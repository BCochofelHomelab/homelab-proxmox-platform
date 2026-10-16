# shared/security

Platform roles (`platform-admin`, `platform-viewer`). Workspace roles are each workspace's.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.9.0, < 2.0 |
| <a name="requirement_elasticstack"></a> [elasticstack](#requirement\_elasticstack) | ~> 0.16.5 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_elasticstack"></a> [elasticstack](#provider\_elasticstack) | 0.16.6 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [elasticstack_kibana_security_role.platform_admin](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_security_role) | resource |
| [elasticstack_kibana_security_role.platform_viewer](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_security_role) | resource |

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_roles"></a> [roles](#output\_roles) | The platform roles, to assign to native users |
<!-- END_TF_DOCS -->
