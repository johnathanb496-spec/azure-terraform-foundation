resource "azuread_application" "pipeline" {
  display_name = "github-azure-terraform-foundation"
}

resource "azuread_service_principal" "pipeline" {
  client_id = azuread_application.pipeline.client_id
}


resource "azuread_application_federated_identity_credential" "pull_request" {
  application_id = azuread_application.pipeline.id
  display_name   = "github-pull-request"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:johnathanb496-spec@240568993/azure-terraform-foundation@1420967840:pull_request"
}

resource "azuread_application_federated_identity_credential" "main" {
  application_id = azuread_application.pipeline.id
  display_name   = "github-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:johnathanb496-spec@240568993/azure-terraform-foundation@1420967840:ref:refs/heads/main"
}
