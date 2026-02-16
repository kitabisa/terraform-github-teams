# GitHub Teams Terraform Module

A comprehensive Terraform module for managing GitHub teams and organization membership at scale. This module supports hierarchical team structures up to 4 levels deep with flexible member and maintainer assignment, including inheritance capabilities.

## Features

- **Hierarchical Teams**: Support for nested team structures up to 4 levels deep (Level 1 → Level 2 → Level 3 → Level 4)
- **Member & Maintainer Management**: Assign users with specific roles to teams
- **Member Inheritance**: Teams can inherit all members from other teams, preserving their original roles
- **Maintainer Inheritance**: Teams can inherit only maintainers from other teams
- **Organization Membership**: Manage organization-level membership roles
- **Team Privacy Control**: Set team privacy settings (open/closed)
- **Team Descriptions**: Add descriptions to teams for better organization

## Requirements

- Terraform >= 1.0
- GitHub Provider >= 5.0
- Valid GitHub token with appropriate organization permissions

## Module Inputs

### Variables

#### `organization` (required)
- **Type**: `string`
- **Description**: GitHub organization name where teams will be created
- **Example**: `"kitabisa"`

#### `teams` (required)
- **Type**: `any`
- **Description**: Nested GitHub teams structure supporting up to 4 levels of nesting
- **Supported Properties** (per team):
  - `description` (optional): Team description
  - `privacy` (optional): Team privacy level - "open" or "closed" (default: "closed")
  - `members` (optional): List of GitHub usernames to add as team members
  - `maintainers` (optional): List of GitHub usernames to add as team maintainers
  - `inherit_members_from` (optional): List of team paths to inherit all members from, preserving their roles
  - `inherit_maintainers_from` (optional): List of team paths to inherit only maintainers from

#### `org_members` (optional)
- **Type**: `map(string)`
- **Description**: Mapping of GitHub usernames to organization membership roles
- **Default**: `{}`
- **Valid Roles**: "member" or "admin"
- **Example**:
  ```hcl
  org_members = {
    "john-doe"  = "member"
    "jane-smith" = "admin"
  }
  ```

## Module Outputs

### `team_ids`
Map of created teams organized by level with their GitHub team IDs
```hcl
{
  level1 = { "engineering" = "123456" }
  level2 = { "engineering/platform" = "234567" }
  level3 = { "engineering/platform/devops" = "345678" }
  level4 = { "engineering/platform/devops/ops" = "456789" }
}
```

### `team_slugs`
Map of created teams organized by level with their URL-safe slugs
```hcl
{
  level1 = { "engineering" = "engineering" }
  level2 = { "engineering/platform" = "engineering-platform" }
  level3 = { "engineering/platform/devops" = "engineering-platform-devops" }
  level4 = { "engineering/platform/devops/ops" = "engineering-platform-devops-ops" }
}
```

### `team_members`
Map of team memberships across all levels with member roles
```hcl
{
  level1 = { "engineering::user1" = { username = "user1", role = "member" } }
  level2 = { "engineering/platform::user2" = { username = "user2", role = "maintainer" } }
  level3 = { "engineering/platform/devops::user3" = { username = "user3", role = "member" } }
  level4 = { "engineering/platform/devops/ops::user4" = { username = "user4", role = "member" } }
}
```

### `org_members`
Map of organization members with their roles
```hcl
{
  "john-doe"  = "member"
  "jane-smith" = "admin"
}
```

## Usage

### Basic Example: Simple Hierarchy

```hcl
module "github_teams" {
  source = "./terraform/github/teams"

  organization = "kitabisa"

  teams = {
    engineering = {
      platform = {
        devops = {
          members = ["alice", "bob"]
        }
        sre = {
          members = ["charlie"]
        }
      }
      backend = {
        api = {
          members = ["david", "eve"]
        }
      }
    }
  }
}
```

### Advanced Example: With Inheritance

```hcl
module "github_teams" {
  source = "./terraform-github-teams"

  organization = "kitabisa"

  teams = {
    engineering = {
      platform = {
        devops = {
          description = "DevOps Team"
          privacy     = "closed"
          members     = ["alice", "bob"]
          maintainers = ["charlie"]
        }
        sre = {
          members     = ["david"]
          maintainers = ["eve"]
        }
      }
      backend = {
        api = {
          members = ["frank", "grace"]
        }
        data = {
          members = ["henry"]
        }
      }
      # All team (inherits members from all sub-teams)
      all = {
        description = "All Platform Engineers"
        inherit_members_from = [
          "engineering/platform/devops",
          "engineering/platform/sre",
          "engineering/platform/api",
          "engineering/platform/data"
        ]
      }
      # Leadership team (inherits only maintainers)
      leads = {
        description = "Platform Leadership"
        inherit_maintainers_from = [
          "engineering/platform/devops",
          "engineering/platform/sre"
        ]
      }
    }
    non-engineering = {}
  }

  org_members = {
    "alice"  = "member"
    "charlie" = "admin"
  }
}
```

## Team Path References

When using inheritance features, reference teams by their full path:

- **Level 1**: `"engineering"`
- **Level 2**: `"engineering/platform"`
- **Level 3**: `"engineering/platform/devops"`

Example:
```hcl
engineering = {
  platform = {
    all_platform = {
      inherit_members_from = [
        "engineering/platform"  # All direct children of platform team
      ]
    }
  }
}
```

## Inheritance Behavior

### `inherit_members_from`
- Inherits **all members** from specified team paths
- Preserves **original roles** (member stays member, maintainer stays maintainer)
- Useful for creating aggregate/overview teams

### `inherit_maintainers_from`
- Inherits **only maintainers** from specified team paths
- Assigns them with **maintainer role** to the new team
- Useful for leadership/oversight teams

## Notes

1. **Circular Dependencies**: Avoid creating circular inheritance (A inherits from B which inherits from A)
2. **Role Priority**: If a user is added both explicitly and via inheritance, they will have their specified explicit role
3. **Empty Teams**: Teams with only `{}` are still created (useful for team structure without immediate members)
4. **Privacy**: Default team privacy is "closed" - change to "open" if needed
5. **Parent Teams**: Parent teams are created automatically even if they have no explicit members

## Example: Complete Real-World Setup

See [terraform.tfvars.example](terraform.tfvars.example) for a complete working example.

```bash
# Copy example to actual tfvars
cp terraform.tfvars.example terraform.tfvars

# Update with your values
terraform init
terraform plan
terraform apply
```

## Troubleshooting

### Users not being added to teams
- Ensure users are already members of the organization
- Check usernames are spelled correctly (case-sensitive)
- Verify GitHub token has appropriate permissions

### Inheritance not working
- Verify team path references are correct (use full path from root)
- Check for typos in team names
- Ensure source teams are created before inheritance references them

### Plan shows no changes
- This is normal when all resources are already in sync
- Use `terraform refresh` to update state from GitHub

## License

MIT

## Support

For issues or feature requests, please contact the infrastructure team.
