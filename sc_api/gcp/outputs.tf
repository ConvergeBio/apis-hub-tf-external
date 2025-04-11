output "instance_name" {
  description = "Name of the created instance"
  value       = google_compute_instance.vm_instance.name
}