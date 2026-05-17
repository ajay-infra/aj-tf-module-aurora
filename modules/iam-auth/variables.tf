variable "name_prefix" {
  type        = string
  description = "Resource name prefix (from root locals.name_prefix)"
}

variable "cluster_resource_id" {
  type        = string
  description = <<-EOT
    Aurora cluster resource ID (e.g. cluster-XXXXXX).
    Used in the rds-db:connect IAM policy resource ARN.
    Obtained from the db-cluster module output cluster_resource_id.
  EOT
}

variable "iam_auth_db_username" {
  type        = string
  default     = "ai_search_app"
  description = <<-EOT
    PostgreSQL username that the app uses for RDS IAM auth.
    This user must be granted rds_iam role in the DB after cluster creation:
      CREATE USER ai_search_app WITH LOGIN;
      GRANT rds_iam TO ai_search_app;
    The IAM policy allows rds-db:connect only for this specific user.
  EOT
}

variable "aws_region" {
  type        = string
  description = "AWS region (used in rds-db:connect ARN)"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID (used in rds-db:connect ARN). Pass data.aws_caller_identity.current.account_id from root."
}
