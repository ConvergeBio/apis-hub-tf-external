resource "aws_instance" "vm_instance" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.enable_public_ip
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  key_name                    = var.key_pair_name


  user_data = <<-EOF
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

    # Login to ECR
    aws ecr get-login-password --region ${var.region} | docker login --username AWS \
    --password-stdin ${var.converge_account_id}.dkr.ecr.${var.region}.amazonaws.com

    # Pull and run the container
    docker pull ${local.image_repository}:${var.image_tag}
    docker run -d \
    --name converge-sc \
    -e CUSTOMER_ID="${var.customer_id}" \
    -e WANDB_API_KEY="${var.wandb_api_key}" \
    --gpus all \
    -p 8000:8000 \
    -v /data:/app/storage \
    --log-driver=awslogs \
    --log-opt awslogs-region=${var.region} \
    --log-opt awslogs-group=${local.log_group_name} \
    --log-opt awslogs-stream=${var.instance_name}-container \
    --log-opt awslogs-create-group=true \
    --restart always \
    ${local.image_repository}:${var.image_tag}

    # Wait for the API to be ready
    echo "Waiting for the API to be ready..."

    until curl --output /dev/null --silent --fail http://localhost:8000/ping; do
      printf '.'
      sleep 5
    done
    echo "API is ready and responding to health checks!"
      
    # Explicitly send completion message to CloudWatch Logs
    aws logs put-log-events \
    --log-group-name "${local.log_group_name}" \
    --log-stream-name "${var.instance_name}-container" \
    --log-events timestamp=$(($(date +%s%N)/1000000)),message="CONTAINER_SETUP_COMPLETE" \
    --region "${var.region}"
  EOF

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  lifecycle {
    replace_triggered_by = [
      null_resource.image_tag_tracker
    ]
  }

  tags = merge(var.labels, {
    "Name" = "${var.instance_name}-${var.image_tag}"
    "Tag"  = var.image_tag
  })
}
