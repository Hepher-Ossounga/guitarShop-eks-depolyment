
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC created for the GuitarShop infrastructure"
}

output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "List of public subnet IDs used for load balancers in the GuitarShop VPC"
}

output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "List of private subnet IDs used for GuitarShop EKS worker nodes"
}

output "public_subnet_map" {
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
  description = "Map of availability zone to public subnet ID for the GuitarShop VPC"
}
