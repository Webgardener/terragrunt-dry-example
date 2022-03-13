# Terragrunt: keep your configuration as DRY as possible

Terragrunt is a thin wrapper that provides extra tools for [keeping your Terraform configurations DRY](https://blog.gruntwork.io/terragrunt-how-to-keep-your-terraform-code-dry-and-maintainable-f61ae06959d8).

This article presents a use case to keep a configuration DRY using multiple `include` blocks.

[TOC]

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
    │   └── vpc
    │       └── terragrunt.hcl
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

In this structure, the root `live/terragrunt.hcl` configuration contains the project level configurations of remote state and provider blocks, while the `_commonenv/vpc/terragrunt.hcl`
configuration contains the common inputs for setting up a VPC. This allows the child configurations in each env (qa, stage, prod) to be simplified to:

```hcl
include "root" {
  path = find_in_parent_folders()
}

include "common" {
  path = "${get_path_to_repo_root()}/live/_commonenv/vpc/terragrunt.hcl"
}

inputs = {
  cidr_block = "10.0.0.0/16"
}
```

## Use case: keep the configuration DRY 

> introduce context

The following folder structure:

```
.
├── live
│   └── terragrunt.hcl
│   ├── prod
│   │   └── apps
│   │       └── app-1
│   │           ├── bucket
│   │           └── pubsub
│   │       └── app-2
│   │           ├── bucket
│   │           └── pubsub
│   ├── qa
│   │   └── apps
│   │       └── app-1
│   │           ├── bucket
│   │           └── pubsub
│   │       └── app-2
│   │           ├── bucket
│   │           └── pubsub
│   ├── stage
│   │   └── apps
│   │       └── app-1
│   │           ├── bucket
│   │           └── pubsub
│   │       └── app-2
│   │           ├── bucket
│   │           └── pubsub
```

Each app needs a bucket and Pub/Sub.

The configuration for these pieces of infrastructure is almost identical between environments.
In that example, *only the `prefix` of the resources name will be different*:

For the bucket name:

- `stage-app-1-assets`
- `qa-app-1-assets`
- `prod-app-1-assets` 

Same logic applies for Pub/Sub configuration.

I might have a lot of configuration for each environment. So do I avoid to repeat it three times?

*Step 1*: 

- create a `env.hcl` file for each environment;
- create a `_commonenv` folder with the same structure as in your environments.

```
├── live
│   └── terragrunt.hcl
│   ├── _commonenv
│   │   └── apps
│   │       └── app-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
│   ├── prod
│   │   ├── env.hcl
│   │   └── apps
│   │       └── app-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
│   ├── qa
│   │   ├── env.hcl
│   │   └── apps
│   │       └── app-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
│   ├── stage
│   │   ├── env.hcl
│   │   └── apps
│   │       └── app-1
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
  project_id = "my-gcp-project-stage"
}

inputs = {
  project_id = local.project_id
}
```

Same logic applies for `qa` and `prod`.

- Write the desired configuration in the terragrunt.hcl files within the `_commonenv` folder:

```hcl
# live/_commonenv/apps/app-1/bucket/terragrunt.hcl

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
    name = "${local.env}-app-1-assets" # the name of the bucket is prefixed by the environment
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
# live/stage/apps/app-1/bucket/terragrunt.hcl

include "root" {
  path = find_in_parent_folders()
}

include "common" {
  path = "${get_path_to_repo_root()}/live/_commonenv/apps/app-1/bucket/terragrunt.hcl"
}
```

Same structure for `qa` and `prod`:

```hcl
# live/qa/apps/app-1/bucket/terragrunt.hcl

include "root" {
  path = find_in_parent_folders()
}

include "bucket-config" {
  path = "${get_path_to_repo_root()}/live/_commonenv/apps/app-1/bucket/terragrunt.hcl"
}
```

That's it!

## Refactor: make the configuration more DRY

In the previous section, we achieved to avoid writing the configuration for each environment.

But we also recreated an apps hierachy in the `_commonenv`. 

```
├── live
│   ├── _commonenv
│   │   └── apps
│   │       └── app-1
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
│   │       └── app-2
│   │           ├── bucket
│   │           │   └── terragrunt.hcl
│   │           └── pubsub
│   │               └── terragrunt.hcl
```

Can this be avoided as well?

Maybe.

Let's try with buckets:

The common bucket configuration looks almost the same between apps.

*Only the app name is different*:

```hcl
# live/_commonenv/apps/app-1/bucket/terragrunt.hcl

locals {
  env_config = read_terragrunt_config(find_in_parent_folders("env.hcl")
  env        = local.env_config.locals.env
}

terraform {
  source = "tfr:///terraform-google-modules/cloud-storage/google//modules/simple_bucket?version=3.1.0"
}

inputs = merge(
  local.env_config.inputs,
  {
    name = "${local.env}-app-1-assets" # the name of the bucket contains the name of the app
    iam_members = [{
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }] 
  }
)
```

The "app name" part of the the bucket name can be passed as a variable:

```hcl
# live/_commonenv/apps/bucket/terragrunt.hcl

locals {
  [..]
  app_name = "${basename(dirname(get_original_terragrunt_dir()))}" # will be equal to "app-1"
}
[..]
inputs = merge(
  local.env_config.inputs,
  {
    name = "${local.env}-{local.app_name}-assets"
    iam_members = [{
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }] 
  }
)
```

> Note how the `apps/app-1/bucket/terragrunt.hcl` file becomes `apps/bucket/terragrunt.hcl`
> The bucket configuration is now common to all apps!
