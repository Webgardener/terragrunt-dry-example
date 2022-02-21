
remote_state {
  backend = "gcs"

  config = {
    bucket = "backend-terraform"
    prefix = "terraform/${path_relative_to_include()}"
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
