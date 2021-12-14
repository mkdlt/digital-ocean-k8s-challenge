terraform {
  backend "remote" {
    organization = "mkdlt"

    workspaces {
      name = "digital-ocean-k8s-challenge"
    }
  }
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.16.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.6.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

resource "digitalocean_project" "k8s_challenge" {
  name        = "k8s-challenge"
  description = "Entry for the DigitalOcean Kubernetes Challenge"
  purpose     = "Just trying out DigitalOcean"
  environment = "Development"

  resources = [
    digitalocean_kubernetes_cluster.postgres.urn
  ]
}

resource "digitalocean_vpc" "k8s" {
  name   = "k8s-vpc"
  region = "sgp1"

  timeouts {
    delete = "4m"
  }
}

data "digitalocean_kubernetes_versions" "prefix" {
  version_prefix = "1.21."
}

resource "digitalocean_kubernetes_cluster" "postgres" {
  name         = "postgres"
  region       = "sgp1"
  auto_upgrade = true
  version      = data.digitalocean_kubernetes_versions.prefix.latest_version

  vpc_uuid = digitalocean_vpc.k8s.id

  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }

  node_pool {
    name       = "worker-pool"
    size       = "s-1vcpu-2gb"
    node_count = 3
  }
}

provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.postgres.endpoint
  token = digitalocean_kubernetes_cluster.postgres.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.postgres.kube_config[0].cluster_ca_certificate
  )
}

provider "kubectl" {
  host  = digitalocean_kubernetes_cluster.postgres.endpoint
  token = digitalocean_kubernetes_cluster.postgres.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.postgres.kube_config[0].cluster_ca_certificate
  )
  load_config_file = false
}

variable "superUserPassword" {}
variable "replicationUserPassword" {}


resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "mypostgres-secret"
    namespace = "default"
  }

  data = {
    superUserPassword       = var.superUserPassword
    replicationUserPassword = var.replicationUserPassword
  }

  type = "Opaque"
}

data "kubectl_path_documents" "docs" {
  pattern = "./manifests/*.yaml"
}

resource "kubectl_manifest" "kubegres" {
  for_each  = toset(data.kubectl_path_documents.docs.documents)
  yaml_body = each.value
}