##############################################################################
# Outputs
##############################################################################

output "prefix" {
  description = "Prefix used to name all resources in this deployment."
  value       = var.prefix
}

output "region" {
  description = "IBM Cloud region where resources were deployed."
  value       = var.region
}

output "resource_group_id" {
  description = "ID of the resource group used."
  value       = data.ibm_resource_group.rg.id
}

output "resource_group_name" {
  description = "Name of the resource group used."
  value       = data.ibm_resource_group.rg.name
}

output "vpc_id" {
  description = "ID of the VPC hosting the IKS cluster."
  value       = local.vpc_id
}

output "cluster_id" {
  description = "ID of the IKS cluster where DevOps Loop is deployed."
  value       = local.cluster_id
}

output "cluster_name" {
  description = "Name of the IKS cluster."
  value       = var.existing_cluster_id == "" ? ibm_container_vpc_cluster.devops_loop_cluster[0].name : var.existing_cluster_id
}

output "devops_loop_namespace" {
  description = "Kubernetes namespace where DevOps Loop is deployed."
  value       = kubernetes_namespace.devops_loop.metadata[0].name
}

output "devops_loop_release_name" {
  description = "Helm release name for the DevOps Loop deployment."
  value       = helm_release.devops_loop.name
}

output "devops_loop_domain" {
  description = "FQDN at which DevOps Loop is accessible."
  value       = var.devops_loop_domain
}

output "emissary_release_name" {
  description = "Helm release name for the Emissary-ingress deployment."
  value       = helm_release.emissary_ingress.name
}

output "tls_secret_name" {
  description = "Name of the Kubernetes secret holding the TLS certificate."
  value       = kubernetes_secret.tls_cert.metadata[0].name
}

output "enabled_capabilities" {
  description = "Map of DevOps Loop capability toggles applied in this deployment."
  value = {
    plan    = var.enable_plan
    code    = var.enable_code
    control = var.enable_control
    build   = var.enable_build
    test    = var.enable_test
    release = var.enable_release
    deploy  = var.enable_deploy
    measure = var.enable_measure
  }
}

output "devops_loop_access_instructions" {
  description = "Step-by-step instructions to access IBM DevOps Loop after deployment."
  value       = <<-EOT
    ========================================================
    IBM DevOps Loop has been deployed to your IKS cluster.
    ========================================================

    1. Configure kubectl:
       ibmcloud ks cluster config --cluster ${local.cluster_id}

    2. Verify all pods are running:
       kubectl get pods -n ${local.namespace}

    3. Get the Emissary-ingress LoadBalancer IP:
       kubectl get svc emissary-ingress -n emissary -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

    4. Access the DevOps Loop UI:
       https://${var.devops_loop_domain}

    5. First-time setup:
       - Log in with your HCL administrator credentials
       - Create a Teamspace to begin using DevOps Loop
       - Navigate to the desired capabilities (Plan, Code, Build, etc.)

    6. For non-HTTP services (Deploy WSS, Build WSS, Control SSH):
       - These are exposed on the Emissary-ingress LoadBalancer IP
       - Ports: 7919 (deploy-wss), 7920 (build-wss), 9022 (control-ssh)

    Documentation: https://www.ibm.com/docs/en/devops-loop/1.0.3
  EOT
}
