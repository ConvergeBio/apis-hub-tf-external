resource "null_resource" "image_tag_tracker" {
  triggers = {
    image_tag = var.image_tag
  }
}
resource "null_resource" "setup_instance" {
  depends_on = [aws_instance.vm_instance]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for the instance to be available in SSM
      ${local.ssm_readiness_check}

      # Run the update command through SSM
      PARAMS='${local.ssm_setup_payload}'

      command_id=$(aws ssm send-command \
      --instance-ids ${aws_instance.vm_instance.id} \
      --document-name "AWS-RunShellScript" \
      --parameters "$PARAMS" \
      --region ${var.region} \
      --query 'Command.CommandId' --output text)
      echo "Waiting for SSM command $command_id to complete..."
      aws ssm wait command-executed --command-id $command_id --instance-id ${aws_instance.vm_instance.id} --region ${var.region}
            
      # Check command status
      status=$(aws ssm get-command-invocation --command-id $command_id --instance-id ${aws_instance.vm_instance.id} --region ${var.region} --query "Status" --output text)
      if [ "$status" != "Success" ]; then
        echo "Container update failed with status: $status"
        exit 1
      fi
      
      echo "Instance setup completed successfully"
    EOT
  }
}

resource "null_resource" "update_container" {
  triggers = {
    image_tag = var.image_tag
  }

  depends_on = [
    aws_instance.vm_instance,
    null_resource.setup_instance
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for the instance to be available in SSM
      ${local.ssm_readiness_check}
      
      # Run the update command through SSM
      PARAMS='${local.ssm_update_payload}'

      command_id=$(aws ssm send-command \
      --instance-ids ${aws_instance.vm_instance.id} \
      --document-name "AWS-RunShellScript" \
      --parameters "$PARAMS" \
      --region ${var.region} \
      --query 'Command.CommandId' --output text)
      echo "Waiting for SSM command $command_id to complete..."
      aws ssm wait command-executed --command-id $command_id --instance-id ${aws_instance.vm_instance.id} --region ${var.region}
            
      # Check command status
      status=$(aws ssm get-command-invocation --command-id $command_id --instance-id ${aws_instance.vm_instance.id} --region ${var.region} --query "Status" --output text)
      if [ "$status" != "Success" ]; then
        echo "Container update failed with status: $status"
        exit 1
      fi
      
      echo "Container updated successfully to version ${var.image_tag}"
    EOT
  }
}

resource "null_resource" "wait_for_container" {
  depends_on = [
    aws_instance.vm_instance,
    null_resource.update_container,
    null_resource.setup_instance
  ]

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
        
        if echo "$EVENTS" | grep -q "CONTAINER_UPDATE_COMPLETE_${var.image_tag}"; then
          echo "Container update to version ${var.image_tag} completed successfully"
          exit 0
        fi

        echo "Waiting for container setup/update to complete..."
        sleep 30
      done
    EOT
  }
}
