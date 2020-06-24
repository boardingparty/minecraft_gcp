terraform {
  backend "gcs" {}
}

data "terraform_remote_state" "state" {
  backend = "gcs"
  config = {
    bucket     = "${var.tf_state_bucket}"
    prefix     = "${var.application}/${var.environment}"
  }
}

provider "google" {
  project = var.project
}
