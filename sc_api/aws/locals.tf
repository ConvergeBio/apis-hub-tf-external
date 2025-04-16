locals {
  roles = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ])
  log_group_name   = "/converge/${var.instance_name}-${var.customer_id}-${var.region}"
  image_repository = "${var.converge_account_id}.dkr.ecr.${var.region}.amazonaws.com/converge-sc/api"
}
