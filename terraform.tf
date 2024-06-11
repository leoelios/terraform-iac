# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {

  cloud {
    organization = "leoelios"

    workspaces {
      name = "iac"
    }
  }

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.20.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.30.0"
    }
  }

  required_version = "~> 1.2"
}
