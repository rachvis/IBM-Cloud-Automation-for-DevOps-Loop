########################################################################################################################
# Terraform Providers
########################################################################################################################

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  visibility       = "public"
}

# Fetch the kubeconfig after the cluster is ready so Helm and Kubernetes
# providers can authenticate. The cluster_name_id resolves to either the
# provisioned cluster or the existing cluster ID passed by the user.
data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = module.devops_loop_on_iks.cluster_id
  resource_group_id = module.devops_loop_on_iks.resource_group_id
  config_dir        = "${path.module}/kubeconfig"
}

provider "helm" {
  kubernetes {
    host                   = data.ibm_container_cluster_config.cluster_config.host
    token                  = data.ibm_container_cluster_config.cluster_config.token
    cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
  }
}

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
  cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
}
