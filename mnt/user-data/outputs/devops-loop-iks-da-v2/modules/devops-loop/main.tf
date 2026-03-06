########################################################################################################################
# Namespaces
########################################################################################################################

resource "kubernetes_namespace" "emissary" {
  metadata {
    name = "emissary"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "devops_loop" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

########################################################################################################################
# Emissary-ingress — CRDs (must precede the controller)
########################################################################################################################

resource "helm_release" "emissary_crds" {
  name             = "emissary-crds"
  repository       = "https://app.getambassador.io"
  chart            = "emissary-ingress-crds"
  version          = var.emissary_chart_version
  namespace        = "emissary"
  create_namespace = false
  timeout          = 600
  wait             = true

  depends_on = [kubernetes_namespace.emissary]
}

########################################################################################################################
# Emissary-ingress — Controller
########################################################################################################################

resource "helm_release" "emissary_ingress" {
  name             = "emissary-ingress"
  repository       = "https://app.getambassador.io"
  chart            = "emissary-ingress"
  version          = var.emissary_chart_version
  namespace        = "emissary"
  create_namespace = false
  timeout          = 900
  wait             = true

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "service.ports[0].name"
    value = "http"
  }
  set {
    name  = "service.ports[0].port"
    value = "80"
  }
  set {
    name  = "service.ports[0].targetPort"
    value = "8080"
  }
  set {
    name  = "service.ports[1].name"
    value = "https"
  }
  set {
    name  = "service.ports[1].port"
    value = "443"
  }
  set {
    name  = "service.ports[1].targetPort"
    value = "8443"
  }
  set {
    name  = "service.ports[2].name"
    value = "deploy-wss"
  }
  set {
    name  = "service.ports[2].port"
    value = "7919"
  }
  set {
    name  = "service.ports[2].targetPort"
    value = "7919"
  }
  set {
    name  = "service.ports[3].name"
    value = "build-wss"
  }
  set {
    name  = "service.ports[3].port"
    value = "7920"
  }
  set {
    name  = "service.ports[3].targetPort"
    value = "7920"
  }
  set {
    name  = "service.ports[4].name"
    value = "control-ssh"
  }
  set {
    name  = "service.ports[4].port"
    value = "9022"
  }
  set {
    name  = "service.ports[4].targetPort"
    value = "9022"
  }

  depends_on = [
    kubernetes_namespace.emissary,
    helm_release.emissary_crds
  ]
}

########################################################################################################################
# HCL Harbor image-pull secret
########################################################################################################################

resource "kubernetes_secret" "hcl_harbor_pull" {
  metadata {
    name      = "hcl-entitlement-key"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "hclcr.io" = {
          username = var.hcl_harbor_username
          password = var.hcl_harbor_cli_secret
          auth     = base64encode("${var.hcl_harbor_username}:${var.hcl_harbor_cli_secret}")
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.devops_loop]
}

########################################################################################################################
# TLS secret
########################################################################################################################

resource "kubernetes_secret" "tls" {
  metadata {
    name      = "devops-loop-tls"
    namespace = var.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = var.tls_certificate
    "tls.key" = var.tls_private_key
  }

  depends_on = [kubernetes_namespace.devops_loop]
}

########################################################################################################################
# DevOps Loop Helm release
########################################################################################################################

resource "helm_release" "devops_loop" {
  name             = "${local.prefix}devops-loop"
  repository       = "oci://hclcr.io/devops-automation-helm"
  chart            = "hcl-devops-loop"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = false
  timeout          = 1800
  wait             = true

  # Registry authentication
  repository_username = var.hcl_harbor_username
  repository_password = var.hcl_harbor_cli_secret

  # Domain and TLS
  set {
    name  = "global.domain"
    value = var.domain
  }
  set {
    name  = "global.tlsSecretName"
    value = kubernetes_secret.tls.metadata[0].name
  }

  # License
  set {
    name  = "global.licenseServer"
    value = var.license_server
  }

  # Storage
  set {
    name  = "global.storageClass.rwo"
    value = var.rwo_storage_class
  }
  set {
    name  = "global.storageClass.rwx"
    value = var.rwx_storage_class
  }

  # Image pull secret
  set {
    name  = "global.imagePullSecrets[0]"
    value = kubernetes_secret.hcl_harbor_pull.metadata[0].name
  }

  # Capabilities
  set {
    name  = "capabilities.plan.enabled"
    value = var.enable_plan
  }
  set {
    name  = "capabilities.code.enabled"
    value = var.enable_code
  }
  set {
    name  = "capabilities.control.enabled"
    value = var.enable_control
  }
  set {
    name  = "capabilities.build.enabled"
    value = var.enable_build
  }
  set {
    name  = "capabilities.test.enabled"
    value = var.enable_test
  }
  set {
    name  = "capabilities.release.enabled"
    value = var.enable_release
  }
  set {
    name  = "capabilities.deploy.enabled"
    value = var.enable_deploy
  }
  set {
    name  = "capabilities.measure.enabled"
    value = var.enable_measure
  }

  # SMTP (only configured when smtp_host is provided)
  dynamic "set" {
    for_each = var.smtp_host != "" ? [1] : []
    content {
      name  = "smtp.host"
      value = var.smtp_host
    }
  }
  dynamic "set" {
    for_each = var.smtp_host != "" ? [1] : []
    content {
      name  = "smtp.port"
      value = var.smtp_port
    }
  }
  dynamic "set" {
    for_each = var.smtp_host != "" ? [1] : []
    content {
      name  = "smtp.fromAddress"
      value = var.smtp_from_address
    }
  }
  dynamic "set" {
    for_each = var.smtp_host != "" && var.smtp_username != "" ? [1] : []
    content {
      name  = "smtp.username"
      value = var.smtp_username
    }
  }
  dynamic "set" {
    for_each = var.smtp_host != "" && var.smtp_password != "" ? [1] : []
    content {
      name  = "smtp.password"
      value = var.smtp_password
    }
  }

  depends_on = [
    kubernetes_namespace.devops_loop,
    kubernetes_secret.hcl_harbor_pull,
    kubernetes_secret.tls,
    helm_release.emissary_ingress
  ]
}

locals {
  prefix = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""
}
