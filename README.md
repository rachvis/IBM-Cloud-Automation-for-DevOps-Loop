# IBM DevOps Loop on IBM Cloud Kubernetes Service — Deployable Architecture

[![IBM Cloud Deployable Architecture](https://img.shields.io/badge/IBM%20Cloud-Deployable%20Architecture-blue)](https://cloud.ibm.com/catalog)
[![DevOps Loop](https://img.shields.io/badge/IBM%20DevOps%20Loop-1.0.3-orange)](https://www.ibm.com/docs/en/devops-loop/1.0.3)

This repository is an IBM Cloud **Deployable Architecture** that installs [IBM DevOps Loop](https://www.ibm.com/docs/en/devops-loop/1.0.3) on [IBM Cloud Kubernetes Service (IKS)](https://www.ibm.com/cloud/kubernetes-service) using Terraform and the official OCI Helm chart.

It is designed to be onboarded into an **IBM Cloud Private Catalog** and deployed via **IBM Cloud Projects** or **IBM Cloud Schematics**.

---

## What is IBM DevOps Loop?

IBM DevOps Loop is a unified platform that brings every stage of the software development lifecycle into a **continuous feedback loop**. It connects teams, processes, and applications across:

| Capability | Description |
|---|---|
| **Plan** | Project planning, issue tracking, and backlog management |
| **Code** | Cloud-based browser IDE — write, build, and debug without local setup |
| **Control** | Source control management and governance |
| **Build** | CI pipelines and build automation |
| **Test** | Test management, execution, and reporting |
| **Release** | Release orchestration and approval workflows |
| **Deploy** | Deployment automation across environments |
| **Measure** | Real-time dashboards, analytics, and delivery insights |

DevOps Loop also includes **Loop Genie**, an AI-powered assistant (integrated with IBM watsonx) that accelerates workflows and provides intelligent search across the entire toolchain.

---

## Architecture Overview

![Architecture Diagram](reference-architecture/devops-loop-on-iks.svg)

### What gets provisioned

| Resource | Details |
|---|---|
| VPC | New VPC with one subnet (or use existing) |
| IKS Cluster | VPC-based cluster, ≥ 3 × `bx2.8x32` workers (or use existing) |
| Emissary-ingress | Ambassador API gateway — exposes ports 80, 443, 7919, 7920, 9022 |
| Custom Ingress Domain | `<name>.<region>.containers.appdomain.com` |
| Kubernetes Namespace | Dedicated `devops-loop` namespace |
| HCL Harbor Pull Secret | Image pull authentication for `hclcr.io` |
| TLS Secret | Certificate managed via IBM Secrets Manager |
| IBM Cloud Block Storage | RWO storage class (`ibmc-block-gold`) for stateful workloads |
| IBM Cloud File Storage | RWX storage class (`ibmc-file-gold-gid`) for shared volumes |
| DevOps Loop (Helm) | OCI chart `hclcr.io/devops-automation-helm/hcl-devops-loop` |

---

## Network Architecture

Emissary-ingress (Ambassador Edge Stack) serves as the **L4 LoadBalancer** and **API gateway** for all external traffic into DevOps Loop:

| Port | Service |
|---|---|
| `443` | HTTPS — DevOps Loop UI |
| `80` | HTTP — redirected to HTTPS |
| `7919` | WebSocket — DevOps Deploy |
| `7920` | WebSocket — DevOps Build |
| `9022` | SSH — DevOps Control |

---

## Flavors

### 1. New Cluster _(greenfield)_

Provisions from scratch:
- VPC + Subnet → IKS Cluster → Emissary-ingress → DevOps Loop

### 2. Existing Cluster _(brownfield)_

Deploys only Kubernetes resources into your existing IKS cluster:
- Emissary-ingress + DevOps Loop namespaces, secrets, and Helm releases

---

## Prerequisites

Before deploying, ensure you have:

1. **IBM Cloud API key** with the following IAM permissions:
   - IBM Kubernetes Service: **Administrator**
   - VPC Infrastructure: **Administrator**
   - IBM Secrets Manager: **Manager**

2. **HCL Harbor credentials** — obtain from [hclcr.io](https://hclcr.io):
   - HCL ID (username)
   - CLI Secret from your User Profile

3. **HCL Rational License Key Server** — hostname or IP in the format `@<hostname>`

4. **TLS Certificate** — a valid certificate issued by a trusted CA for your domain, in PEM format

5. **Custom Domain** — created in IBM Cloud Kubernetes Service Ingress Domains panel:
   - Format: `<custom-name>.<region>.containers.appdomain.com`
   - Must be set as the **default domain** for your cluster

---

## Quick Start (IBM Cloud Private Catalog)

1. **Tag a GitHub release** (e.g. `v1.0.0`) and note the archive URL:
   ```
   https://github.com/YOUR_ORG/devops-loop-iks-da/archive/refs/tags/v1.0.0.tar.gz
   ```

2. In **IBM Cloud → Manage → Catalogs → Private Catalogs**, create a new product and point it at the archive URL.

3. Configure required inputs (see table below) and deploy via **IBM Cloud Projects**.

---

## Local Development / Testing

### Prerequisites

- [Terraform >= 1.3](https://developer.hashicorp.com/terraform/downloads)
- [IBM Cloud CLI](https://cloud.ibm.com/docs/cli) with `ks` plugin
- [kubectl](https://kubernetes.io/docs/tasks/tools/) and [Helm >= 3](https://helm.sh)

### Steps

```bash
cd solutions/devops-loop-on-iks

cat > terraform.tfvars <<EOF
ibmcloud_api_key       = "YOUR_IBM_CLOUD_API_KEY"
region                 = "us-south"
prefix                 = "my-dl"
resource_group_name    = "Default"
devops_loop_domain     = "my-dl.us-south.containers.appdomain.com"
license_server         = "@my-license-server.example.com"
hcl_harbor_username    = "your-hcl-id@example.com"
hcl_harbor_cli_secret  = "YOUR_HARBOR_CLI_SECRET"
tls_certificate        = <<CERT
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
CERT
tls_private_key        = <<KEY
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
KEY
EOF

terraform init
terraform plan
terraform apply
```

After `apply` completes, read the `devops_loop_access_instructions` output for the URL and next steps.

---

## Inputs Reference

### Required Inputs

| Variable | Description |
|---|---|
| `ibmcloud_api_key` | IBM Cloud API key |
| `region` | IBM Cloud region (e.g. `us-south`) |
| `prefix` | Resource name prefix (≤16 chars) |
| `resource_group_name` | IBM Cloud resource group |
| `devops_loop_domain` | FQDN for DevOps Loop |
| `license_server` | HCL License Server (`@<host>`) |
| `hcl_harbor_username` | HCL Harbor registry username |
| `hcl_harbor_cli_secret` | HCL Harbor CLI secret / token |
| `tls_certificate` | PEM-encoded TLS certificate |
| `tls_private_key` | PEM-encoded TLS private key |

### Optional Inputs

| Variable | Description | Default |
|---|---|---|
| `worker_flavor` | IKS worker node machine type | `bx2.8x32` |
| `worker_count` | Number of worker nodes | `3` |
| `use_existing_vpc` | Reuse existing VPC | `false` |
| `existing_cluster_id` | Existing IKS cluster ID | `""` |
| `rwo_storage_class` | RWO storage class | `ibmc-block-gold` |
| `rwx_storage_class` | RWX storage class | `ibmc-file-gold-gid` |
| `devops_loop_chart_version` | Helm chart version | `1.0.3` |
| `emissary_chart_version` | Emissary-ingress chart version | `3.9.1` |
| `enable_plan` | Enable Plan capability | `true` |
| `enable_code` | Enable Code capability | `true` |
| `enable_control` | Enable Control capability | `true` |
| `enable_build` | Enable Build capability | `true` |
| `enable_test` | Enable Test capability | `true` |
| `enable_release` | Enable Release capability | `true` |
| `enable_deploy` | Enable Deploy capability | `true` |
| `enable_measure` | Enable Measure capability | `true` |
| `smtp_host` | SMTP server hostname | `""` |
| `smtp_port` | SMTP port | `587` |
| `smtp_from_address` | From address for notifications | `""` |

---

## Outputs Reference

| Output | Description |
|---|---|
| `cluster_id` | IKS cluster ID |
| `cluster_name` | IKS cluster name |
| `vpc_id` | VPC ID |
| `devops_loop_namespace` | Kubernetes namespace |
| `devops_loop_domain` | FQDN of the deployment |
| `enabled_capabilities` | Map of capability toggles |
| `devops_loop_access_instructions` | Full access guide |

---

## Repository Structure

```
devops-loop-iks-da/
├── ibm_catalog.json                        # IBM Private Catalog manifest
├── README.md                               # This file
├── LICENSE                                 # Apache 2.0
├── .gitignore
├── reference-architecture/
│   └── devops-loop-on-iks.svg              # Detailed architecture diagram
└── solutions/
    └── devops-loop-on-iks/
        ├── main.tf                         # Core Terraform resources
        ├── variables.tf                    # All input variables
        ├── outputs.tf                      # Output values
        ├── version.tf                      # Provider + Terraform version pins
        └── README.md                       # Solution-level docs
```

---

## Important Notes

- **Cluster sizing**: DevOps Loop requires substantial compute. Each worker node should have at least 8 vCPU and 32 GB RAM (`bx2.8x32`). Use at least 3 nodes for production.
- **RWX storage**: Several DevOps Loop components require `ReadWriteMany` persistent volumes. `ibmc-file-gold-gid` is the recommended IBM Cloud storage class for this.
- **Emissary-ingress**: The Ambassador Edge Stack is mandatory — DevOps Loop routes all traffic (including non-HTTP ports) through it.
- **TLS certificates**: Must be issued by a publicly trusted CA. Self-signed certificates are not supported for IKS deployments without additional configuration.
- **First login**: After deployment, create a **Teamspace** before using any DevOps Loop capabilities.

---

## Documentation

- [IBM DevOps Loop 1.0.3 Documentation](https://www.ibm.com/docs/en/devops-loop/1.0.3)
- [Installing DevOps Loop on IKS](https://help.hcl-software.com/devops/loop/1.0.2/docs/topics/install_iks.html)
- [IBM Cloud Kubernetes Service](https://cloud.ibm.com/docs/containers)
- [Emissary-ingress (Ambassador)](https://www.getambassador.io/docs/emissary)

---

## Support

This is a community-maintained deployable architecture. For IBM DevOps Loop product support, refer to [IBM Support](https://www.ibm.com/support).

---

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
# IBM-Cloud-Automation-for-DevOps-Loop
