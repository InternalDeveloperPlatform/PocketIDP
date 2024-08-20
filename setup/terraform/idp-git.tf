resource "kubernetes_namespace" "gitea" {
  metadata {
    name = "gitea"
  }
}

resource "kubernetes_secret_v1" "gitea_cert" {
  depends_on = [ kubernetes_namespace.gitea ]
  metadata {
    name = "gitea-tls"
    namespace = "gitea"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = base64decode(var.tls_cert_string)
    "tls.key" = base64decode(var.tls_key_string)
  }
}

resource "helm_release" "gitea" {
  name             = "gitea"
  namespace        = "gitea"
  create_namespace = true
  repository       = "https://dl.gitea.com/charts/"

  chart   = "gitea"
  version = "10.3.0"
  wait    = true
  timeout = 600

  values = [
    file("${path.module}/gitea_values.yaml")
  ]

  depends_on = [kubernetes_secret_v1.gitea_cert]
}
