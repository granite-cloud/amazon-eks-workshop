/******************
 Cloudwatch Logs
******************/

# Log Group
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/clusters"
  retention_in_days = 1
}
