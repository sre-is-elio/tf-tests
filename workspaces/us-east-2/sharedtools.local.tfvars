aws_providers = {
  primary = {
    is_assumable_role = false
    profile           = "stanza-sharedtools"
    role              = "arn:aws:iam::349674910754:role/OrganizationAccountAccessRole"
    region            = "us-east-2"
  },
  # dev = {
  #   is_assumable_role = false
  #   profile           = "stanza-dev"
  #   role              = "arn:aws:iam::885015629014:role/OrganizationAccountAccessRole"
  #   region            = "us-east-2"
  # }
  # demo = {
  #   is_assumable_role = false
  #   profile           = "stanza-demo"
  #   role              = "arn:aws:iam::134764736449:role/OrganizationAccountAccessRole"
  #   region            = "us-east-2"
  # }
  # prod = {
  #   is_assumable_role = false
  #   profile           = "stanza-prod"
  #   role              = "arn:aws:iam::838106405942:role/OrganizationAccountAccessRole"
  #   region            = "us-east-2"
  # }
}
