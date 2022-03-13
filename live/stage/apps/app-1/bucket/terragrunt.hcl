include "root" {
  path = find_in_parent_folders()
}
include "gcs" {
  path = "${get_path_to_repo_root()}/live/_commonenv/apps/app-1/bucket/terragrunt.hcl"
}
