resource "local_file" "kubeconfig" {
  depends_on   = [azurerm_kubernetes_cluster.demo]
  filename     = "kubeconfig"
  content      = azurerm_kubernetes_cluster.demo.kube_config_raw
}