# ============================================================
# Security Groups
#
# Health check:
#   aws ec2 describe-security-groups \
#     --filters "Name=tag:Project,Values=${app_name}" \
#     --query "SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions}"
#   → Expect 3 groups: alb-sg, app-sg, redis-sg
#   → Verify app-sg ingress sources alb-sg (not a CIDR)
#   → Verify redis-sg ingress sources app-sg (not a CIDR)
# ============================================================

# ------------------------------------------------------------
# ALB security group — accepts HTTP (and HTTPS) from internet
# ------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Allow inbound HTTP/HTTPS to the ALB from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Uncomment when you add an HTTPS listener:
  # ingress {
  #   description = "HTTPS from internet"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.app_name}-alb-sg"
    Role  = "alb"
    Phase = "security"
  }
}

# ------------------------------------------------------------
# App (EC2) security group — accepts traffic from ALB only
# ------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.app_name}-app-sg"
  description = "Allow inbound app traffic from the ALB security group only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB SG"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.app_name}-app-sg"
    Role  = "app"
    Phase = "security"
  }
}

# ------------------------------------------------------------
# Redis security group — accepts traffic from app instances only
# ------------------------------------------------------------

resource "aws_security_group" "redis" {
  name        = "${var.app_name}-redis-sg"
  description = "Allow Redis port from app security group only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from app SG"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.app_name}-redis-sg"
    Role  = "redis"
    Phase = "security"
  }
}

# ------------------------------------------------------------
# Outputs (consumed by later phases)
# ------------------------------------------------------------

output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Security group ID for app instances"
  value       = aws_security_group.app.id
}

output "redis_sg_id" {
  description = "Security group ID for ElastiCache Redis"
  value       = aws_security_group.redis.id
}
