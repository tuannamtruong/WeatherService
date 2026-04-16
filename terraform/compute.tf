# ============================================================
# ALB · IAM · ASG · Autoscaling
#
# Health checks (run in sequence):
#
# 1. ALB active:
#    aws elbv2 describe-load-balancers \
#      --names ${app_name}-alb \
#      --query "LoadBalancers[0].State.Code"
#    → "active"
#
# 2. ALB returns 503 (expected — no targets yet):
#    curl -o /dev/null -s -w "%{http_code}" http://<alb_dns_name>/health
#    → 503
#
# 3. ASG has at least one InService instance:
#    aws autoscaling describe-auto-scaling-groups \
#      --auto-scaling-group-names ${app_name}-asg \
#      --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService']"
#
# 4. End-to-end health (expect 200 once instance is InService):
#    curl http://<alb_dns_name>/health
#    → 200 OK
#
# Tag search across all Phase 5 resources:
#    aws resourcegroupstaggingapi get-resources \
#      --tag-filters Key=Phase,Values=compute Key=Project,Values=${app_name}
# ============================================================

# ------------------------------------------------------------
# Application Load Balancer
# ------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Set to true before going to production
  enable_deletion_protection = false

  # Uncomment to enable access logs (recommended for production):
  # access_logs {
  #   bucket  = aws_s3_bucket.alb_logs.bucket
  #   prefix  = var.app_name
  #   enabled = true
  # }

  tags = {
    Name  = "${var.app_name}-alb"
    Role  = "load-balancer"
    Phase = "compute"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.app_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name  = "${var.app_name}-tg"
    Role  = "load-balancer"
    Phase = "compute"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name  = "${var.app_name}-http-listener"
    Phase = "compute"
  }
}

# ------------------------------------------------------------
# IAM role for EC2 — SSM access (no SSH needed)
# ------------------------------------------------------------

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.app_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name  = "${var.app_name}-ec2-ssm-role"
    Role  = "iam"
    Phase = "compute"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allows EC2 instances to read the Redis URL from SSM Parameter Store
resource "aws_iam_role_policy" "read_ssm_params" {
  name = "${var.app_name}-read-ssm-params"
  role = aws_iam_role.ec2_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.app_name}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.app_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name

  tags = {
    Name  = "${var.app_name}-ec2-ssm-profile"
    Role  = "iam"
    Phase = "compute"
  }
}

# ------------------------------------------------------------
# Launch template
# The Redis URL is fetched from SSM at boot time so the launch
# template does not embed a baked-in endpoint address.
# Replace "weather-go-app:latest" with your ECR image URI.
# ------------------------------------------------------------

resource "aws_launch_template" "app" {
  name_prefix   = "${var.app_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install Docker
    dnf install -y docker
    systemctl enable --now docker

    # Fetch Redis URL from SSM (requires AmazonSSMManagedInstanceCore + read_ssm_params policy)
    REDIS_URL=$(aws ssm get-parameter \
      --name /${var.app_name}/REDIS_URL \
      --query Parameter.Value \
      --output text \
      --region ${var.aws_region})

    # Pull and run the WeatherService container
    # TODO: replace with your ECR image URI, e.g. <account>.dkr.ecr.<region>.amazonaws.com/weather-go-app:latest
    docker run -d \
      --name weather-service \
      --restart unless-stopped \
      -p ${var.app_port}:${var.app_port} \
      -e REDIS_URL=$REDIS_URL \
      weather-go-app:latest
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name          = "${var.app_name}-instance"
      Role          = "app"
      Phase         = "compute"
      weatherAppTag = var.weather_app_tag_value
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name          = "${var.app_name}-root-volume"
      Phase         = "compute"
      weatherAppTag = var.weather_app_tag_value
    }
  }

  tags = {
    Name  = "${var.app_name}-launch-template"
    Phase = "compute"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------
# Auto Scaling Group
# ------------------------------------------------------------

resource "aws_autoscaling_group" "app" {
  name                = "${var.app_name}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.app_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "weatherAppTag"
    value               = var.weather_app_tag_value
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.app_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Phase"
    value               = "compute"
    propagate_at_launch = true
  }
}

# ------------------------------------------------------------
# Autoscaling policies & CloudWatch alarms
# ------------------------------------------------------------

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.app_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.app_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when average CPU exceeds 70% for 2 consecutive minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = {
    Name  = "${var.app_name}-cpu-high-alarm"
    Phase = "compute"
  }
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.app_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.app_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in when average CPU drops below 30% for 2 consecutive minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = {
    Name  = "${var.app_name}-cpu-low-alarm"
    Phase = "compute"
  }
}

# ------------------------------------------------------------
# Outputs
# ------------------------------------------------------------

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer — use this to test /health"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}
