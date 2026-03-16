variable "aws_region" {
  description = "AWS region where GuitarShop infrastructure resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Deployment environment name (e.g. dev, staging, prod) used in GuitarShop resource names and tags"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the GuitarShop VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Global tags applied to all GuitarShop VPC resources"
  type        = map(string)
  default     = {
    Terraform = "true"
  }
}

variable "subnet_newbits" {
  description = "Number of additional bits added to the VPC CIDR to calculate subnet sizes for GuitarShop (e.g., 8 produces /24 subnets from a /16 VPC)"
  type        = number
  default     = 8
}
