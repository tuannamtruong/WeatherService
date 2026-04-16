# ============================================================
# ElastiCache Redis
#
# Note: cluster provisioning takes 5–10 minutes.
#
# Health check:
#   aws elasticache describe-cache-clusters \
#     --cache-cluster-id ${app_name}-redis \
#     --show-cache-node-info \
#     --query "CacheClusters[0].{Status:CacheClusterStatus,Endpoint:CacheNodes[0].Endpoint}"
#   → CacheClusterStatus must be "available"
#   → Note the endpoint address — stored in SSM for the ASG to consume
#
# Tag search:
#   aws elasticache list-tags-for-resource \
#     --resource-name arn:aws:elasticache:<region>:<account>:cluster:${app_name}-redis
# ============================================================

# ------------------------------------------------------------
# Subnet group (places Redis nodes in private subnets)
# ------------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.app_name}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name  = "${var.app_name}-redis-subnet-group"
    Phase = "cache"
  }
}

# ------------------------------------------------------------
# Redis cluster
# ------------------------------------------------------------

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.app_name}-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = {
    Name  = "${var.app_name}-redis"
    Role  = "cache"
    Phase = "cache"
  }
}

# ------------------------------------------------------------
# SSM Parameter — Redis URL for the ASG launch template
#
# Storing the endpoint here decouples the ASG launch template
# from the ElastiCache resource. EC2 instances fetch this at
# boot time via the SSM-enabled IAM role, so Redis can be
# replaced without forcing a new launch template version.
# ------------------------------------------------------------

resource "aws_ssm_parameter" "redis_url" {
  name        = "/${var.app_name}/REDIS_URL"
  description = "Redis connection URL consumed by WeatherService at boot"
  type        = "String"
  value       = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379"

  tags = {
    Name  = "${var.app_name}-redis-url-param"
    Phase = "cache"
  }
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint address"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_cluster.redis.port
}

output "redis_url_ssm_name" {
  description = "SSM parameter name holding the Redis connection URL"
  value       = aws_ssm_parameter.redis_url.name
}
