# [1] providers
terraform {
  required_version = ">= 1.5.6"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }

    random = {
        source = "hashicorp/random"
        version = "~> 3.0"
    }
  }
}

provider "aws" {
    region = "ap-northeast-2"
}