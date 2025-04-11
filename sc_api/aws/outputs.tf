output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = aws_instance.vm_instance.id
}

output "instance_public_ip" {
  description = "Public IP address of the created instance (if enabled)"
  value       = aws_instance.vm_instance.public_ip
}
