output "assumed_role_admin_map" {
  value = local.assumed_role_admins_map
}

output "aws_iam_roles_admins" {
  value = local.admin_arns
}

output "aws_iam_roles_powerusers" {
  value = local.poweruser_arns
}

output "sops_kms_role" {
  value = aws_iam_role.sops_kms_role.arn
}

output "sops_kms_key" {
  value = aws_kms_key.key.key_id
}

output "aws_sso_users_by_groups" {
  value = local.aws_sso_users_by_groups
}

output "admin_users_with_assumed_roles" {
  value = local.admin_users_with_assumed_roles
}
