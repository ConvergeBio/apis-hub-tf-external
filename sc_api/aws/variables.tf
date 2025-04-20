variable "region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "converge-sc-vm"
}

variable "container_name" {
  description = "The name of the container to run"
  type        = string
  default     = "converge-sc"
}

variable "customer_id" {
  description = "The customer ID used for Model Registry artifacts naming"
  type        = string
}

variable "wandb_api_key" {
  description = "The Wandb API key"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (GPU-enabled instance)"
  type        = string
  default     = "g6e.12xlarge"
  validation {
    condition     = contains(["p4d.24xlarge", "g6e.48xlarge", "g6e.24xlarge", "g6e.16xlarge", "g6e.12xlarge"], var.instance_type)
    error_message = "The instance_type must be a valid GPU instance type. Allowed values are: p4d.24xlarge, g6e.48xlarge, g6e.24xlarge, g6e.16xlarge, g6e.12xlarge"
  }
}

variable "instance_ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-08809f9da8c76a5ae" # (us-east-1) Deep Learning AMI (Linux 2) with GPU
}

variable "disk_size" {
  description = "The size of the disk to attach to the instance"
  type        = number
  default     = 1000
}

variable "converge_account_id" {
  description = "The account ID of the Converge account"
  type        = string
}

variable "image_tag" {
  description = "The tag of the container image"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID in which to launch the instance"
  type        = string
}

variable "security_group_ids" {
  description = "The security group IDs to attach to the instance. Must include a security group that allows traffic on port 8000."
  type        = list(string)
}

variable "key_pair_name" {
  description = "The name of the key pair to use for the instance"
  type        = string
  default     = null
}

variable "enable_public_ip" {
  description = "Whether to assign a public IP address to the instance"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Tags to apply to the instance"
  type        = map(string)
  default     = {}
}
