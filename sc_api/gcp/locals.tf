locals {
  machine_configs = {
    "a2-highgpu-2g"  = { count = 2, type = "nvidia-tesla-a100" }
    "a2-highgpu-1g"  = { count = 1, type = "nvidia-tesla-a100" }
    "g2-standard-96" = { count = 8, type = "nvidia-l4" }
    "g2-standard-48" = { count = 4, type = "nvidia-l4" }
  }

  gpu_count        = local.machine_configs[var.machine_type].count
  gpu_type         = local.machine_configs[var.machine_type].type
  image_repository = "${var.converge_project_id}.dkr.ecr.${var.region}.amazonaws.com/converge-sc/api"
}
