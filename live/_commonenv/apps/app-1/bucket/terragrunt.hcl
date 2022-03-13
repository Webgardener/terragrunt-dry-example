locals {
  env_config = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env        = local.env_config.locals.env

  app_name = "${basename(dirname(get_original_terragrunt_dir()))}"
}

terraform {
  source = "tfr:///terraform-google-modules/cloud-storage/google//modules/simple_bucket?version=3.1.0"
}

inputs = merge(
  local.env_config.inputs, # merge the inputs from the env.hcl file (so that we get the "project_id" input)
  {
    name = "${local.env}-${local.app_name}-assets", # the name of the bucket is prefixed by the environment
    iam_members = [{
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }]
  }
)
