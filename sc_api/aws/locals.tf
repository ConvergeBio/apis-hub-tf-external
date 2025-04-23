locals {
  roles = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  ssm_readiness_check = <<-EOT
    # Wait for the instance to be available in SSM
    echo "Checking if instance is registered with SSM..."
    
    INSTANCE_ID="${aws_instance.vm_instance.id}"
    REGION="${var.region}"
    MAX_RETRIES=30
    RETRY_INTERVAL=30
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

    # Verify EBS volume is attached and ready
    echo "Checking if EBS volume is attached and ready..."
    count=0
    
    while [[ $count -lt $MAX_RETRIES ]]; do
      # Run command to check if the EBS volume is attached and visible
      RESULT=$(aws ssm send-command \
        --instance-ids $INSTANCE_ID \
        --document-name "AWS-RunShellScript" \
        --comment "${var.instance_name}-${var.customer_id}-check-ebs-attached" \
        --parameters '{"commands":["lsblk | grep -E \"nvme1n1|xvdh\""]}' \
        --region $REGION \
        --output text --query "Command.CommandId")
      
      # Wait for command to complete
      echo "Waiting for SSM command $RESULT to complete..."
      wait_count=0
      WAIT_MAX_RETRIES=30
      WAIT_RETRY_INTERVAL=30
      
      while [[ $wait_count -lt $WAIT_MAX_RETRIES ]]; do
        cmd_status=$(aws ssm get-command-invocation \
          --command-id $RESULT \
          --instance-id $INSTANCE_ID \
          --region $REGION \
          --query "Status" \
          --output text 2>/dev/null || echo "Pending")
        
        if [[ "$cmd_status" == "Success" ]]; then
          echo "Command completed successfully."
          
          # Check the output for the device
          OUTPUT=$(aws ssm get-command-invocation \
            --command-id $RESULT \
            --instance-id $INSTANCE_ID \
            --region $REGION \
            --query "StandardOutputContent" \
            --output text)
          
          if [[ ! -z "$OUTPUT" ]]; then
            echo "EBS volume is attached and visible: $OUTPUT"
            break 2  # Break out of both loops
          fi
          
          # If we get here, command succeeded but no output found
          break  # Break out of the wait loop but continue the EBS check loop
        elif [[ "$cmd_status" == "Failed" || "$cmd_status" == "Cancelled" || "$cmd_status" == "TimedOut" ]]; then
          echo "Command failed with status: $cmd_status"
          # Continue with the next attempt in the outer loop
          break
        fi
        
        wait_count=$((wait_count+1))
        if [[ $wait_count -ge $WAIT_MAX_RETRIES ]]; then
          echo "Error: Timed out waiting for command to complete after $WAIT_MAX_RETRIES attempts."
          exit 1
        fi
        
        echo "Attempt $wait_count/$WAIT_MAX_RETRIES: Command still in progress. Waiting $WAIT_RETRY_INTERVAL seconds..."
        sleep $WAIT_RETRY_INTERVAL
      done
    done
  EOT

  ssm_setup_commands = {
    setup = <<-EOT
      #!/bin/bash -ex
      echo "Setting up instance"
    EOT

    ebs_mount_script = <<-EOF
      #!/bin/bash -ex      
      
      # Wait for the EBS volume to be attached and stabilize
      echo "Waiting for EBS volume to be attached..."
      while [ ! -b /dev/nvme1n1 ] && [ ! -b /dev/xvdh ]; do
        sleep 5
      done

      # Determine which device name was assigned
      DEVICE_NAME="/dev/nvme1n1"
      if [ ! -b $DEVICE_NAME ]; then
        DEVICE_NAME="/dev/xvdh"
      fi
      echo "Found device at: $DEVICE_NAME"

      # Check if the device already has a filesystem
      if ! blkid $DEVICE_NAME; then
        echo "New volume detected, formatting with ext4..."
        mkfs -t ext4 $DEVICE_NAME
      fi

      # Get the UUID of the device for more reliable mounting
      UUID=$(blkid -s UUID -o value $DEVICE_NAME)
      if [ -z "$UUID" ]; then
        echo "Failed to get UUID for $DEVICE_NAME"
        exit 1
      fi

      # Create mount point
      mkdir -p /data

      # Update fstab using UUID (if not already present)
      if ! grep -q $UUID /etc/fstab; then
        echo "UUID=$UUID /data ext4 defaults,nofail 0 0" >> /etc/fstab
      fi

      # Mount all filesystems from fstab
      mount -a

      # Verify mount was successful
      if ! mountpoint -q /data; then
        echo "Failed to mount /data"
        exit 1
      fi

      # Set appropriate permissions
      sudo chown ec2-user:ec2-user /data
  EOF
  }

  ssm_setup_payload = jsonencode({
    commands = [
      local.ssm_setup_commands.setup,
      local.ssm_setup_commands.ebs_mount_script
    ]
  })

  ssm_update_commands = {
    setup = <<-EOT
      #!/bin/bash -ex
      echo "Updating container to version ${var.image_tag}"
    EOT

    login = <<-EOT
      aws ecr get-login-password --region ${var.region} | \
      docker login --username AWS --password-stdin \
      ${var.converge_account_id}.dkr.ecr.${var.region}.amazonaws.com
    EOT

    check_running = <<-EOT
      if docker ps | grep -q "${local.image_repository}:${var.image_tag}"; then \
        echo "Correct image tag is already running"; exit 0; fi
    EOT

    pull_image = "docker pull ${local.image_repository}:${var.image_tag}"

    stop_container = <<-EOT
      docker stop ${var.container_name} || true;
      docker rm -f ${var.container_name} || true;
    EOT

    run_container = <<-EOT
      # Run container with retry logic
      MAX_DOCKER_RETRIES=3
      docker_retry_count=0
      container_id=""
      
      while [ $docker_retry_count -lt $MAX_DOCKER_RETRIES ]; do
        echo "Starting container (attempt $((docker_retry_count+1))/$MAX_DOCKER_RETRIES)..."
        
        # Run container and store its ID
        container_id=$(docker run -d --name ${var.container_name} \
          -e CUSTOMER_ID=${var.customer_id} \
          -e WANDB_API_KEY=${var.wandb_api_key} \
          --gpus all -p 8000:8000 -v /data:/app/storage \
          --log-driver=awslogs \
          --log-opt awslogs-region=${var.region} \
          --log-opt awslogs-group=${local.log_group_name} \
          --log-opt awslogs-stream=${var.instance_name}-container \
          --log-opt awslogs-create-group=true \
          --restart always \
          ${local.image_repository}:${var.image_tag})
        
        # Check if container started successfully
        if [ $? -eq 0 ] && [ ! -z "$container_id" ]; then
          echo "Container started successfully with ID: $container_id"
          break
        fi
        
        echo "Failed to start container on attempt $((docker_retry_count+1))/$MAX_DOCKER_RETRIES"
        
        # Check docker and GPU status
        echo "Docker info:"
        docker info
        
        echo "NVIDIA GPU info:"
        nvidia-smi || echo "nvidia-smi not available"
        
        # Clean up any failed container instance before retry
        docker rm -f ${var.container_name} || true
        
        # If this is the last retry, show detailed logs and fail
        docker_retry_count=$((docker_retry_count+1))
        if [ $docker_retry_count -ge $MAX_DOCKER_RETRIES ]; then
          echo "ERROR: Failed to start container after $MAX_DOCKER_RETRIES attempts"
          exit 1
        fi
        
        echo "Waiting before retry..."
        sleep 10
      done
    EOT

    wait_for_api = <<-EOT
      until curl --silent --fail http://localhost:8000/ping; do sleep 5; done
    EOT

    log_completion = <<-EOT
      aws logs put-log-events \
        --log-group-name ${local.log_group_name} \
        --log-stream-name ${var.instance_name}-container \
        --log-events timestamp=$(($(date +%s%N)/1000000)),message=CONTAINER_UPDATE_COMPLETE_${var.image_tag} \
        --region ${var.region}
    EOT
  }
  ssm_update_payload = jsonencode({
    commands = [
      local.ssm_update_commands.setup,
      local.ssm_update_commands.login,
      local.ssm_update_commands.check_running,
      local.ssm_update_commands.pull_image,
      local.ssm_update_commands.stop_container,
      local.ssm_update_commands.run_container,
      local.ssm_update_commands.wait_for_api,
      local.ssm_update_commands.log_completion
    ]
  })

  log_group_name   = "/converge/${var.instance_name}-${var.customer_id}-${var.region}"
  image_repository = "${var.converge_account_id}.dkr.ecr.${var.region}.amazonaws.com/converge-sc/api"
}
