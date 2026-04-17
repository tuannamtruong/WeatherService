variable "aws_region" {
  description = "AWS region for weatherApp infrastructure."
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the weatherApp VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs for ALB and ASG."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for weatherApp ASG."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID used by weatherApp instances."
  type        = string
}

variable "app_port" {
  description = "Port exposed by the weatherApp service."
  type        = number
  default     = 8080
}
