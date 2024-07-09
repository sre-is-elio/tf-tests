data "aws_caller_identity" "current" {}

resource "null_resource" "get_aws_sso_users_by_groups" {
  triggers = {
    uuid = uuid()
  }

  provisioner "local-exec" {
    command = <<-PYTHON
      #!/usr/bin/env bash

      mkdir .cache
      
      python3 -m pip install -r ./scripts/requirements.txt
      python3 ./scripts/get-users-by-sso-groups.py
    PYTHON
  }
}

locals {
  depends_on = [null_resource.get_aws_sso_users_by_groups]

  account_id = data.aws_caller_identity.current.account_id

  automation_roles = sort(distinct([
    "GitHubOrganizationAccountAssumeRole",
    "OrganizationAccountAccessRole",
  ]))

  sso_groups = {
    admins = {
      AWSAdmins = "AWSReservedSSO_AWSAdministratorAccess_.*"
    }
    powerusers = {
      AWSPowerUsers = "AWSReservedSSO_AWSPowerUserAccess_.*"
    }
  }

  sso_admin_role_name_regex = sort(distinct([
    for group, group_regex in local.sso_groups["admins"] :
    group_regex
  ]))

  sso_poweruser_role_name_regex = sort(distinct([
    for group, group_regex in local.sso_groups["powerusers"] :
    group_regex
  ]))

  aws_sso_users_by_groups = yamldecode(file("./.cache/stanza-sso-users.yaml"))

  assumed_role_base_arn = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role"

  assumed_role_admins_map = merge({
    for parts in [for arn in data.aws_iam_roles.admin.arns : split("/", arn)] :
    format("%s", element(parts, length(parts) - 1)) => format("%s/%s", local.assumed_role_base_arn, element(parts, length(parts) - 1))
  })

  admin_users_with_assumed_roles = merge([
    for email, user in local.aws_sso_users_by_groups["AWSAdmins"] :
    {
      for _, adm_data in local.assumed_role_admins_map :
      format("%s", email) => merge(user, {
        AssumedRoleArn = format("%s/%s", adm_data, user.UserName)
      })
    }
  ]...)

  assumed_role_powerusers_map = merge({
    for parts in [for arn in data.aws_iam_roles.admin.arns : split("/", arn)] :
    format("%s", element(parts, length(parts) - 1)) => format("%s/%s", local.assumed_role_base_arn, element(parts, length(parts) - 1))
  })

  powerusers_with_assumed_roles = merge([
    for email, user in local.aws_sso_users_by_groups["AWSPowerUsers"] :
    {
      for _, adm_data in local.assumed_role_powerusers_map :
      format("%s", email) => merge(user, {
        AssumedRoleArn = format("%s/%s", adm_data, user.UserName)
      })
    }
  ]...)

  admin_arns = sort(distinct(flatten([
    [
      for parts in [for arn in data.aws_iam_roles.admin.arns : split("/", arn)] :
      format("%s/%s", parts[0], element(parts, length(parts) - 1))
    ],
    data.aws_iam_roles.automation.arns
  ])))

  poweruser_arns = sort(distinct(flatten([
    [
      for parts in [for arn in data.aws_iam_roles.poweruser.arns : split("/", arn)] :
      format("%s/%s", parts[0], element(parts, length(parts) - 1))
    ]
  ])))
}

data "aws_ssoadmin_instances" "instances" {
  provider = aws.root
}

data "aws_identitystore_groups" "groups" {
  provider          = aws.identitystore
  identity_store_id = tolist(data.aws_ssoadmin_instances.instances.identity_store_ids)[0]
}

data "aws_iam_roles" "automation" {
  name_regex = join("|", local.automation_roles)
}

data "aws_iam_roles" "admin" {
  name_regex  = join("|", local.sso_admin_role_name_regex)
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_roles" "poweruser" {
  name_regex  = join("|", local.sso_poweruser_role_name_regex)
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

resource "aws_iam_policy" "sops_kms_policy" {
  name        = "KMSDecryptPolicy"
  description = "Policy to allow KMS decrypt operations"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt"
        ],
        Resource = [
          "arn:aws:kms:us-east-2:${data.aws_caller_identity.current.account_id}:key/298bb098-358c-4429-ab7a-125ca91e9c1d", # Replace REGION, ACCOUNT_ID, and KEY_ID with your KMS key details
          aws_kms_key.key.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "sops_kms_role" {
  name = "KMSDecryptRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = sort(distinct(flatten([
            "arn:aws:iam::129086617226:root",
            "arn:aws:iam::${local.account_id}:root",
            data.aws_iam_roles.automation.arns,
            data.aws_iam_roles.admin.arns,
            data.aws_iam_roles.poweruser.arns,
          ])))
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sops_kms_role_attachment" {
  role       = aws_iam_role.sops_kms_role.name
  policy_arn = aws_iam_policy.sops_kms_policy.arn
}

resource "aws_kms_key" "key" {
  description             = "KMS key to encrypt and decrypt"
  deletion_window_in_days = 10
}

resource "aws_kms_key_policy" "key" {
  key_id = aws_kms_key.key.key_id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = sort(distinct(flatten([
            [
              for email, user in local.admin_users_with_assumed_roles :
              user.AssumedRoleArn
            ],
            "arn:aws:iam::129086617226:root",
            "arn:aws:iam::${local.account_id}:root",
            data.aws_iam_roles.automation.arns,
            data.aws_iam_roles.admin.arns,
          ])))
        },
        Action = "kms:*",
        Resource = [
          aws_kms_key.key.arn
        ]
      },
      {
        Sid    = "Allow use of the key",
        Effect = "Allow",
        Principal = {
          AWS = sort(distinct(flatten([
            [
              for email, user in local.powerusers_with_assumed_roles :
              user.AssumedRoleArn
            ],
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KMSDecryptRole",
            data.aws_iam_roles.automation.arns,
            data.aws_iam_roles.admin.arns,
            data.aws_iam_roles.poweruser.arns,
          ])))
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = [
          aws_kms_key.key.arn
        ]
      }
    ]
  })
}

resource "aws_kms_alias" "key" {
  name          = "alias/tf-tests"
  target_key_id = aws_kms_key.key.key_id
}
