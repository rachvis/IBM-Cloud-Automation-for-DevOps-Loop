########################################################################################################################
# Terraform and Provider Version Constraints — Self-Managed Solution
########################################################################################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.73.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.0"
    }
  }
}
