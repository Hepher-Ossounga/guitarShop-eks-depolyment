const amqp   = require('amqplib');
const { logger } = require('../config/logger');

const EXCHANGE   = 'guitarshop.orders';
const QUEUE      = 'checkout.events';
const ROUTING_KEY = 'order.created';

let channel;

async function connectMQ() {
  const url = process.env.RABBITMQ_URL || 'amqp://guitarshop:guitarshop123@rabbitmq:5672';
  const maxRetries = 10;

  for (let i = 0; i < maxRetries; i++) {
    try {
      const conn = await amqp.connect(url);
      channel = await conn.createChannel();
      await channel.assertExchange(EXCHANGE, 'topic', { durable: true });
      await channel.assertQueue(QUEUE, { durable: true });
      await channel.bindQueue(QUEUE, EXCHANGE, ROUTING_KEY);
      logger.info('✅ Connected to RabbitMQ');
      conn.on('error', err => logger.error('RabbitMQ error:', err));
      return;
    } catch (err) {
      logger.warn(`⏳ Waiting for RabbitMQ... attempt ${i + 1}/${maxRetries}`);
      await new Promise(r => setTimeout(r, 3000));
    }
  }
  logger.error('❌ Could not connect to RabbitMQ — checkout will run without messaging');
}

async function publishOrderCreated(order) {
  if (!channel) {
    logger.warn('RabbitMQ not connected, skipping publish');
    return;
  }
  const message = Buffer.from(JSON.stringify({
    event:        'ORDER_CREATED',
    orderId:      order.id,
    customerId:   order.customer_id,
    email:        order.email,
    firstName:    order.first_name,
    lastName:     order.last_name,
    address:      order.address,
    city:         order.city,
    country:      order.country,
    postalCode:   order.postal_code,
    items:        typeof order.items === 'string' ? JSON.parse(order.items) : order.items,
    subtotal:     order.subtotal,
    shippingCost: order.shipping_cost,
    total:        order.total,
    timestamp:    new Date().toISOString(),
  }));
  channel.publish(EXCHANGE, ROUTING_KEY, message, { persistent: true });
  logger.info(`📨 Published ORDER_CREATED for order ${order.id}`);
}

module.exports = { connectMQ, publishOrderCreated };
