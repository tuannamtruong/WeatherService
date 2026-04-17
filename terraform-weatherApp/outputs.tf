output "alb_dns_name" {
  description = "DNS name of weatherApp ALB."
  value       = aws_lb.weather_app.dns_name
}

output "asg_name" {
  description = "Name of weatherApp Auto Scaling Group."
  value       = aws_autoscaling_group.weather_app.name
}

output "vpc_id" {
  description = "VPC ID created for weatherApp."
  value       = aws_vpc.weather_app.id
}
