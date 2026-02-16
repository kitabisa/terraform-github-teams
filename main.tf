provider "github" {
  owner = var.organization
}

############################
# Flatten nested teams structure
############################
locals {
  # Helper to check if value is a nested structure (object/map)
  is_nested = { for k, v in var.teams : k => try(v != null && length(keys(v)) > 0, false) }

  # Level 1: Direct children of var.teams
  level1_teams = {
    for k, v in var.teams : k => v
    if local.is_nested[k]
  }

  # Level 2: Children of level 1 teams
  level2_flat = flatten([
    for l1_key, l1_val in local.level1_teams : [
      for l2_key, l2_val in l1_val : {
        parent_key = l1_key
        name       = l2_key
        value      = l2_val
      }
      if l2_key != "description" && l2_key != "privacy" && l2_key != "members" && l2_key != "maintainers" && l2_key != "inherit_members_from" && l2_key != "inherit_maintainers_from" && try(l2_val != null && length(keys(l2_val)) > 0, false)
    ]
  ])

  level2_teams = {
    for item in local.level2_flat : "${item.parent_key}/${item.name}" => merge(
      { parent_key = item.parent_key, name = item.name },
      item.value
    )
  }


  # Level 3: Children of level 2 teams
  level3_flat = flatten([
    for l2_key, l2_val in local.level2_teams : [
      for l3_key, l3_val in l2_val : {
        parent_key = l2_key
        name       = l3_key
        value      = l3_val
      }
      if l3_key != "parent_key" && l3_key != "name" && l3_key != "description" && l3_key != "privacy" && l3_key != "members" && l3_key != "maintainers" && l3_key != "inherit_members_from" && l3_key != "inherit_maintainers_from"
    ]
  ])

  level3_teams = {
    for item in local.level3_flat : "${item.parent_key}/${item.name}" => merge(
      { parent_key = item.parent_key, name = item.name },
      item.value
    )
  }

  # Level 4: Children of level 3 teams (filter only nested maps/objects)
  level4_flat = flatten([
    for l3_key, l3_val in local.level3_teams : [
      for l4_key, l4_val in l3_val : {
        parent_key = l3_key
        name       = l4_key
        value      = l4_val
      }
      if l4_key != "parent_key" && l4_key != "name" && l4_key != "description" && l4_key != "privacy" && l4_key != "members" && l4_key != "maintainers" && l4_key != "inherit_members_from" && l4_key != "inherit_maintainers_from"
      && can(length(keys(l4_val)))
    ]
  ])

  level4_teams = {
    for item in local.level4_flat : "${item.parent_key}/${item.name}" => merge(
      { parent_key = item.parent_key, name = item.name },
      item.value
    )
  }

  ############################
  # Extract team members
  ############################
  # Level 1 members
  level1_members_flat = flatten([
    for l1_key, l1_val in local.level1_teams : concat(
      [for member in try(l1_val.members, []) : {
        team_key    = l1_key
        team_id_ref = "github_team.level1[\"${l1_key}\"].id"
        username    = member
        role        = "member"
      }],
      [for maintainer in try(l1_val.maintainers, []) : {
        team_key    = l1_key
        team_id_ref = "github_team.level1[\"${l1_key}\"].id"
        username    = maintainer
        role        = "maintainer"
      }]
    )
  ])

  level1_members = {
    for item in local.level1_members_flat : "${item.team_key}::${item.username}" => item
  }

  # Level 2 members
  level2_members_flat = flatten([
    for l2_key, l2_val in local.level2_teams : concat(
      [for member in try(l2_val.members, []) : {
        team_key = l2_key
        username = member
        role     = "member"
      }],
      [for maintainer in try(l2_val.maintainers, []) : {
        team_key = l2_key
        username = maintainer
        role     = "maintainer"
      }]
    )
  ])

  level2_members = {
    for item in local.level2_members_flat : "${item.team_key}::${item.username}" => item
  }


  # Level 3 members
  level3_members_flat = flatten([
    for l3_key, l3_val in local.level3_teams : concat(
      [for member in try(l3_val.members, []) : {
        team_key = l3_key
        username = member
        role     = "member"
      }],
      [for maintainer in try(l3_val.maintainers, []) : {
        team_key = l3_key
        username = maintainer
        role     = "maintainer"
      }]
    )
  ])

  level3_members = {
    for item in local.level3_members_flat : "${item.team_key}::${item.username}" => item
  }

  # Level 4 members
  level4_members_flat = flatten([
    for l4_key, l4_val in local.level4_teams : concat(
      [for member in try(l4_val.members, []) : {
        team_key = l4_key
        username = member
        role     = "member"
      }],
      [for maintainer in try(l4_val.maintainers, []) : {
        team_key = l4_key
        username = maintainer
        role     = "maintainer"
      }]
    )
  ])

  level4_members = {
    for item in local.level4_members_flat : "${item.team_key}::${item.username}" => item
  }

  ############################
  # Handle inherited members from other teams
  ############################
  # Build a map of all members by team path (for lookup)

  all_members_by_team = merge(
    { for k, v in local.level1_members : k => v },
    { for k, v in local.level2_members : k => v },
    { for k, v in local.level3_members : k => v },
    { for k, v in local.level4_members : k => v }
  )

  # Extract teams that have inherit_members_from and resolve their references
  inherited_members_flat = flatten([
    for l1_key, l1_val in local.level1_teams : [
      for inherit_path in try(l1_val.inherit_members_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l1_key
          username = member_val.username
          role     = member_val.role
        }
        if startswith(member_key, inherit_path) && member_val.role == "member"
      ]
    ]
  ])

  inherited_members_l2_flat = flatten([
    for l2_key, l2_val in local.level2_teams : [
      for inherit_path in try(l2_val.inherit_members_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l2_key
          username = member_val.username
          role     = member_val.role
        }
        if startswith(member_key, inherit_path) && member_val.role == "member"
      ]
    ]
  ])


  inherited_members_l3_flat = flatten([
    for l3_key, l3_val in local.level3_teams : [
      for inherit_path in try(l3_val.inherit_members_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l3_key
          username = member_val.username
          role     = member_val.role
        }
        if startswith(member_key, inherit_path) && member_val.role == "member"
      ]
    ]
  ])

  inherited_members_l4_flat = flatten([
    for l4_key, l4_val in local.level4_teams : [
      for inherit_path in try(l4_val.inherit_members_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l4_key
          username = member_val.username
          role     = member_val.role
        }
        if startswith(member_key, inherit_path) && member_val.role == "member"
      ]
    ]
  ])

  ############################
  # Handle inherited maintainers from other teams
  ############################
  inherited_maintainers_flat = flatten([
    for l1_key, l1_val in local.level1_teams : [
      for inherit_path in try(l1_val.inherit_maintainers_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l1_key
          username = member_val.username
          role     = "maintainer"
        }
        if startswith(member_key, inherit_path) && member_val.role == "maintainer"
      ]
    ]
  ])

  inherited_maintainers_l2_flat = flatten([
    for l2_key, l2_val in local.level2_teams : [
      for inherit_path in try(l2_val.inherit_maintainers_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l2_key
          username = member_val.username
          role     = "maintainer"
        }
        if startswith(member_key, inherit_path) && member_val.role == "maintainer"
      ]
    ]
  ])


  inherited_maintainers_l3_flat = flatten([
    for l3_key, l3_val in local.level3_teams : [
      for inherit_path in try(l3_val.inherit_maintainers_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l3_key
          username = member_val.username
          role     = "maintainer"
        }
        if startswith(member_key, inherit_path) && member_val.role == "maintainer"
      ]
    ]
  ])

  inherited_maintainers_l4_flat = flatten([
    for l4_key, l4_val in local.level4_teams : [
      for inherit_path in try(l4_val.inherit_maintainers_from, []) : [
        for member_key, member_val in local.all_members_by_team : {
          team_key = l4_key
          username = member_val.username
          role     = "maintainer"
        }
        if startswith(member_key, inherit_path) && member_val.role == "maintainer"
      ]
    ]
  ])

  # Merge all members (explicit + inherited) across all levels
  all_level1_members_merged = {
    for item in concat(local.level1_members_flat, local.inherited_members_flat, local.inherited_maintainers_flat) : "${item.team_key}::${item.username}" => item
  }

  all_level2_members_merged = {
    for item in concat(local.level2_members_flat, local.inherited_members_l2_flat, local.inherited_maintainers_l2_flat) : "${item.team_key}::${item.username}" => item
  }

  all_level3_members_merged = {
    for item in concat(local.level3_members_flat, local.inherited_members_l3_flat, local.inherited_maintainers_l3_flat) : "${item.team_key}::${item.username}" => item
  }

  all_level4_members_merged = {
    for item in concat(local.level4_members_flat, local.inherited_members_l4_flat, local.inherited_maintainers_l4_flat) : "${item.team_key}::${item.username}" => item
  }
}


############################
# Create Level 1 Teams
############################
resource "github_team" "level1" {
  for_each = local.level1_teams

  name        = each.key
  description = try(each.value.description, null)
  privacy     = try(each.value.privacy, "closed")
}

############################
# Create Level 2 Teams
############################
resource "github_team" "level2" {
  for_each = local.level2_teams

  name           = each.value.name
  description    = try(each.value.description, null)
  privacy        = try(each.value.privacy, "closed")
  parent_team_id = github_team.level1[each.value.parent_key].id
}

############################
# Create Level 3 Teams
############################
resource "github_team" "level3" {
  for_each = local.level3_teams

  name           = each.value.name
  description    = try(each.value.description, null)
  privacy        = try(each.value.privacy, "closed")
  parent_team_id = github_team.level2[each.value.parent_key].id
}

############################
# Create Level 4 Teams
############################
resource "github_team" "level4" {
  for_each = local.level4_teams

  name           = each.value.name
  description    = try(each.value.description, null)
  privacy        = try(each.value.privacy, "closed")
  parent_team_id = github_team.level3[each.value.parent_key].id
}


############################
# Assign members to Level 1 Teams
############################
resource "github_team_membership" "level1" {
  for_each = local.all_level1_members_merged

  team_id  = github_team.level1[each.value.team_key].id
  username = each.value.username
  role     = each.value.role
}

############################
# Assign members to Level 2 Teams
############################
resource "github_team_membership" "level2" {
  for_each = local.all_level2_members_merged

  team_id  = github_team.level2[each.value.team_key].id
  username = each.value.username
  role     = each.value.role
}

############################
# Assign members to Level 3 Teams
############################
resource "github_team_membership" "level3" {
  for_each = local.all_level3_members_merged

  team_id  = github_team.level3[each.value.team_key].id
  username = each.value.username
  role     = each.value.role
}

############################
# Assign members to Level 4 Teams
############################
resource "github_team_membership" "level4" {
  for_each = local.all_level4_members_merged

  team_id  = github_team.level4[each.value.team_key].id
  username = each.value.username
  role     = each.value.role
}

############################
# Manage Organization Members
############################
resource "github_membership" "this" {
  for_each = var.org_members

  username = each.key
  role     = each.value
}
