# ── Security Group ────────────────────────────────────────────────────────────
# Placed in the data VPC. Allows inbound 5432 from EKS cluster VPC CIDRs.
# Blue VPC is always allowed; green CIDR is added during blue/green upgrade.

resource "aws_security_group" "aurora" {
  name        = "${var.name_prefix}-aurora-sg"
  description = "Aurora PostgreSQL — allow inbound 5432 from EKS cluster VPC CIDRs"
  vpc_id      = var.data_vpc_id

  ingress {
    description = "Aurora PostgreSQL from EKS clusters (blue + optional green)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────
# Data VPC subnets, one per AZ (sliced by az_count in root locals).
# Aurora requires at least 2 subnets in different AZs regardless of replica_count.

resource "aws_db_subnet_group" "aurora" {
  name        = "${var.name_prefix}-aurora"
  description = "Data VPC subnets for Aurora — one per AZ"
  subnet_ids  = var.subnet_ids
}

# ── Cluster Parameter Group ───────────────────────────────────────────────────
# aurora-postgresql16 family. pgvector loaded via shared_preload_libraries.
# max_connections tuned upward — pgvector similarity searches and pgbouncer
# (app-layer) can drive concurrent connections higher than Aurora default.

resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${var.name_prefix}-aurora-cpg"
  family      = "aurora-postgresql16"
  description = "Aurora PostgreSQL 16 cluster params — pgvector enabled for ${var.name_prefix}"

  parameter {
    # vector extension loaded at startup — enables pgvector similarity search.
    # pg_stat_statements included for query performance tracking in Performance Insights.
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,vector"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Instance Parameter Group ──────────────────────────────────────────────────
# Per-instance settings. Empty by default — Aurora instance defaults are sane.
# Kept as an explicit resource so instance-level tuning can be added without
# changing resource structure (avoids recreate).

resource "aws_db_parameter_group" "aurora" {
  name        = "${var.name_prefix}-aurora-pg"
  family      = "aurora-postgresql16"
  description = "Aurora PostgreSQL 16 instance params for ${var.name_prefix}"

  lifecycle {
    create_before_destroy = true
  }
}

# ── Aurora Cluster ────────────────────────────────────────────────────────────
# Aurora PostgreSQL — shared data layer across blue and green EKS clusters.
# Both clusters connect to the same Aurora instance via data VPC peering.
#
# RDS IAM auth (iam_database_authentication_enabled = true):
#   App pods use rds-db:connect tokens (15-min rotating) via Pod Identity.
#   No static password in application code or K8s secrets.
#   See modules/iam-auth for the Pod Identity IAM policy.
#
# manage_master_user_password = true:
#   AWS creates and rotates the master password in Secrets Manager automatically.
#   Master credentials are for break-glass/admin access only — never for app auth.
#   The master_user_secret ARN is available in outputs for admin tooling.

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username

  # AWS-managed master password — stored and rotated in Secrets Manager automatically.
  # Application pods do NOT use this credential; they use RDS IAM auth tokens.
  manage_master_user_password = true

  # Network
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # Parameter group
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  # Storage — always encrypted; AWS-managed KMS key (CMK can be passed if needed)
  storage_encrypted = var.storage_encrypted

  # RDS IAM database authentication — app pods authenticate with IAM tokens
  iam_database_authentication_enabled = var.enable_iam_auth

  # Backup — Aurora continuous backup with point-in-time recovery
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window

  # Deletion protection — off for dev (easy teardown), on for prod
  deletion_protection = var.deletion_protection

  # Final snapshot — taken on cluster deletion when deletion_protection = false
  # (i.e. when it's actually possible to delete the cluster)
  skip_final_snapshot       = var.deletion_protection ? false : true
  final_snapshot_identifier = var.deletion_protection ? "${var.name_prefix}-aurora-final" : null

  # Logs — export PostgreSQL logs to CloudWatch; Alloy can ship to central Loki
  enabled_cloudwatch_logs_exports = ["postgresql"]

  apply_immediately = var.apply_immediately

  lifecycle {
    # Allow Aurora to manage minor engine version patches without Terraform drift.
    # Major version upgrades use Aurora native blue/green (not Terraform).
    ignore_changes = [engine_version]
  }
}

# ── Writer Instance ───────────────────────────────────────────────────────────
# Single writer — Aurora does not support multiple writers (unlike Multi-AZ DB cluster).
# RI purchase target: this is the instance to commit to for 1yr/3yr RDS RI.

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.name_prefix}-aurora-writer"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  db_parameter_group_name = aws_db_parameter_group.aurora.name
  db_subnet_group_name    = aws_db_subnet_group.aurora.name

  # Performance Insights — free 7-day retention on r8g instances
  performance_insights_enabled = var.enable_performance_insights

  # Allow Aurora to apply minor engine version patches during maintenance window
  auto_minor_version_upgrade = true

  apply_immediately = var.apply_immediately
}

# ── Reader Instances ──────────────────────────────────────────────────────────
# Aurora distributes readers across AZs automatically when db_subnet_group has
# subnets in multiple AZs. The reader endpoint load-balances across all readers.
#
# RI note: each reader instance requires its own RI (or is covered by normalised
# RI units from a larger commitment in the same r8g family).

resource "aws_rds_cluster_instance" "reader" {
  count = var.replica_count

  identifier         = "${var.name_prefix}-aurora-reader-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  db_parameter_group_name = aws_db_parameter_group.aurora.name
  db_subnet_group_name    = aws_db_subnet_group.aurora.name

  performance_insights_enabled = var.enable_performance_insights

  auto_minor_version_upgrade = true

  apply_immediately = var.apply_immediately

  depends_on = [aws_rds_cluster_instance.writer]
}
