# envs/staging.tfvars — Aurora config for staging environment
# Used with: -var-file=envs/staging.tfvars (plus common.tfvars from aj-infra-release)

environment  = "staging"
cluster_name = "ai-search-staging"
aws_region   = "us-east-1"

# Network — filled in by aj-infra-release pipeline from vpc module outputs
# data_vpc_id     = "<from vpc output>"
# data_subnet_ids = ["<from vpc output>"]

blue_vpc_cidr  = "10.112.0.0/16" # staging data VPC CIDR
green_enabled  = false
green_vpc_cidr = ""

az_count = 2 # staging: 2 AZs — mirrors dev topology

# Engine
engine_version = "16.6"

# Instance class — same r8g family as dev and prod (RI family alignment)
instance_class = "db.r8g.large"

# Database
database_name        = "ai_search"
master_username      = "dbadmin"
iam_auth_db_username = "ai_search_app"

# Replication: writer + 1 reader (same as dev)
replica_count = 1

# Backup
backup_retention_days = 14 # longer than dev — staging used for pre-prod validation
backup_window         = "03:00-04:00"
maintenance_window    = "mon:04:00-mon:05:00"

# Protection — off for staging
deletion_protection = false

# Observability — enable for staging to catch slow queries before prod
enable_performance_insights = true

# IAM auth — always true
enable_iam_auth = true

apply_immediately           = false # staging: respect maintenance window
secret_recovery_window_days = 7

team        = "infra-core"
cost_center = "infra-2026-q1"
tags = {
  Owner = "ajay"
  Env   = "staging"
}
