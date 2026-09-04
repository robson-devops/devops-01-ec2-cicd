output "instance_id" {
  description = "ID da instância EC2 (usar como secret EC2_INSTANCE_ID no GitHub)"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.app.public_ip
}

output "app_health_url" {
  description = "URL de health check da aplicação"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/health"
}

output "ssm_session_command" {
  description = "Comando para abrir uma sessão administrativa na instância"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}

output "log_group_name" {
  description = "Nome do log group da aplicação no CloudWatch"
  value       = aws_cloudwatch_log_group.app.name
}