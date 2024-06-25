# Terraform POC - Vultr cluster

This is a dummy terraform repo config for testing terraform features.

- Vultr K8s Cluster
- k8s infraservices namespace
- main module

## Installing

1. Configure `envs` on Terraform platform. (Important: set `enable_letscrypt` to `false`)

Will probably create only the K8S Cluster and other run will fail.

2. Re-run via UI

It will create namespace and helm releases.

3. Create letscrypt issuer

Configure (Important: set `enable_letscrypt` to `true`) and rerun terraform
