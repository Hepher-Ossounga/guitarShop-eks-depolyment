# ------------------------------------------------------------------------------
# Output the EKS Cluster API server endpoint
# Used by kubectl and external tools to communicate with the cluster
# ------------------------------------------------------------------------------
output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "API server endpoint for the GuitarShop EKS cluster"
}

# ------------------------------------------------------------------------------
# Output the EKS Cluster ID
# Used in AWS CLI commands and automation scripts to reference the GuitarShop EKS cluster
# ------------------------------------------------------------------------------
output "eks_cluster_id" {
  description = "The ID of the GuitarShop EKS cluster."
  value       = aws_eks_cluster.main.id
}

# ------------------------------------------------------------------------------
# Output the EKS Cluster Version
# Useful for identifying compatible EKS add-ons and Kubernetes tooling versions
# for the GuitarShop cluster
# ------------------------------------------------------------------------------
output "eks_cluster_version" {
  description = "Kubernetes version running on the GuitarShop EKS cluster"
  value       = aws_eks_cluster.main.version
}

# ------------------------------------------------------------------------------
# Output the name of the EKS cluster
# Helpful for scripting, `aws eks update-kubeconfig`, etc.
# ------------------------------------------------------------------------------
output "eks_cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "Name of the GuitarShop EKS cluster"
}


# ------------------------------------------------------------------------------
# Output the EKS Cluster Certificate Authority data
# Needed when setting up kubeconfig or accessing EKS via API
# ------------------------------------------------------------------------------
output "eks_cluster_certificate_authority_data" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "Base64-encoded certificate authority data for authenticating to the GuitarShop EKS cluster"
}

# ------------------------------------------------------------------------------
# Output the logical name of the private node group
# Useful for autoscaler configs, dashboards, tagging
# ------------------------------------------------------------------------------
output "private_node_group_name" {
  value       = aws_eks_node_group.private_nodes.node_group_name
  description = "Name of the private node group hosting GuitarShop microservice workloads"
}

# ------------------------------------------------------------------------------
# Output the IAM Role ARN used by the EKS Node Group
# Useful for IRSA setup or attaching additional permissions
# ------------------------------------------------------------------------------
output "eks_node_instance_role_arn" {
  value       = aws_iam_role.eks_nodegroup_role.arn
  description = "IAM Role ARN assumed by EC2 worker nodes in the GuitarShop EKS node group"
}

# ------------------------------------------------------------------------------
# Output command to configure kubectl for the GuitarShop EKS cluster
# Run this command after terraform apply to connect kubectl to the cluster
# ------------------------------------------------------------------------------
output "to_configure_kubectl" {
  description = "AWS CLI command to update local kubeconfig for the GuitarShop EKS cluster"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${local.eks_cluster_name}"
}


