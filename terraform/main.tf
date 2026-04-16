# ============================================================
# Provider, Variables & Data Sources
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }   
  }
}

provider "aws" {
  region = var.aws_region

  # Applied to every supported resource automatically.
  # Resource-level tags blocks are merged on top of these.
  default_tags {
    tags = {
      Project      = var.app_name
      weatherAppTag = var.weather_app_tag_value
      ManagedBy    = "terraform"
    }
  }
}

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name prefix used for resource naming and tagging"
  type        = string
  default     = "weather-service"
}

variable "weather_app_tag_value" {
  description = "Value for the common weatherAppTag tag (used for cost allocation / resource search)"
  type        = string
  default     = "weather-service"
}

variable "app_port" {
  description = "Port the WeatherService container listens on"
  type        = number
  default     = 8080
}

variable "instance_type" {
  description = "EC2 instance type for ASG instances"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG (must be >= 1)"
  type        = number
  default     = 1

  validation {
    condition     = var.asg_desired_capacity >= 1
    error_message = "asg_desired_capacity must be at least 1 to keep the target group healthy."
  }
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

# ------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
