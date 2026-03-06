########################################################################################################################
# DevOps Loop on IKS — Self-Managed Solution
#
# This solution wrapper calls the root module which handles:
#   • Optional VPC + Subnet provisioning
#   • Optional IKS cluster provisioning
#   • Emissary-ingress API gateway installation
#   • HCL Harbor registry authentication
#   • TLS secret management
#   • DevOps Loop Helm deployment with all capability toggles
########################################################################################################################

locals {
  prefix = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""
}

########################################################################################################################
# Resource Group
########################################################################################################################

module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.4.7"
  existing_resource_group_name = var.existing_resource_group_name
}

########################################################################################################################
# DevOps Loop on IKS — Root module
########################################################################################################################

module "devops_loop_on_iks" {
  source = "../.."

  # Core
  region                      = var.region
  prefix                      = var.prefix
  existing_resource_group_name = var.existing_resource_group_name
  resource_tags               = var.resource_tags

  # Networking
  existing_vpc_id    = var.existing_vpc_id
  existing_subnet_id = var.existing_subnet_id

  # Cluster
  existing_cluster_id = var.existing_cluster_id
  kubernetes_version  = var.kubernetes_version
  worker_flavor       = var.worker_flavor
  worker_count        = var.worker_count

  # DevOps Loop application
  devops_loop_namespace     = var.devops_loop_namespace
  devops_loop_chart_version = var.devops_loop_chart_version
  devops_loop_domain        = var.devops_loop_domain
  license_server            = var.license_server

  # Registry
  hcl_harbor_username   = var.hcl_harbor_username
  hcl_harbor_cli_secret = var.hcl_harbor_cli_secret

  # TLS
  tls_certificate = var.tls_certificate
  tls_private_key = var.tls_private_key

  # Storage
  rwo_storage_class = var.rwo_storage_class
  rwx_storage_class = var.rwx_storage_class

  # Emissary
  emissary_chart_version = var.emissary_chart_version

  # SMTP
  smtp_host         = var.smtp_host
  smtp_port         = var.smtp_port
  smtp_from_address = var.smtp_from_address
  smtp_username     = var.smtp_username
  smtp_password     = var.smtp_password

  # Capabilities
  enable_plan    = var.enable_plan
  enable_code    = var.enable_code
  enable_control = var.enable_control
  enable_build   = var.enable_build
  enable_test    = var.enable_test
  enable_release = var.enable_release
  enable_deploy  = var.enable_deploy
  enable_measure = var.enable_measure
}
