# ── Aurora DB Cluster ─────────────────────────────────────────────────────────
# Aurora PostgreSQL in the data VPC. Shared across blue and green EKS clusters —
# the data layer is never duplicated. Both clusters connect to the same Aurora
# instance via data VPC peering.
#
# pgvector extension: enabled via cluster parameter group (shared_preload_libraries).
# pgvector is used by the RAG backend for embedding similarity search on the
# ai_search database.
#
# RDS IAM auth: app pods use 15-min rotating tokens via Pod Identity → rds-db:connect.
# manage_master_user_password = true: AWS manages master creds for break-glass only.

module "db_cluster" {
  source = "./modules/db-cluster"

  name_prefix         = local.name_prefix
  data_vpc_id         = var.data_vpc_id
  subnet_ids          = local.active_data_subnets
  allowed_cidr_blocks = local.allowed_cidr_blocks

  engine_version = var.engine_version
  instance_class = var.instance_class
  database_name  = var.database_name
  master_username = var.master_username
  replica_count  = var.replica_count

  storage_encrypted           = var.storage_encrypted
  enable_iam_auth             = var.enable_iam_auth
  backup_retention_days       = var.backup_retention_days
  backup_window               = var.backup_window
  maintenance_window          = var.maintenance_window
  deletion_protection         = var.deletion_protection
  enable_performance_insights = var.enable_performance_insights
  apply_immediately           = var.apply_immediately
}

# ── RDS IAM Auth Policy ───────────────────────────────────────────────────────
# IAM policy for Pod Identity: grants rds-db:connect on this specific cluster
# for the designated app DB username. Attach to the EKS Pod Identity role of
# each service namespace that needs Aurora access (via aj-infra-release).

module "iam_auth" {
  source = "./modules/iam-auth"

  name_prefix         = local.name_prefix
  cluster_resource_id = module.db_cluster.cluster_resource_id
  iam_auth_db_username = var.iam_auth_db_username
  aws_region          = var.aws_region
}

# ── Connection Config Bundle (Secrets Manager) ────────────────────────────────
# Stores the Aurora connection configuration for ESO ExternalSecret in k8s-manifests.
# ESO pulls this secret into each namespace that needs Aurora access as a K8s Secret.
#
# Secret JSON schema:
#   host         — Aurora writer endpoint (write operations)
#   reader_host  — Aurora reader endpoint (read-heavy RAG similarity queries)
#   port         — always 5432
#   dbname       — database name (ai_search)
#   username     — IAM auth DB username (ai_search_app); app generates token at runtime
#   region       — AWS region (needed by SDK to call generate-db-auth-token)
#   iam_auth     — "true" (signals to app to use token auth, not password)
#
# NOTE: No password in this secret — app uses rds-db:connect IAM token (15-min rotating).
# The master password is in a separate AWS-managed secret (master_user_secret_arn output).

resource "aws_secretsmanager_secret" "aurora_connection" {
  name                    = "${local.name_prefix}/aurora/connection"
  description             = "Aurora connection config for ${local.name_prefix} — IAM auth (no password)"
  recovery_window_in_days = var.secret_recovery_window_days
}

resource "aws_secretsmanager_secret_version" "aurora_connection" {
  secret_id = aws_secretsmanager_secret.aurora_connection.id

  secret_string = jsonencode({
    host        = module.db_cluster.cluster_endpoint
    reader_host = module.db_cluster.reader_endpoint
    port        = tostring(module.db_cluster.port)
    dbname      = module.db_cluster.database_name
    username    = var.iam_auth_db_username
    region      = var.aws_region
    iam_auth    = "true"
  })
}
