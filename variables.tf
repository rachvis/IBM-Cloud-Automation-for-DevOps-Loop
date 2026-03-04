##############################################################################
# Core IBM Cloud Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "The IBM Cloud platform API key used to provision IAM-enabled resources."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region where resources will be deployed (e.g. us-south, eu-gb, au-syd)."
  type        = string
  default     = "us-south"
}

variable "prefix" {
  description = "Unique identifier prefix applied to all resource names. Must start with a lowercase letter, use only lowercase letters, numbers, and hyphens, and be 16 characters or fewer."
  type        = string
  default     = "devops-loop"

  validation {
    error_message = "Prefix must begin with a lowercase letter and contain only lowercase letters, numbers, and - characters. Must end with a letter or number and be 16 or fewer characters."
    condition     = can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix)) && length(var.prefix) <= 16
  }
}

variable "resource_group_name" {
  description = "Name of the IBM Cloud resource group where resources will be deployed."
  type        = string
  default     = "Default"
}

variable "tags" {
  description = "List of tags to attach to all provisioned IBM Cloud resources."
  type        = list(string)
  default     = []
}

##############################################################################
# VPC Variables
##############################################################################

variable "use_existing_vpc" {
  description = "Set to true to reuse an existing VPC. Requires existing_vpc_name and existing_subnet_name."
  type        = bool
  default     = false
}

variable "existing_vpc_name" {
  description = "Name of the existing VPC (only used when use_existing_vpc = true)."
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of the existing subnet within the VPC (only used when use_existing_vpc = true)."
  type        = string
  default     = ""
}

##############################################################################
# IKS Cluster Variables
##############################################################################

variable "existing_cluster_id" {
  description = "ID of an existing IKS cluster. Leave empty to provision a new cluster."
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version for the new IKS cluster. Leave empty for the IBM Cloud default."
  type        = string
  default     = ""
}

variable "worker_flavor" {
  description = "Machine type (flavor) for IKS worker nodes. DevOps Loop requires at least 8 vCPU / 32 GB RAM per node."
  type        = string
  default     = "bx2.8x32"
}

variable "worker_count" {
  description = "Number of worker nodes in the IKS cluster. Minimum 3 for production."
  type        = number
  default     = 3

  validation {
    error_message = "Worker count must be at least 1."
    condition     = var.worker_count >= 1
  }
}

##############################################################################
# Emissary-ingress Variables
##############################################################################

variable "emissary_chart_version" {
  description = "Version of the Emissary-ingress (Ambassador Edge Stack) Helm chart."
  type        = string
  default     = "3.9.1"
}

##############################################################################
# DevOps Loop Core Variables
##############################################################################

variable "devops_loop_namespace" {
  description = "Kubernetes namespace where DevOps Loop will be deployed."
  type        = string
  default     = "devops-loop"
}

variable "devops_loop_chart_version" {
  description = "Version of the HCL DevOps Loop OCI Helm chart (e.g. 1.0.3). See hclcr.io for available versions."
  type        = string
  default     = "1.0.3"
}

variable "devops_loop_domain" {
  description = "Fully qualified domain name (FQDN) for DevOps Loop, e.g. devops-loop.us-south.containers.appdomain.com. Must match the TLS certificate's CN/SAN."
  type        = string
}

variable "license_server" {
  description = "Hostname or IP of the HCL Rational License Key Server in the format @<hostname-or-ip> (e.g. @my-license-server.example.com)."
  type        = string
}

##############################################################################
# HCL Harbor Registry Credentials
##############################################################################

variable "hcl_harbor_username" {
  description = "HCL Harbor registry username (your HCL ID). Used to pull DevOps Loop container images from hclcr.io."
  type        = string
  sensitive   = true
}

variable "hcl_harbor_cli_secret" {
  description = "HCL Harbor CLI secret / pre-generated API token (from User Profile on hclcr.io). Used to authenticate image pulls."
  type        = string
  sensitive   = true
}

##############################################################################
# TLS Certificate Variables
##############################################################################

variable "tls_certificate" {
  description = "PEM-encoded TLS certificate for the DevOps Loop domain. Must be issued by a trusted CA and match devops_loop_domain."
  type        = string
  sensitive   = true
}

variable "tls_private_key" {
  description = "PEM-encoded private key corresponding to the TLS certificate."
  type        = string
  sensitive   = true
}

##############################################################################
# Storage Variables
##############################################################################

variable "rwo_storage_class" {
  description = "Kubernetes storage class for ReadWriteOnce (RWO) volumes. IBM Cloud default: ibmc-block-gold."
  type        = string
  default     = "ibmc-block-gold"
}

variable "rwx_storage_class" {
  description = "Kubernetes storage class for ReadWriteMany (RWX) volumes, required by several DevOps Loop components. IBM Cloud default: ibmc-file-gold-gid."
  type        = string
  default     = "ibmc-file-gold-gid"
}

##############################################################################
# SMTP / Email Variables
##############################################################################

variable "smtp_host" {
  description = "Hostname of the SMTP server used by DevOps Loop to send notifications."
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "Port number of the SMTP server."
  type        = string
  default     = "587"
}

variable "smtp_from_address" {
  description = "Email address used as the 'From' address for DevOps Loop notifications."
  type        = string
  default     = ""
}

variable "smtp_username" {
  description = "SMTP authentication username (leave empty if SMTP server does not require auth)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_password" {
  description = "SMTP authentication password (leave empty if SMTP server does not require auth)."
  type        = string
  sensitive   = true
  default     = ""
}

##############################################################################
# Capability Toggle Variables
# Enable or disable individual DevOps Loop capabilities.
##############################################################################

variable "enable_plan" {
  description = "Enable the DevOps Plan capability (project planning and tracking)."
  type        = bool
  default     = true
}

variable "enable_code" {
  description = "Enable the DevOps Code capability (browser-based IDE)."
  type        = bool
  default     = true
}

variable "enable_control" {
  description = "Enable the DevOps Control capability (source control management)."
  type        = bool
  default     = true
}

variable "enable_build" {
  description = "Enable the DevOps Build capability (CI pipelines and build automation)."
  type        = bool
  default     = true
}

variable "enable_test" {
  description = "Enable the DevOps Test capability (test management and execution)."
  type        = bool
  default     = true
}

variable "enable_release" {
  description = "Enable the DevOps Release capability (release management and orchestration)."
  type        = bool
  default     = true
}

variable "enable_deploy" {
  description = "Enable the DevOps Deploy capability (deployment automation)."
  type        = bool
  default     = true
}

variable "enable_measure" {
  description = "Enable the DevOps Measure capability (analytics and dashboards)."
  type        = bool
  default     = true
}
