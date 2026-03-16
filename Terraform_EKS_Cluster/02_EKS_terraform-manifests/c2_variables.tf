# --------------------------------------------------------
# AWS Region (used in provider block)
# --------------------------------------------------------
variable "aws_region" {
  description = "AWS region where GuitarShop EKS cluster and related resources will be deployed"
  type        = string
  default     = "us-east-1"
}

# --------------------------------------------------------
# Environment & Business Division Info
# --------------------------------------------------------

# Logical environment name (used in tags and resource names)
variable "environment_name" {
  description = "Deployment environment name (e.g. dev, staging, prod) used in GuitarShop resource names and tags"
  type        = string
  default     = "dev"
}

# Business unit or department (used in tags and naming)
variable "business_division" {
  description = "Business division or team name used in resource naming and tagging (e.g. guitarshop)"
  type        = string
  default     = "guitarshop"
}

# --------------------------------------------------------
# EKS Cluster Configuration
# --------------------------------------------------------

# Name of the EKS cluster (used in names, tags, and references)
variable "cluster_name" {
  description = "Name of the GuitarShop EKS cluster, also used as a prefix for related resource names."
  type        = string
  default     = "guitarshop-eks"
}

# Kubernetes version for the EKS control plane
variable "cluster_version" {
  description = "Kubernetes version to use for the GuitarShop EKS control plane (e.g. 1.29, 1.30)"
  type        = string
  default     = null
}

# CIDR block used for Kubernetes service networking
variable "cluster_service_ipv4_cidr" {
  description = "IPv4 CIDR block for Kubernetes service networking in the GuitarShop cluster. Leave null to use the AWS default."
  type        = string
  default     = null
}

# Enable access to the EKS API via private endpoint
variable "cluster_endpoint_private_access" {
  description = "Whether to enable private VPC access to the GuitarShop EKS control plane endpoint"
  type        = bool
  default     = false
}

# Enable access to the EKS API via public endpoint
variable "cluster_endpoint_public_access" {
  description = "Whether to enable public internet access to the GuitarShop EKS control plane endpoint"
  type        = bool
  default     = true
}

# List of CIDRs allowed to reach the public EKS API endpoint
variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks permitted to access the public GuitarShop EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --------------------------------------------------------
# Common Tags
# --------------------------------------------------------

# Tags applied to all resources created by this configuration
variable "tags" {
  description = "Tags applied to all GuitarShop EKS cluster and related AWS resources"
  type        = map(string)
  default     = {
    Terraform = "true"
    Project   = "guitarShop"
  }
}

# --------------------------------------------------------
# EKS Node Group Configuration
# --------------------------------------------------------

# EC2 instance types for worker nodes
variable "node_instance_types" {
  description = "List of EC2 instance types used for GuitarShop EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

# Capacity type for node group (ON_DEMAND or SPOT)
variable "node_capacity_type" {
  description = "EC2 capacity type for GuitarShop worker nodes: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

# Root volume size (GiB) for worker nodes
variable "node_disk_size" {
  description = "Root volume size in GiB for each GuitarShop EKS worker node"
  type        = number
  default     = 20
}

