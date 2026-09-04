terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # O state local é suficiente para um ambiente único e sem colaboração).
  # O backend S3 + DynamoDB entra no projeto 2.
  # backend "s3" {
  #   bucket         = "devops-01-ec2-cicd-tfstate"
  #   key            = "devops-01-ec2-cicd/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy    = "Terraform"
    }
  }
}