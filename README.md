# apis-hub-tf-external

This repository contains Terraform modules for deploying Converge solutions across multiple cloud platforms.

## Overview

`apis-hub-tf-external` provides infrastructure-as-code for Converge Bio solutions, enabling consistent deployment across different cloud providers.<br> 
Each solution is organized in its own directory and contains Terraform configurations for supported cloud platforms.

## Solutions

### Single Cell

Currently, the repository includes Terraform modules for the Single Cell solution with support for:

- AWS
- GCP

Each cloud implementation includes all necessary resources, IAM permissions, networking, and storage components required to run the Single Cell solution.

## Usage

To use a specific solution, reference the appropriate module in your Terraform configuration:

```hcl
module "single_cell_aws" {
  source = "git::ssh://git@github.com/ConvergeBio/apis-hub-tf-external.git//sc_api/aws?ref=vX.Y.Z"
  
  # Required and optional parameters
  # See the README.md within each module for specific configuration options
}
```

## Structure

```
apis-hub-tf-external/
├── sc_api/
│   ├── aws/      # AWS Terraform module
│   └── gcp/      # GCP Terraform module
├── [future_solution]/
│   ├── .../
└── README.md
```

## Requirements

- Terraform >= 0.14
- Access to AWS and/or GCP with appropriate permissions
- Knowledge of the specific requirements for each solution