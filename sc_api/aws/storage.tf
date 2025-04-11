resource "aws_ebs_volume" "data_disk" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.disk_size
  type              = "gp3"
}

resource "aws_volume_attachment" "data_disk_attachment" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.data_disk.id
  instance_id  = aws_instance.vm_instance.id
  force_detach = true
  depends_on   = [aws_instance.vm_instance]
}
