# ── RDS IAM Authentication Policy ─────────────────────────────────────────────
# Grants rds-db:connect permission for a specific PostgreSQL username on this
# Aurora cluster. This policy is attached to the EKS Pod Identity role of each
# service that needs DB access (via aj-infra-release or aj-infra-platform).
#
# How RDS IAM auth works at runtime:
#   1. Pod calls aws rds generate-db-auth-token (or SDK equivalent)
#   2. AWS returns a signed token (valid 15 minutes) using the pod's IAM identity
#   3. Pod connects to Aurora using the token as the PostgreSQL password
#   4. No static password stored in K8s secrets or environment variables
#
# Prerequisites (one-time DB admin step after cluster provisioning):
#   psql -h <cluster_endpoint> -U dbadmin -d ai_search
#   CREATE USER ai_search_app WITH LOGIN;
#   GRANT rds_iam TO ai_search_app;
#   GRANT CONNECT ON DATABASE ai_search TO ai_search_app;
#   -- Grant table-level permissions as needed per service

resource "aws_iam_policy" "rds_iam_auth" {
  name        = "${var.name_prefix}-aurora-iam-auth"
  description = "Allow RDS IAM database authentication for ${var.name_prefix} Aurora — user: ${var.iam_auth_db_username}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRDSIAMAuth"
        Effect = "Allow"
        Action = ["rds-db:connect"]
        Resource = [
          "arn:aws:rds-db:${var.aws_region}:${var.aws_account_id}:dbuser:${var.cluster_resource_id}/${var.iam_auth_db_username}"
        ]
      }
    ]
  })
}
