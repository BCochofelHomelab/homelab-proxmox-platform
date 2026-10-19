# core

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.9.0, < 2.0 |
| <a name="requirement_elasticstack"></a> [elasticstack](#requirement\_elasticstack) | ~> 0.16.5 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_workspace"></a> [workspace](#module\_workspace) | git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git | 1.0.0 |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_role_names"></a> [role\_names](#output\_role\_names) | The workspace's roles, by kind: assign them to native users in Kibana |
| <a name="output_rule_ids"></a> [rule\_ids](#output\_rule\_ids) | The workspace's alerting rules |
| <a name="output_space_id"></a> [space\_id](#output\_space\_id) | The workspace's Kibana space |
<!-- END_TF_DOCS -->
