remote_state {
  backend = "gcs"

  config = {
    bucket = "twe-terraform-backend"
    prefix = "terraform/${path_relative_to_include()}"
skip_bucket_creation = true
  }
}

generate "backend" {
  path      = "tg_backend.tf"
  if_exists = "skip"
  contents  = <<EOF
terraform {
  backend "gcs" {}
}
EOF
}
