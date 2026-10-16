# otel-demo

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
| [elasticstack_fleet_agent_policy.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_agent_policy) | resource |
| [elasticstack_fleet_integration_policy.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_integration_policy) | resource |

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_policy_id"></a> [policy\_id](#output\_policy\_id) | The agent policy's id (elastic\_agent\_policy\_id in Ansible's group\_vars) |
<!-- END_TF_DOCS -->
