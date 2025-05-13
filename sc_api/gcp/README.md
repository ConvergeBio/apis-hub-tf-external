# Single Cell GCP Terraform Module

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 4.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_attached_disk.a_disk_tf](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_attached_disk) | resource |
| [google_compute_disk.disk_tf](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk) | resource |
| [google_compute_instance.vm_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [null_resource.image_tag_tracker](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_container](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_converge_project_id"></a> [converge\_project\_id](#input\_converge\_project\_id) | The GCP project ID where the Converge account is located | `string` | n/a | yes |
| <a name="input_customer_id"></a> [customer\_id](#input\_customer\_id) | The customer ID used for Model Registry artifacts naming | `string` | n/a | yes |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | The size of the disk to attach to the instance | `number` | `500` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Whether to enable external IP for the instance | `bool` | `false` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | The tag of the container image in Artifact Registry | `string` | n/a | yes |
| <a name="input_instance_image_name"></a> [instance\_image\_name](#input\_instance\_image\_name) | The name of the container image to use | `string` | `"deeplearning-platform-release/common-cu124-ubuntu-2204-py310"` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name for the GCE instance | `string` | `"converge-sc-vm"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the instance | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type for the GCE instance. Available options:<br/>  - a2-highgpu-2g: 2x NVIDIA A100 GPUs<br/>  - a2-highgpu-1g: 1x NVIDIA A100 GPU<br/>  - g2-standard-96: 8x NVIDIA L4 GPUs<br/>  - g2-standard-48: 4x NVIDIA L4 GPUs | `string` | `"a2-highgpu-2g"` | no |
| <a name="input_network"></a> [network](#input\_network) | The VPC network to host the instance in | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where resources will be created | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where resources will be created | `string` | `"us-central1"` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | The email of the service account to use for the instance | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The subnetwork to host the instance in | `string` | n/a | yes |
| <a name="input_wandb_api_key"></a> [wandb\_api\_key](#input\_wandb\_api\_key) | The Wandb API key | `string` | n/a | yes |
| <a name="input_zone"></a> [zone](#input\_zone) | The zone to host the instance in | `string` | `"us-central1-a"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | Name of the created instance |
