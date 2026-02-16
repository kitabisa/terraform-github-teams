variable "organization" {
  description = "GitHub organization name"
  type        = string
}

variable "teams" {
  description = "Nested GitHub teams structure - supports up to 4 levels of nesting. Each team can include: description, privacy, members (list of usernames), maintainers (list of usernames), inherit_members_from (list of team paths to inherit members from), inherit_maintainers_from (list of team paths to inherit maintainers from)"
  type        = any
}

variable "org_members" {
  description = "Optional mapping of usernames to their organization membership role (member, admin)"
  type        = map(string)
  default     = {}
}
