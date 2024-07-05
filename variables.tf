variable "aws_providers" {
  type = object({
    primary = optional(object({
      is_assumable_role = optional(bool, false)
      profile           = optional(string, null)
      role              = optional(string, null)
      region            = optional(string, "us-east-2")
    }), {})
  })
  description = "AWS Providers Configuration"
  default     = {}
}

variable "kms_alias" {
  type    = string
  default = "tf-tests"
}
