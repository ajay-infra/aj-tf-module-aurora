locals {
  name_prefix = "${lower(replace(var.cluster_name, " ", "-"))}-${var.environment}"

  # Data VPC subnets sliced to az_count.
  # Subnets must be ordered by AZ (standard aj-tf-module-vpc output).
  # Aurora DB subnet group requires at least 2 subnets in different AZs.
  # min() guards against callers passing fewer subnets than az_count.
  active_data_subnets = slice(var.data_subnet_ids, 0, min(var.az_count, length(var.data_subnet_ids)))

  # Allowed source CIDRs on port 5432.
  # Always includes the blue VPC; green is added dynamically when the
  # green cluster is live (during a blue/green upgrade window).
  allowed_cidr_blocks = concat(
    [var.blue_vpc_cidr],
    var.green_enabled ? [var.green_vpc_cidr] : []
  )

  full_tags = merge(var.common_tags, {
    # The estate's base set — see aj-skill-farm/rules/tagging.yaml.
    Project     = "aj-tf-module-aurora"
    ManagedBy   = "Terraform"
    Repository  = "aj-tf-module-aurora"
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
    ClusterName = var.cluster_name
    AZCount     = tostring(var.az_count)
    # FinOps: explicit RI family tag for Cloudability RI coverage tracking
    FinOpsRIFamily = "db.r8g"
  }, var.tags)
}
