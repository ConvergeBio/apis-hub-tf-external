locals {
  roles = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  ssm_commands = {
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
      if docker ps | grep -q '${local.image_repository}:${var.image_tag}'; then \
        echo 'Correct image tag is already running'; exit 0; fi
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
  ssm_payload = jsonencode({
    commands = [
      local.ssm_commands.setup,
      local.ssm_commands.login,
      local.ssm_commands.check_running,
      local.ssm_commands.pull_image,
      local.ssm_commands.stop_container,
      local.ssm_commands.run_container,
      local.ssm_commands.wait_for_api,
      local.ssm_commands.log_completion
    ]
  })

  log_group_name   = "/converge/${var.instance_name}-${var.customer_id}-${var.region}"
  image_repository = "${var.converge_account_id}.dkr.ecr.${var.region}.amazonaws.com/converge-sc/api"
}
