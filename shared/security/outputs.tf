output "roles" {
  value = [
    elasticstack_kibana_security_role.platform_admin.name,
    elasticstack_kibana_security_role.platform_viewer.name,
  ]
  description = "The platform roles, to assign to native users"
}
