# modules/resources/resourcegroup/tests/resourcegroup.tftest.hcl
mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azurerm" {}

variables {
  name     = "rg-orders-dev-uks-001"
  location = "uksouth"
}

run "plans_with_defaults" {
  command = plan
}

run "plans_with_tags" {
  command = plan
  variables {
    tags = { environment = "test" }
  }
}

run "outputs_are_wired" {
  command = plan

  assert {
    condition     = output.name == "myrandomval"
    error_message = "name output should come from the AVM module."
  }
}
