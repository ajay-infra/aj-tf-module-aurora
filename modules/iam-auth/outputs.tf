output "policy_arn" {
  description = <<-EOT
    IAM policy ARN for RDS IAM authentication.
    Attach to the Pod Identity role of each service that needs Aurora access:
      aws eks create-pod-identity-association \
        --cluster-name <eks-cluster> \
        --namespace backend \
        --service-account ai-search-backend \
        --role-arn <pod-identity-role-arn>
    The role must have this policy attached.
    Managed via aj-infra-release (passed as -var flag to aj-infra-platform).
  EOT
  value       = aws_iam_policy.rds_iam_auth.arn
}

output "policy_name" {
  description = "IAM policy name for RDS IAM authentication"
  value       = aws_iam_policy.rds_iam_auth.name
}

output "iam_auth_db_username" {
  description = "PostgreSQL username this policy grants rds-db:connect for"
  value       = var.iam_auth_db_username
}
