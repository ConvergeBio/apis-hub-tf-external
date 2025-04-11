resource "null_resource" "image_tag_tracker" {
  triggers = {
    image_tag = var.image_tag
  }
}

resource "null_resource" "wait_for_container" {
  depends_on = [google_compute_instance.vm_instance]
  provisioner "local-exec" {
    command = <<-EOT
      while true; do
        if gcloud compute instances get-serial-port-output ${var.instance_name} --zone ${var.zone} --project ${var.project_id} | grep -q "CONTAINER_SETUP_COMPLETE"; then
          echo "Container setup completed successfully"
          exit 0
        fi
        
        sleep 60
      done
    EOT
  }
}
