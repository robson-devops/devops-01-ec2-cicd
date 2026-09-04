resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/app"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-log-group"
  }
}

# Alarme de saúde da instância: dispara se o status check da EC2 falhar
# (problema de hardware/host ou do sistema operacional).
resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = "${var.project_name}-status-check-failed"
  alarm_description   = "Status check da instancia EC2 falhou"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  tags = {
    Name = "${var.project_name}-alarm-status-check"
  }
}

# Alarme de CPU: sinaliza saturação sustentada, base para a discussão de
# escalabilidade que motiva a migração para ECS no projeto 2.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  alarm_description   = "CPU acima de 80% por 10 minutos"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  tags = {
    Name = "${var.project_name}-alarm-cpu"
  }
}