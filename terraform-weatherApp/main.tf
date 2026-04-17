locals {
  app_name = "weatherApp"
  common_tags = {
    Project = local.app_name
    Name    = local.app_name
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "weather_app" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-vpc"
  })
}

resource "aws_internet_gateway" "weather_app" {
  vpc_id = aws_vpc.weather_app.id

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.weather_app.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-public-subnet-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.weather_app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.weather_app.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${local.app_name}-alb-sg"
  description = "Allow HTTP traffic to weatherApp ALB."
  vpc_id      = aws_vpc.weather_app.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-alb-sg"
  })
}

resource "aws_security_group" "app" {
  name        = "${local.app_name}-app-sg"
  description = "Allow ALB traffic to weatherApp instances."
  vpc_id      = aws_vpc.weather_app.id

  ingress {
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

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-app-sg"
  })
}

resource "aws_lb" "weather_app" {
  name               = "${local.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-alb"
  })
}

resource "aws_lb_target_group" "weather_app" {
  name     = "${local.app_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.weather_app.id

  health_check {
    enabled             = true
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.weather_app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.weather_app.arn
  }
}

resource "aws_launch_template" "weather_app" {
  name_prefix   = "${local.app_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.app_name}-instance"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.app_name}-volume"
    })
  }
}

resource "aws_autoscaling_group" "weather_app" {
  name                      = "${local.app_name}-asg"
  min_size                  = 1
  desired_capacity          = 1
  max_size                  = 2
  vpc_zone_identifier       = aws_subnet.public[*].id
  target_group_arns         = [aws_lb_target_group.weather_app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.weather_app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.app_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = local.app_name
    propagate_at_launch = true
  }
}
