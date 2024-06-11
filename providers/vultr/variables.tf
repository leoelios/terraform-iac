# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# variable "region" {
#   description = "AWS region"
#   default     = "us-west-1"
# }

variable "vultr_api_key" {
  description = "VULTR Api key for K8S cluster creation"
  sensitive   = true
}
