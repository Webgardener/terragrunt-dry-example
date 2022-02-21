include "root" {
  path = find_in_parents_folders()
}

include "gcs" {
  path = "${get_path_to_repo_root()}/live/_commonenv/projects/project-1/gcs/terragrunt.hcl"
}
