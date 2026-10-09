# TerraVision diagrams with AzAPI resources

AzAPI resources normally use TerraVision's generic icon. This wrapper maps common
ARM resource types to their AzureRM icon equivalents before rendering:

```bash
python3 scripts/terravision-azapi.py \
  --source ./environments/test \
  --format svg \
  --outfile docs/architecture
```

It initializes Terraform, creates a temporary plan and dependency graph, then
renders the rewritten graph. The temporary plan (which can contain sensitive
values) is removed when the script exits. Add or override mappings with a JSON
file containing ARM resource types as keys and supported `azurerm_*` node types
as values, then pass it with `--mapping`. For example:

```json
{
  "Microsoft.ServiceBus/namespaces": "azurerm_servicebus_namespace"
}
```

Only the diagram graph is rewritten; Terraform configuration and resources are
unchanged. Unmapped types are left as `azapi_resource` and reported.
