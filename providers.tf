provider "aws" {
  region  = var.aws_providers.primary.region
  profile = var.aws_providers.primary.is_assumable_role == false ? try(var.aws_providers.primary.profile, null) : null
  dynamic "assume_role" {
    for_each = var.aws_providers.primary.is_assumable_role == true ? try({ role = var.aws_providers.primary.role }, tomap({})) : tomap({})
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias   = "identitystore"
  region  = "us-east-1"
  profile = "default"
  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias   = "root"
  region  = "us-east-1"
  profile = "stanza-root"
  default_tags {
    tags = local.tags
  }
}

provider "shell" {
  interpreter        = ["/bin/sh", "-c"]
  enable_parallelism = false
}
