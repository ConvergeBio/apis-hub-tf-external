# Single Cell AWS Terraform Module

## Example Usage

```hcl
module "sc_api_aws" {
    source = "git::ssh://git@github.com/ConvergeBio/apis-hub-tf-external.git//sc_api/aws?ref=v0.0.4"
    
    image_tag           = "0.0.4"
    subnet_id           = "subnet-1234567890"
    converge_account_id = "123456789012"
    customer_id         = "customer-abc"
    wandb_api_key       = "00000000000000000000000000000000"
    security_group_ids  = ["sg-1234567890"]

    labels = {
        environment = "production"
        team        = "data-science" 
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.67.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.container_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ebs_volume.data_disk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_iam_instance_profile.instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.vm_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_volume_attachment.data_disk_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [null_resource.image_tag_tracker](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_container](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_converge_account_id"></a> [converge\_account\_id](#input\_converge\_account\_id) | The account ID of the Converge account | `string` | n/a | yes |
| <a name="input_customer_id"></a> [customer\_id](#input\_customer\_id) | The customer ID used for Model Registry artifacts naming | `string` | n/a | yes |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | The size of the disk to attach to the instance | `number` | `500` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Whether to assign a public IP address to the instance | `bool` | `false` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | The tag of the container image | `string` | n/a | yes |
| <a name="input_instance_ami"></a> [instance\_ami](#input\_instance\_ami) | AMI ID for the EC2 instance | `string` | `"ami-08809f9da8c76a5ae"` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name for the EC2 instance | `string` | `"converge-sc-vm"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type (GPU-enabled instance) | `string` | `"g4dn.12xlarge"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | The name of the key pair to use for the instance | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Tags to apply to the instance | `map(string)` | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to create resources in | `string` | `"us-east-1"` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | The security group IDs to attach to the instance. Must include a security group that allows traffic on port 8000. | `list(string)` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | The subnet ID in which to launch the instance | `string` | n/a | yes |
| <a name="input_wandb_api_key"></a> [wandb\_api\_key](#input\_wandb\_api\_key) | The Wandb API key | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the created EC2 instance |
| <a name="output_instance_public_ip"></a> [instance\_public\_ip](#output\_instance\_public\_ip) | Public IP address of the created instance (if enabled) |
