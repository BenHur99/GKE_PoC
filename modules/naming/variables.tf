variable "client_name" {
  description = "Client name (e.g. orel)"
  type        = string
}

variable "product_name" {
  description = "Product name (e.g. gob)"
  type        = string
}

variable "environment" {
  description = "Environment (e.g. dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "GCP region (e.g. europe-west1)"
  type        = string
}
