terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.54.1"
    }
    shell = {
      source  = "scottwinkler/shell"
      version = ">= 1.7.10"
    }
  }
}