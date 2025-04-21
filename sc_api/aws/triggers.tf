resource "null_resource" "image_tag_tracker" {
  triggers = {
    image_tag = var.image_tag
  }
}

resource "null_resource" "update_container" {
  triggers = {
    image_tag = var.image_tag
  }

  depends_on = [aws_instance.vm_instance]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for the instance to be available in SSM
      # echo "Will wait 5 minutes for instance to be available in SSM..."
      # sleep 300 # 5 minutes
      
      echo "Checking if instance is registered with SSM..."
      
      INSTANCE_ID="${aws_instance.vm_instance.id}"
      REGION="${var.region}"
      MAX_RETRIES=30
      RETRY_INTERVAL=10
      count=0
      
      while [[ $count -lt $MAX_RETRIES ]]; do
        # Check if instance is registered using grep's quiet mode (-q)
        if aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --region "$REGION" --output text | grep -q "$INSTANCE_ID"; then
          echo "Instance $INSTANCE_ID is registered with SSM."
          break # Exit loop if found
        fi
      
        # Increment counter and wait
        count=$((count+1))
        if [[ $count -ge $MAX_RETRIES ]]; then
           echo "Error: Timed out waiting for instance $INSTANCE_ID to register with SSM after $MAX_RETRIES attempts."
           exit 1 # Failure
        fi
        echo "Attempt $count/$MAX_RETRIES: Instance not yet registered. Waiting $RETRY_INTERVAL seconds..."
        sleep $RETRY_INTERVAL
      done

      # Run the update command through SSM

      command_id=$(aws ssm send-command \
      --instance-ids ${aws_instance.vm_instance.id} \
      --document-name "AWS-RunShellScript" \
      --parameters "$${local.ssm_payload}" \   # <= no single quotes inside!
      --region ${var.region} \
      --output text \
      --query 'Command.CommandId')

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
  depends_on = [aws_instance.vm_instance, null_resource.update_container]

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
