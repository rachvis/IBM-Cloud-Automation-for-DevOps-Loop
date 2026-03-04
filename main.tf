##############################################################################
# IBM DevOps Loop on IBM Cloud Kubernetes Service (IKS)
#
# This solution:
#   1. Optionally creates a VPC, subnet, and IKS cluster
#   2. Installs IBM Secrets Manager integration for TLS certificates
#   3. Installs Emissary-ingress (Ambassador) as the API gateway / L4 LB
#   4. Registers a custom ingress domain for the cluster
#   5. Creates the image-pull secret for the HCL Harbor registry
#   6. Deploys IBM DevOps Loop via its OCI Helm chart
##############################################################################

##############################################################################
# Data Sources
##############################################################################

data "ibm_resource_group" "rg" {
  name = var.resource_group_name
}

data "ibm_is_zones" "regional" {
  region = var.region
}

# Cluster config — always fetched after cluster is ready
data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = local.cluster_id
  resource_group_id = data.ibm_resource_group.rg.id
  admin             = true

  depends_on = [
    ibm_container_vpc_cluster.devops_loop_cluster,
    time_sleep.wait_for_cluster
  ]
}

##############################################################################
# Locals
##############################################################################

locals {
  cluster_id    = var.existing_cluster_id != "" ? var.existing_cluster_id : ibm_container_vpc_cluster.devops_loop_cluster[0].id
  vpc_id        = var.use_existing_vpc ? data.ibm_is_vpc.existing[0].id : ibm_is_vpc.devops_loop[0].id
  subnet_id     = var.use_existing_vpc ? data.ibm_is_subnet.existing[0].id : ibm_is_subnet.devops_loop[0].id
  namespace     = var.devops_loop_namespace
  release_name  = "${var.prefix}-devops-loop"
  tags          = concat(var.tags, ["devops-loop", "iks", "deployable-architecture"])
}

##############################################################################
# VPC (conditional)
##############################################################################

resource "ibm_is_vpc" "devops_loop" {
  count          = var.use_existing_vpc ? 0 : 1
  name           = "${var.prefix}-vpc"
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags
}

data "ibm_is_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  name  = var.existing_vpc_name
}

##############################################################################
# Subnet (conditional)
##############################################################################

resource "ibm_is_subnet" "devops_loop" {
  count                    = var.use_existing_vpc ? 0 : 1
  name                     = "${var.prefix}-subnet-1"
  vpc                      = local.vpc_id
  zone                     = data.ibm_is_zones.regional.zones[0]
  resource_group           = data.ibm_resource_group.rg.id
  total_ipv4_address_count = 256
  tags                     = local.tags
}

data "ibm_is_subnet" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  name  = var.existing_subnet_name
}

##############################################################################
# IKS Cluster (conditional)
##############################################################################

resource "ibm_container_vpc_cluster" "devops_loop_cluster" {
  count             = var.existing_cluster_id == "" ? 1 : 0
  name              = "${var.prefix}-iks"
  vpc_id            = local.vpc_id
  flavor            = var.worker_flavor
  worker_count      = var.worker_count
  kubernetes_version = var.kubernetes_version
  resource_group_id = data.ibm_resource_group.rg.id
  tags              = local.tags
  # DevOps Loop requires a fully ready cluster including Ingress
  wait_till         = "IngressReady"

  zones {
    name      = data.ibm_is_zones.regional.zones[0]
    subnet_id = local.subnet_id
  }

  kube_config_path = "${path.module}/.kube"
}

resource "time_sleep" "wait_for_cluster" {
  depends_on      = [ibm_container_vpc_cluster.devops_loop_cluster]
  create_duration = "180s"
}

##############################################################################
# Kubernetes & Helm Providers
##############################################################################

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
  cluster_ca_certificate = base64decode(data.ibm_container_cluster_config.cluster_config.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.ibm_container_cluster_config.cluster_config.host
    token                  = data.ibm_container_cluster_config.cluster_config.token
    cluster_ca_certificate = base64decode(data.ibm_container_cluster_config.cluster_config.ca_certificate)
  }
}

##############################################################################
# DevOps Loop Namespace
##############################################################################

resource "kubernetes_namespace" "devops_loop" {
  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "devops-loop-da"
    }
  }
  depends_on = [data.ibm_container_cluster_config.cluster_config]
}

##############################################################################
# Emissary-ingress Namespace
##############################################################################

resource "kubernetes_namespace" "emissary" {
  metadata {
    name = "emissary"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  depends_on = [data.ibm_container_cluster_config.cluster_config]
}

##############################################################################
# Emissary CRDs
# DevOps Loop requires Ambassador/Emissary-ingress as its API gateway.
# CRDs must be applied before the Helm chart.
##############################################################################

resource "helm_release" "emissary_crds" {
  name             = "emissary-crds"
  repository       = "https://app.getambassador.io"
  chart            = "emissary-ingress"
  version          = var.emissary_chart_version
  namespace        = "emissary"
  create_namespace = false
  timeout          = 300
  wait             = true

  # Install only CRDs
  set {
    name  = "agent.enabled"
    value = "false"
  }

  set {
    name  = "deploymentTool"
    value = "helm"
  }

  depends_on = [kubernetes_namespace.emissary]
}

##############################################################################
# Emissary-ingress (L4 LoadBalancer + API Gateway)
# Exposes ports 80/443 (HTTP/HTTPS), 7919 (Deploy WSS),
# 7920 (Build WSS), 9022 (Control SSH) as required by DevOps Loop.
##############################################################################

resource "helm_release" "emissary_ingress" {
  name             = "emissary-ingress"
  repository       = "https://app.getambassador.io"
  chart            = "emissary-ingress"
  version          = var.emissary_chart_version
  namespace        = "emissary"
  create_namespace = false
  timeout          = 600
  wait             = true

  # HTTPS
  set {
    name  = "service.ports[0].name"
    value = "https"
  }
  set {
    name  = "service.ports[0].port"
    value = "443"
  }
  set {
    name  = "service.ports[0].targetPort"
    value = "8443"
  }

  # HTTP
  set {
    name  = "service.ports[1].name"
    value = "http"
  }
  set {
    name  = "service.ports[1].port"
    value = "80"
  }
  set {
    name  = "service.ports[1].targetPort"
    value = "8080"
  }

  # Deploy WSS (DevOps Deploy websocket)
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

  # Build WSS (DevOps Build websocket)
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

  # Control SSH (DevOps Control)
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

  depends_on = [helm_release.emissary_crds]
}

##############################################################################
# HCL Harbor Image Pull Secret
# DevOps Loop images are hosted on hclcr.io and require an entitlement key.
##############################################################################

resource "kubernetes_secret" "hcl_entitlement" {
  metadata {
    name      = "hcl-entitlement-key"
    namespace = kubernetes_namespace.devops_loop.metadata[0].name
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
}

##############################################################################
# TLS Secret (user-supplied certificate)
# The user provides their TLS cert/key for the custom domain.
# This secret is referenced by DevOps Loop's Helm chart parameter
# TLS_CERT_SECRET_NAME.
##############################################################################

resource "kubernetes_secret" "tls_cert" {
  metadata {
    name      = "${var.prefix}-tls-cert"
    namespace = kubernetes_namespace.devops_loop.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = var.tls_certificate
    "tls.key" = var.tls_private_key
  }
}

##############################################################################
# DevOps Loop Helm Release
# Chart is hosted on HCL's OCI registry: hclcr.io/devops-automation-helm
##############################################################################

resource "helm_release" "devops_loop" {
  name             = local.release_name
  repository       = "oci://hclcr.io/devops-automation-helm"
  chart            = "hcl-devops-loop"
  version          = var.devops_loop_chart_version
  namespace        = kubernetes_namespace.devops_loop.metadata[0].name
  create_namespace = false
  timeout          = 1200   # DevOps Loop is a large platform — allow 20 min
  wait             = true

  # --- Core required parameters ---

  # Domain for all DevOps Loop services
  set {
    name  = "global.domain"
    value = var.devops_loop_domain
  }

  # TLS certificate secret name
  set {
    name  = "global.ibmCertSecretName"
    value = kubernetes_secret.tls_cert.metadata[0].name
  }

  # License acceptance
  set {
    name  = "global.license"
    value = "accept"
  }

  # HCL License Server (Rational License Key Server)
  set {
    name  = "global.licenseServer"
    value = var.license_server
  }

  # --- Storage classes ---

  # RWO storage (IBM Cloud Block Storage — fast, single-node)
  set {
    name  = "global.storageClass"
    value = var.rwo_storage_class
  }

  # RWX storage (IBM Cloud File Storage — shared, multi-node)
  set {
    name  = "global.rwxStorageClass"
    value = var.rwx_storage_class
  }

  # --- Image registry ---
  set {
    name  = "global.imageRegistry"
    value = "hclcr.io"
  }

  set {
    name  = "global.imagePullSecret"
    value = kubernetes_secret.hcl_entitlement.metadata[0].name
  }

  # --- Email / SMTP ---
  set {
    name  = "global.smtpHost"
    value = var.smtp_host
  }
  set {
    name  = "global.smtpPort"
    value = var.smtp_port
  }
  set {
    name  = "global.smtpFromAddress"
    value = var.smtp_from_address
  }

  # Optional SMTP auth
  dynamic "set_sensitive" {
    for_each = var.smtp_username != "" ? [1] : []
    content {
      name  = "global.smtpUsername"
      value = var.smtp_username
    }
  }

  dynamic "set_sensitive" {
    for_each = var.smtp_password != "" ? [1] : []
    content {
      name  = "global.smtpPassword"
      value = var.smtp_password
    }
  }

  # --- Capability toggles ---
  set {
    name  = "devopsPlan.enabled"
    value = var.enable_plan
  }
  set {
    name  = "devopsCode.enabled"
    value = var.enable_code
  }
  set {
    name  = "devopsControl.enabled"
    value = var.enable_control
  }
  set {
    name  = "devopsBuild.enabled"
    value = var.enable_build
  }
  set {
    name  = "devopsTest.enabled"
    value = var.enable_test
  }
  set {
    name  = "devopsRelease.enabled"
    value = var.enable_release
  }
  set {
    name  = "devopsDeploy.enabled"
    value = var.enable_deploy
  }
  set {
    name  = "devopsMeasure.enabled"
    value = var.enable_measure
  }

  depends_on = [
    helm_release.emissary_ingress,
    kubernetes_secret.hcl_entitlement,
    kubernetes_secret.tls_cert
  ]
}
