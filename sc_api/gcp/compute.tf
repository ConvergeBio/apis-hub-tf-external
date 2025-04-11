resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = var.instance_image_name
      size  = 100
    }
  }

  guest_accelerator {
    type  = local.gpu_type
    count = local.gpu_count
  }

  scheduling {
    on_host_maintenance = "TERMINATE"
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {
      }
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    set -x

    # Wait for the persistent disk to be attached
    echo "Waiting for disk to be attached..."
    while [ ! -e /dev/disk/by-id/google-persistent-disk-1 ] && 
          [ ! -b /dev/sdb ]; do
      echo "Waiting for disk to appear..."
      sleep 5
    done

    # Create mount point
    mkdir -p /data

    # Find the device path with more fallback options
    DEVICE_NAME=$(readlink -f /dev/disk/by-id/google-persistent-disk-1 2>/dev/null || 
                  echo "/dev/sdb")
    echo "Found device at: $DEVICE_NAME"
    
    # Check if the device already has a filesystem
    if ! blkid $DEVICE_NAME; then
      echo "New volume detected, formatting with ext4..."
      mkfs -t ext4 $DEVICE_NAME
    fi
    
    # Get UUID for more reliable mounting
    UUID=$(blkid -s UUID -o value $DEVICE_NAME)
    if [ -z "$UUID" ]; then
      echo "Failed to get UUID for $DEVICE_NAME"
      exit 1
    fi

    # Update fstab using UUID
    if ! grep -q $UUID /etc/fstab; then
      echo "UUID=$UUID /data ext4 discard,defaults,nofail 0 2" >> /etc/fstab
    fi

    # Mount all filesystems from fstab
    mount -a

    # Verify mount was successful
    if ! mountpoint -q /data; then
      echo "Failed to mount /data"
      exit 1
    fi

    # Set appropriate permissions for data directory
    chmod 777 /data

    # Ensure directory exists
    mkdir -p /root/.docker

    # Write Docker config with credential helper
    cat > /root/.docker/config.json <<'DOCKERCONFIG'
{
  "credHelpers": {
    "gcr.io": "gcloud",
    "us.gcr.io": "gcloud",
    "eu.gcr.io": "gcloud",
    "asia.gcr.io": "gcloud",
    "staging-k8s.gcr.io": "gcloud",
    "marketplace.gcr.io": "gcloud",
    "us-central1-docker.pkg.dev": "gcloud"
  }
}
DOCKERCONFIG

    # Install Nvidia drivers
    sudo /opt/deeplearning/install-driver.sh

    # Pull and run the container
    docker pull ${local.image_repository}:${var.image_tag}
    docker run -d \
    --name converge-sc \
    -e CUSTOMER_ID=${var.customer_id} \
    -e WANDB_API_KEY=${var.wandb_api_key} \
    --restart always \
    --gpus all \
    -p 8000:8000 \
    -v /data:/app/storage \
    --log-driver=gcplogs \
    --log-opt gcp-project=${var.project_id} \
    --log-opt gcp-log-cmd=true \
    --log-opt labels=customer_id \
    ${local.image_repository}:${var.image_tag}

    # Wait for the API to be ready
    echo "Waiting for the API to be ready..."
    until $(curl --output /dev/null --silent --fail http://localhost:8000/ping); do
      printf '.'
      sleep 5
    done
    echo "API is ready and responding to health checks!"

    # Signal completion in serial port output
    echo "CONTAINER_SETUP_COMPLETE" > /dev/ttyS0
  EOF

  service_account {
    email = var.service_account_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  lifecycle {
    replace_triggered_by = [
      null_resource.image_tag_tracker
    ]
  }

  labels = var.labels
}
