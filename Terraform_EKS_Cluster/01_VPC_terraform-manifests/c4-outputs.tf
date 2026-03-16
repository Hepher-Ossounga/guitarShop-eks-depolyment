output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID of the GuitarShop VPC, referenced by the EKS cluster and other services"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Private subnet IDs used to deploy GuitarShop EKS worker nodes"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "Public subnet IDs used for ALB/NLB load balancers in the GuitarShop VPC"
}

output "public_subnet_map" {
  value       = module.vpc.public_subnet_map
  description = "Map of availability zone to public subnet ID for load balancer placement in the GuitarShop VPC"
}


