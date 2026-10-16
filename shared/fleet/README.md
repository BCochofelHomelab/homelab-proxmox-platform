# shared/fleet

Fleet, platform-wide: integration packages, the Fleet Server host, the Elasticsearch output and Fleet Server's agent policy.

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
| [elasticstack_fleet_agent_policy.fleet_server](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_agent_policy) | resource |
| [elasticstack_fleet_integration.fleet_server](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_integration) | resource |
| [elasticstack_fleet_integration.system](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_integration) | resource |
| [elasticstack_fleet_integration_policy.fleet_server](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_integration_policy) | resource |
| [elasticstack_fleet_integration_policy.fleet_server_system](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_integration_policy) | resource |
| [elasticstack_fleet_output.elasticsearch](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_output) | resource |
| [elasticstack_fleet_server_host.kibana](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/fleet_server_host) | resource |

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_fleet_server_host"></a> [fleet\_server\_host](#output\_fleet\_server\_host) | Where agents enroll |
| <a name="output_fleet_server_policy_id"></a> [fleet\_server\_policy\_id](#output\_fleet\_server\_policy\_id) | Fleet Server's agent policy (ansible/inventory/group\_vars/fleet\_server.yml) |
| <a name="output_packages"></a> [packages](#output\_packages) | Installed integration packages: name => version |
<!-- END_TF_DOCS -->
