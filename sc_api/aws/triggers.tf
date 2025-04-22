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
      --comment "${var.instance_name}-${var.customer_id}-initial-setup" \
      --parameters "$PARAMS" \
      --region ${var.region} \
      --query 'Command.CommandId' --output text)
      echo "Waiting for SSM command $command_id to complete..."
      
      wait_count=0
      WAIT_MAX_RETRIES=30
      WAIT_RETRY_INTERVAL=15
      
      while [[ $wait_count -lt $WAIT_MAX_RETRIES ]]; do
        cmd_status=$(aws ssm get-command-invocation \
          --command-id $command_id \
          --instance-id ${aws_instance.vm_instance.id} \
          --region ${var.region} \
          --query "Status" \
          --output text 2>/dev/null || echo "Pending")
        
        if [[ "$cmd_status" == "Success" ]]; then
          echo "Command completed successfully."
          break
        elif [[ "$cmd_status" == "Failed" || "$cmd_status" == "Cancelled" || "$cmd_status" == "TimedOut" ]]; then
          echo "Command failed with status: $cmd_status"
          
          # Get any error output to aid in diagnostics
          error_output=$(aws ssm get-command-invocation \
            --command-id $command_id \
            --instance-id ${aws_instance.vm_instance.id} \
            --region ${var.region} \
            --query "StandardErrorContent" \
            --output text)
            
          if [[ ! -z "$error_output" ]]; then
            echo "Error output: $error_output"
          fi
          
          exit 1
        fi
        
        wait_count=$((wait_count+1))
        if [[ $wait_count -ge $WAIT_MAX_RETRIES ]]; then
          echo "Error: Timed out waiting for command to complete after $WAIT_MAX_RETRIES attempts."
          exit 1
        fi
        
        echo "Attempt $wait_count/$WAIT_MAX_RETRIES: Command still in progress. Waiting $WAIT_RETRY_INTERVAL seconds..."
        sleep $WAIT_RETRY_INTERVAL
      done
      
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
      --comment "${var.instance_name}-${var.customer_id}-update-container-${var.image_tag}" \
      --parameters "$PARAMS" \
      --region ${var.region} \
      --query 'Command.CommandId' --output text)
      echo "Waiting for SSM command $command_id to complete..."
      
      wait_count=0
      WAIT_MAX_RETRIES=30
      WAIT_RETRY_INTERVAL=15
      
      while [[ $wait_count -lt $WAIT_MAX_RETRIES ]]; do
        cmd_status=$(aws ssm get-command-invocation \
          --command-id $command_id \
          --instance-id ${aws_instance.vm_instance.id} \
          --region ${var.region} \
          --query "Status" \
          --output text 2>/dev/null || echo "Pending")
        
        if [[ "$cmd_status" == "Success" ]]; then
          echo "Command completed successfully."
          break
        elif [[ "$cmd_status" == "Failed" || "$cmd_status" == "Cancelled" || "$cmd_status" == "TimedOut" ]]; then
          echo "Command failed with status: $cmd_status"
          
          # Get any error output to aid in diagnostics
          error_output=$(aws ssm get-command-invocation \
            --command-id $command_id \
            --instance-id ${aws_instance.vm_instance.id} \
            --region ${var.region} \
            --query "StandardErrorContent" \
            --output text)
            
          if [[ ! -z "$error_output" ]]; then
            echo "Error output: $error_output"
          fi
          
          exit 1
        fi
        
        wait_count=$((wait_count+1))
        if [[ $wait_count -ge $WAIT_MAX_RETRIES ]]; then
          echo "Error: Timed out waiting for command to complete after $WAIT_MAX_RETRIES attempts."
          exit 1
        fi
        
        echo "Attempt $wait_count/$WAIT_MAX_RETRIES: Command still in progress. Waiting $WAIT_RETRY_INTERVAL seconds..."
        sleep $WAIT_RETRY_INTERVAL
      done
      
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
