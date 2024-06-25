provider "aws" {
  region  = "us-east-2"
  profile = "stanza-dev"
  default_tags {
    tags = {
      Name = "tf-tests"
    }
  }
}

provider "aws" {
  alias   = "identitystore"
  region  = "us-east-1"
  profile = "stanza-dev"
  default_tags {
    tags = {
      Name = "tf-tests"
    }
  }
}

provider "aws" {
  alias   = "root"
  region  = "us-east-1"
  profile = "stanza-root"
  default_tags {
    tags = {
      Name = "tf-tests"
    }
  }
}

provider "shell" {
  interpreter        = ["/bin/sh", "-c"]
  enable_parallelism = false
}
