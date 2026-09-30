# modules/storage/account/tests/account.tftest.hcl
mock_provider "azapi" {}
mock_provider "azurerm" {}
mock_provider "random" {}
mock_provider "modtm" {}

variables {
  name      = "stordersdev001"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  location  = "uksouth"
}

# Fails if the wrapper's inputs no longer match the pinned AVM interface.
run "plans_with_defaults" {
  command = plan
}

run "plans_with_non_default_sku" {
  command = plan

  variables {
    account_tier     = "Premium"
    replication_type = "ZRS"
  }
}

run "outputs_are_wired" {
  command = plan

  assert {
    condition     = output.name == var.name
    error_message = "name output should come from the AVM module."
  }
}
