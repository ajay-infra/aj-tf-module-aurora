output "cluster_endpoint" {
  description = "Aurora writer endpoint — used for all write operations (INSERT/UPDATE/DELETE)"
  value       = aws_rds_cluster.aurora.endpoint
}

output "reader_endpoint" {
  description = "Aurora reader endpoint — round-robin load-balanced across all reader instances"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "cluster_identifier" {
  description = "Aurora cluster identifier — used for blue/green native DB upgrades and CloudWatch dimensions"
  value       = aws_rds_cluster.aurora.cluster_identifier
}

output "cluster_resource_id" {
  description = <<-EOT
    Aurora cluster resource ID (dbi-resource-id format, e.g. cluster-XXXXXX).
    Used in the rds-db:connect IAM policy ARN for RDS IAM authentication.
    Format: arn:aws:rds-db:{region}:{account}:dbuser:{cluster_resource_id}/{db_username}
  EOT
  value       = aws_rds_cluster.aurora.cluster_resource_id
}

output "port" {
  description = "Aurora PostgreSQL port (always 5432)"
  value       = aws_rds_cluster.aurora.port
}

output "database_name" {
  description = "Initial database name created in the cluster"
  value       = aws_rds_cluster.aurora.database_name
}

output "master_username" {
  description = "Aurora master username (break-glass admin access only; app uses IAM auth)"
  value       = aws_rds_cluster.aurora.master_username
}

output "master_user_secret_arn" {
  description = <<-EOT
    Secrets Manager ARN for the AWS-managed master user password.
    This is managed by AWS (manage_master_user_password = true) and auto-rotated.
    Used for admin/break-glass access only. Application code uses RDS IAM tokens.
  EOT
  value       = length(aws_rds_cluster.aurora.master_user_secret) > 0 ? aws_rds_cluster.aurora.master_user_secret[0].secret_arn : null
}

output "security_group_id" {
  description = "Aurora security group ID — used to add targeted SG rules from EKS node groups if needed"
  value       = aws_security_group.aurora.id
}

output "writer_instance_id" {
  description = "Aurora writer instance identifier"
  value       = aws_rds_cluster_instance.writer.identifier
}

output "reader_instance_ids" {
  description = "Aurora reader instance identifiers (list, empty when replica_count = 0)"
  value       = [for r in aws_rds_cluster_instance.reader : r.identifier]
}
