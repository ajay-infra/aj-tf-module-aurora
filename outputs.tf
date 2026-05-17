output "cluster_endpoint" {
  description = "Aurora writer endpoint — used for INSERT/UPDATE/DELETE operations"
  value       = module.db_cluster.cluster_endpoint
}

output "reader_endpoint" {
  description = "Aurora reader endpoint — load-balanced across all reader instances. Use for SELECT-heavy RAG similarity searches."
  value       = module.db_cluster.reader_endpoint
}

output "cluster_identifier" {
  description = "Aurora cluster identifier — used for Aurora native blue/green DB upgrades and CloudWatch dimensions"
  value       = module.db_cluster.cluster_identifier
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID — embedded in rds-db:connect IAM policy ARN"
  value       = module.db_cluster.cluster_resource_id
}

output "database_name" {
  description = "Initial database name"
  value       = module.db_cluster.database_name
}

output "security_group_id" {
  description = "Aurora security group ID — used to add targeted SG rules from EKS node groups if needed"
  value       = module.db_cluster.security_group_id
}

output "secret_arn" {
  description = <<-EOT
    Secrets Manager ARN for the Aurora connection config bundle.
    Contains: host, reader_host, port, dbname, username, region, iam_auth.
    Consumed by ESO ExternalSecret in k8s-manifests.
    No password — app uses RDS IAM auth tokens at runtime.
  EOT
  value       = aws_secretsmanager_secret.aurora_connection.arn
}

output "master_user_secret_arn" {
  description = <<-EOT
    Secrets Manager ARN for the AWS-managed master user password.
    Break-glass admin access only. Rotated automatically by AWS.
    Never consumed by application pods.
  EOT
  value       = module.db_cluster.master_user_secret_arn
}

output "iam_auth_policy_arn" {
  description = <<-EOT
    IAM policy ARN for rds-db:connect.
    Attach to the EKS Pod Identity role of each service namespace that needs Aurora access.
    Consumed by aj-infra-release as a -var flag to aj-infra-platform.
  EOT
  value       = module.iam_auth.policy_arn
}

output "iam_auth_db_username" {
  description = "PostgreSQL username used for RDS IAM auth (must be created in DB post-provisioning)"
  value       = module.iam_auth.iam_auth_db_username
}

output "writer_instance_id" {
  description = "Aurora writer instance ID — RI purchase target"
  value       = module.db_cluster.writer_instance_id
}

output "reader_instance_ids" {
  description = "Aurora reader instance IDs (empty when replica_count = 0)"
  value       = module.db_cluster.reader_instance_ids
}

output "active_az_count" {
  description = "Number of AZs this cluster is spread across (controlled by az_count)"
  value       = var.az_count
}

output "active_data_subnets" {
  description = "Data subnet IDs in use — sliced to az_count from data_subnet_ids"
  value       = local.active_data_subnets
}
