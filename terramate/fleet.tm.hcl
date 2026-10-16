# Generated into every stack tagged "fleet" (shared/fleet and every agent
# policy): the platform's integration package versions (global
# fleet_packages), so one bump reaches every stack that installs or uses a
# package. Imported by terramate.tm.hcl.

generate_hcl "_terramate_generated_fleet_packages.tf" {
  condition = tm_contains(terramate.stack.tags, "fleet")

  content {
    locals {
      fleet_packages = global.fleet_packages
    }
  }
}
