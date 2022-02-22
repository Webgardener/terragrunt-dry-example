# Terragrunt: keep your configuration as DRY as possible

Terragrunt is a thin wrapper that provides extra tools for [keeping your Terraform configurations DRY](https://blog.gruntwork.io/terragrunt-how-to-keep-your-terraform-code-dry-and-maintainable-f61ae06959d8).

This article presents a use case to keep a configuration DRY using multiple `include` blocks.

## Take advantage of multiple include blocks

For a long time, Terragrunt only supported one level of `include` blocks. 

`include` is a feature of Terragrunt that allows you to import common configurations so that you can share them across your root modules.

The ability to include multiple files in a single configuration starting with `v0.32.0` of Terragrunt.

This addresses the pain points of single level include while working around the technical limitations of multiple levels.

Now, you can define your component level common configurations in a separate file that gets imported and merged with the project level common configurations.

For example, consider the following folder structure:

```
└── live
    ├── terragrunt.hcl
    ├── _commonenv
    │   └── vpc.hcl
    ├── prod
    │   └── vpc
    │       └── terragrunt.hcl
    ├── qa
    │   └── vpc
    │       └── terragrunt.hcl
    └── stage
        └── vpc
            └── terragrunt.hcl
```

In this structure, the root `live/terragrunt.hcl` configuration contains the project level configurations of remote state and provider blocks, while the `_commonenv/vpc.hcl`
configuration contains the common inputs for setting up a VPC. This allows the child configurations in each env (qa, stage, prod) to be simplified to:

```hcl
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_path_to_repo_root()}/live/_commonenv/vpc.hcl"
}

inputs = {
  cidr_block = "10.0.0.0/16"
}
```

### Use case: keep the configuration DRY 

> introduce context

The following folder structure:

```
.
├── live
│   └── terragrunt.hcl
│   ├── prod
│   │   └── projects
│   │       └── project-1
│   │           ├── bucket
│   │           └── pubsub
│   ├── qa
│   │   └── projects
│   │       └── project-1
│   │           ├── bucket
│   │           └── pubsub
│   ├── stage
│   │   └── projects
│   │       └── project-1
│   │           ├── bucket
│   │           └── pubsub
```

The project-1 needs some Bucket and Pub/Sub configuration.

The configuration for these pieces of infrastructure is almost identical, *only the `prefix` of the resources name will vary*.

Example for bucket names:

- `stage-project-1-assets`
- `qa-project-1-assets`
- `prod-project-1-assets` 

Same logic applies for Pub/Sub configuration.

I might have a lot of configuration for each environment, and I don't want to repeat it three times!

*Step 1*: 

- create a `env.hcl` file for each environment;
- create a `_commonenv` folder with the same structure as in your environments.

```
├── live
│   └── terragrunt.hcl
│   ├── _commonenv
│   │   └── projects
│   │       └── project-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
│   ├── prod
│   │   ├── env.hcl
│   │   └── projects
│   │       └── project-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
│   ├── qa
│   │   ├── env.hcl
│   │   └── projects
│   │       └── project-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
│   ├── stage
│   │   ├── env.hcl
│   │   └── projects
│   │       └── project-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
```

*Step 2*:

- Write the `env.hcl` files for `stage`, `qa` and `prod`:

```hcl
# live/stage/env.hcl

locals {
  env = "stage"
  project_id = "my-project-stage"
}

inputs = {
  project_id = local.project_id
}
```

Same logic applies for `qa` and `prod`.

- Write the desired configuration in the terragrunt.hcl files within the `_commonenv` folder:

```hcl
# live/_commonenv/projects/project-1/bucket/terragrunt.hcl

locals {
  env_config = read_terragrunt_config(find_in_parent_folders("env.hcl")
  env        = local.env_config.locals.env
}

terraform {
  source = "tfr:///terraform-google-modules/cloud-storage/google//modules/simple_bucket?version=3.1.0"
}

inputs = merge(
  local.env_config.inputs, # merge the inputs from the env.hcl file (so that we get the "project_id" input)
  {
    name = "${local.env}-project-1-assets" # the name of the bucket is prefixed by the environment
    iam_members = [{
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }] 
  }
)
```

The configuration is only written once in the `_commonenv` folder.

Then, in the environments folders, this configuration must be included:

```hcl
# live/stage/projects/project-1/bucket/terragrunt.hcl

include "root" {
  path = find_in_parents_folders()
}

include "bucket-config" {
  path = "${get_path_to_repo_root()}/live/_commonenv/projects/project-1/bucket/terragrunt.hcl"
}
```

Same structure for `qa` and `prod`:

```hcl
# live/qa/projects/project-1/bucket/terragrunt.hcl

include "root" {
  path = find_in_parents_folders()
}

include "bucket-config" {
  path = "${get_path_to_repo_root()}/live/_commonenv/projects/project-1/bucket/terragrunt.hcl"
}
```

That's it!

This configuration avoid repeating the `terraform` and `inputs` block for the three environments.

Ok, this configuration is DRY but is it [KISS](https://en.wikipedia.org/wiki/KISS_principle)?

Well, maybe not so much.

Let's recap what it does:

- A "bucket" root module includes a common configuration defined in `_commonenv/projects/project-1/bucket/terragrunt.hcl`
- The `_commonenv/projects/project-1/bucket/terragrunt.hcl` reads a configuration from `live/ENV/env.hcl` (with ENV in `stage`, `qa` and `prod`),
  to get its `locals` block that contain the environment name used to prefix the name of the bucket.

So, repeating this simple bucket configuration 3 times - at the root module level - would probably have been more readable and easy to understand.

But, for more complex use cases (VPC, Pub/Sub etc.), including common configurations can save hundreds of lines of code!
I think it is worth the add of complexity.

