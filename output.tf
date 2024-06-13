data "vultr_kubernetes_node_pools" "nodepools" {
  cluster_id = vultr_kubernetes.k8.id
}

output "vultr_kube_config" {
  value     = vultr_kubernetes.k8.kube_config
  sensitive = true
}

output "vultr_kubernetes_host" {
  value = vultr_kubernetes.k8.endpoint
}

output "cluster_id" {
  value = vultr_kubernetes.k8.id
}

output "argocd" {
  value = helm_release.argocd.metadata
}

output "node_external_ips" {
  value = [for node in data.vultr_kubernetes_node.nodepools.nodes : node.external_ip]
}
