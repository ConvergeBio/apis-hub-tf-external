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
    RETRY_INTERVAL=15
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
  EOT

  ssm_setup_commands = {
    setup = <<-EOT
      #!/bin/bash -e
      echo "Setting up instance"
    EOT

    ebs_mount_script = <<-EOF
      #!/bin/bash
      set -e
      set -x
      
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
      #!/bin/bash -e
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

    pull_image = <<-EOT
      docker pull ${local.image_repository}:${var.image_tag}
    EOT

    stop_container = <<-EOT
      docker stop ${var.container_name} || true
      docker rm -f ${var.container_name} || true
    EOT

    run_container = <<-EOT
      docker run -d --name ${var.container_name} \
        -e CUSTOMER_ID=${var.customer_id} \
        -e WANDB_API_KEY=${var.wandb_api_key} \
        --gpus all -p 8000:8000 -v /data:/app/storage \
        --log-driver=awslogs \
        --log-opt awslogs-region=${var.region} \
        --log-opt awslogs-group=${local.log_group_name} \
        --log-opt awslogs-stream=${var.instance_name}-container \
        --log-opt awslogs-create-group=true \
        --restart always \
        ${local.image_repository}:${var.image_tag}
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
