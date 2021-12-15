terraform {
  required_providers {
    kind = {
      source  = "kyma-incubator/kind"
      version = "0.0.9"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.5.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.1.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "kind" {
}

provider "kubernetes" {
  config_path = pathexpand(var.kind_cluster_config_path)
}

resource "kind_cluster" "default" {
  name            = var.kind_cluster_name
  kubeconfig_path = pathexpand(var.kind_cluster_config_path)
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]
    }

    node {
      role = "worker"
      extra_port_mappings {
        container_port = 30000
        host_port      = 8066
      }
    }
  }
}

resource "kubernetes_deployment" "meudeployment" {
  depends_on = [kind_cluster.default]
  metadata {
    name = "terraform-example-2"
    labels = {
      app = "giropops"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "giropops"
      }
    }

    template {
      metadata {
        labels = {
          app = "giropops"
        }
      }

      spec {
        container {
          image = "camillamartins/docker-linuxtips:1.0"
          name  = "docker-linuxtips"

          resources {
            limits = {
              cpu    = "1"
              memory = "512Mi"
            }
            requests = {
              cpu    = "0.1"
              memory = "64Mi"
            }
          }
          port {
            container_port = 8080
          }          
        }
      }
    }
  }
}

resource "kubernetes_service" "service" {
  depends_on = [kind_cluster.default]
  metadata {
    name = "giropops"
  }
  spec {
    selector = {
      app = "giropops"
    }
    session_affinity = "ClientIP"
    port {
      port        = 8080
      protocol    = "TCP"
      name        = "http"
      target_port = 8080
      node_port   = 30000
    }

    type = "NodePort"
  }
}

