
output "team_ids" {
  description = "All created GitHub team IDs"
  value = {
    level1 = { for k, v in github_team.level1 : k => v.id }
    level2 = { for k, v in github_team.level2 : k => v.id }
    level3 = { for k, v in github_team.level3 : k => v.id }
    level4 = { for k, v in github_team.level4 : k => v.id }
  }
}


output "team_slugs" {
  description = "All created GitHub team slugs"
  value = {
    level1 = { for k, v in github_team.level1 : k => v.slug }
    level2 = { for k, v in github_team.level2 : k => v.slug }
    level3 = { for k, v in github_team.level3 : k => v.slug }
    level4 = { for k, v in github_team.level4 : k => v.slug }
  }
}


output "team_members" {
  description = "Team memberships created across all levels"
  value = {
    level1 = { for k, v in github_team_membership.level1 : k => { username = v.username, role = v.role } }
    level2 = { for k, v in github_team_membership.level2 : k => { username = v.username, role = v.role } }
    level3 = { for k, v in github_team_membership.level3 : k => { username = v.username, role = v.role } }
    level4 = { for k, v in github_team_membership.level4 : k => { username = v.username, role = v.role } }
  }
}

output "org_members" {
  description = "Organization members created"
  value = { for k, v in github_membership.this : k => v.role }
}
