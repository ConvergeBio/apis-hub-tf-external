resource "null_resource" "image_tag_tracker" {
  triggers = {
    image_tag = var.image_tag
  }
}

resource "null_resource" "wait_for_container" {
  depends_on = [aws_instance.vm_instance]

  provisioner "local-exec" {
    command = <<-EOT
      while true; do
        EVENTS=$(aws logs get-log-events \
          --log-group-name "${local.log_group_name}" \
          --log-stream-name "${var.instance_name}-container" \
          --region "${var.region}" \
          --limit 50 \
          --query 'events[].message' \
          --output text)

        if echo "$EVENTS" | grep -q "CONTAINER_SETUP_COMPLETE"; then
          echo "Container setup completed successfully"
          exit 0
        fi

        echo "Waiting for container setup to complete..."
        sleep 30
      done
    EOT
  }

  triggers = {
    image_tag = var.image_tag
  }
}
