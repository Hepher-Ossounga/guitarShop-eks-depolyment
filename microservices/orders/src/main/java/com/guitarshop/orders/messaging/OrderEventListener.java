package com.guitarshop.orders.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.guitarshop.orders.model.Order;
import com.guitarshop.orders.model.OrderItem;
import com.guitarshop.orders.service.OrderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
@Slf4j
public class OrderEventListener {

    private final OrderService orderService;
    private final ObjectMapper objectMapper;

    @RabbitListener(queues = "${guitarshop.rabbitmq.queue:checkout.events}")
    public void handleCheckoutEvent(String message) {
        try {
            log.info("📨 Received checkout event: {}", message);

            @SuppressWarnings("unchecked")
            Map<String, Object> event = objectMapper.readValue(message, Map.class);

            String eventType = (String) event.get("event");
            if (!"ORDER_CREATED".equals(eventType)) {
                log.warn("Unknown event type: {}", eventType);
                return;
            }

            // Build order from the event payload
            Order order = new Order();
            order.setCustomerId((String) event.get("customerId"));
            order.setEmail((String) event.getOrDefault("email", "unknown@guitarshop.com"));
            order.setFirstName((String) event.get("firstName"));
            order.setLastName((String) event.get("lastName"));
            order.setAddress((String) event.get("address"));
            order.setCity((String) event.get("city"));
            order.setCountry((String) event.get("country"));
            order.setPostalCode((String) event.get("postalCode"));

            Object subtotal = event.get("subtotal");
            if (subtotal != null) order.setSubtotal(new BigDecimal(subtotal.toString()));

            Object shippingCost = event.get("shippingCost");
            if (shippingCost != null) order.setShippingCost(new BigDecimal(shippingCost.toString()));

            Object total = event.get("total");
            if (total != null) order.setTotal(new BigDecimal(total.toString()));

            @SuppressWarnings("unchecked")
            List<Map<String, Object>> rawItems = (List<Map<String, Object>>) event.get("items");
            if (rawItems != null) {
                List<OrderItem> items = rawItems.stream().map(raw -> {
                    OrderItem item = new OrderItem();
                    item.setProductId((String) raw.get("productId"));
                    item.setName((String) raw.get("name"));
                    item.setBrand((String) raw.get("brand"));
                    Object price = raw.get("price");
                    if (price != null) item.setPrice(new BigDecimal(price.toString()));
                    Object qty = raw.get("quantity");
                    if (qty != null) item.setQuantity(((Number) qty).intValue());
                    item.setImageUrl((String) raw.get("imageUrl"));
                    return item;
                }).collect(Collectors.toList());
                order.setItems(items);
            }

            orderService.processCheckoutEvent(order);
        } catch (Exception e) {
            log.error("❌ Failed to process checkout event: {}", e.getMessage(), e);
        }
    }
}
