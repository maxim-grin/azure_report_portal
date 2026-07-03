locals {
  prefix = "${var.project}-${var.environment}"

  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}
