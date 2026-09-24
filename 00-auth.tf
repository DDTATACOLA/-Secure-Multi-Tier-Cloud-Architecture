terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.18.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  # Configuration options

  region = var.region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "rds-secret-config"
    key    = "states/01172026/terraform.tfstate" # path to the state file inside the S3 bucket
    region = "us-east-2"
  }
}
