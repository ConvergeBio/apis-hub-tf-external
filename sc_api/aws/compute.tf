resource "aws_instance" "vm_instance" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.enable_public_ip
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  key_name                    = var.key_pair_name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = merge(var.labels, {
    "Name" = "${var.instance_name}"
    "Tag"  = var.image_tag
  })
}
