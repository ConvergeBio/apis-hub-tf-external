resource "aws_iam_role" "instance_role" {
  name = "${var.instance_name}-${var.customer_id}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.labels
}

resource "aws_iam_role_policy_attachment" "permissions" {
  for_each   = local.roles
  role       = aws_iam_role.instance_role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.instance_name}-${var.customer_id}-profile"
  role = aws_iam_role.instance_role.name
}
