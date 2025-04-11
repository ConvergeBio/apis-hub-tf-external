variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "converge_project_id" {
  description = "The GCP project ID where the Converge account is located"
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "instance_name" {
  description = "Name for the GCE instance"
  type        = string
  default     = "converge-sc-vm"
}

variable "customer_id" {
  description = "The customer ID used for Model Registry artifacts naming"
  type        = string

}
variable "wandb_api_key" {
  description = "The Wandb API key"
  type        = string
}


variable "machine_type" {
  description = <<EOT
  The machine type for the GCE instance. Available options:
  - a2-highgpu-2g: 2x NVIDIA A100 GPUs
  - a2-highgpu-1g: 1x NVIDIA A100 GPU
  - g2-standard-96: 8x NVIDIA L4 GPUs
  - g2-standard-48: 4x NVIDIA L4 GPUs
  EOT
  type        = string
  default     = "a2-highgpu-2g"
  validation {
    condition     = contains(["a2-highgpu-2g", "a2-highgpu-1g", "g2-standard-96", "g2-standard-48"], var.machine_type)
    error_message = "The machine_type must be a valid GPU instance type. Allowed values are: a2-highgpu-2g, a2-highgpu-1g, g2-standard-96, g2-standard-48."
  }
}

variable "instance_image_name" {
  description = "The name of the container image to use"
  type        = string
  default     = "deeplearning-platform-release/common-cu124-ubuntu-2204-py310"
}

variable "disk_size" {
  description = "The size of the disk to attach to the instance"
  type        = number
  default     = 500
}

variable "image_tag" {
  description = "The tag of the container image in Artifact Registry"
  type        = string
}

variable "network" {
  description = "The VPC network to host the instance in"
  type        = string
}

variable "subnetwork" {
  description = "The subnetwork to host the instance in"
  type        = string
}

variable "zone" {
  description = "The zone to host the instance in"
  type        = string
  default     = "us-central1-a"
}

variable "enable_public_ip" {
  description = "Whether to enable external IP for the instance"
  type        = bool
  default     = false
}

variable "service_account_email" {
  description = "The email of the service account to use for the instance"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the instance"
  type        = map(string)
  default     = {}
}
