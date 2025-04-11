resource "aws_cloudwatch_log_group" "container_logs" {
  name              = local.log_group_name
  retention_in_days = 30
  tags              = var.labels
}
