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
  }
}

variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "terraform-cloud-token" {
  name = "terraform-cloud-token"
}

resource "digitalocean_project" "digital-ocean-k8s-challenge" {
  name        = "digital-ocean-k8s-challenge"
  description = "DigitalOcean Kubernetes Challenge"
  purpose     = "Deploy a scalable SQL cluster"
}
