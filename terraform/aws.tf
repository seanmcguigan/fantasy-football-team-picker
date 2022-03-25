terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    encrypt        = true
    bucket         = "tf-remote-bucket-gonk"
    dynamodb_table = "tf-lock-table"
    region         = "us-east-1"
    key            = "terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}
