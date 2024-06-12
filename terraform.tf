# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.20.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.13.2"
    }
  }

  required_version = "~> 1.2"
}
