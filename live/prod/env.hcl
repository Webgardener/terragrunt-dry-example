locals {
  env        = "prod"
  project_id = "my-project-${local.env}"
}

inputs = {
  project_id = local.project_id
}
