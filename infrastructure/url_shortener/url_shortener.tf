resource "azurerm_resource_group" "url_shortener_rg" {
  name     = "url_shortener_${var.env}"
  location = var.location

  tags = {
    env = var.env
  }
}

resource "azurerm_storage_account" "url_shortener_storage_account" {
  name                     = "urlshortener${var.env}storage"
  resource_group_name      = azurerm_resource_group.url_shortener_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_table" "url_shortener_storage_table" {
  name                 = "links"
  storage_account_name = azurerm_storage_account.url_shortener_storage_account.name
}

resource "azurerm_log_analytics_workspace" "url_shortener_log_analytics_workspace" {
  name                = "url-shortener-${var.env}-log-analytics-workspace"
  location            = azurerm_resource_group.url_shortener_rg.location
  resource_group_name = azurerm_resource_group.url_shortener_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "url_shortener_application_insights" {
  name                = "url-shortener-${var.env}-application-insights"
  location            = azurerm_resource_group.url_shortener_rg.location
  resource_group_name = azurerm_resource_group.url_shortener_rg.name
  workspace_id        = azurerm_log_analytics_workspace.url_shortener_log_analytics_workspace.id
  application_type    = "other"
}

resource "azurerm_service_plan" "url_shortener_service_plan" {
  name                = "url-shortener-${var.env}-app-service-plan"
  resource_group_name = azurerm_resource_group.url_shortener_rg.name
  location            = azurerm_resource_group.url_shortener_rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "url_shortener_function_app" {
  name                = "url-shortener-${var.env}-function-app"
  resource_group_name = azurerm_resource_group.url_shortener_rg.name
  location            = azurerm_resource_group.url_shortener_rg.location

  storage_account_name       = azurerm_storage_account.url_shortener_storage_account.name
  storage_account_access_key = azurerm_storage_account.url_shortener_storage_account.primary_access_key
  service_plan_id            = azurerm_service_plan.url_shortener_service_plan.id

  app_settings = {
    "WEBSITE_MOUNT_ENABLED"     = "1",
    "WEBSITE_RUN_FROM_PACKAGE"  = "",
    "PASSWORD"           = var.PASSWORD,
  }

  connection_string {
    type = "Custom"
    name  = "AzureStorageConnectionString"
    value = azurerm_storage_account.url_shortener_storage_account.primary_connection_string
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.url_shortener_application_insights.connection_string
    application_insights_key               = azurerm_application_insights.url_shortener_application_insights.instrumentation_key
  }
}

resource "azurerm_app_service_custom_hostname_binding" "url_shortener_custom_domain" {
  count = var.env == "dev" ? 1 : 0
  hostname            = "link-${var.env}.niels.freier.fr"
  app_service_name    = azurerm_linux_function_app.url_shortener_function_app.name
  resource_group_name = azurerm_resource_group.url_shortener_rg.name

  # Ignore ssl_state and thumbprint as they are managed using
  # azurerm_app_service_certificate_binding.example
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }

  depends_on = [
    azurerm_app_service_custom_hostname_binding.url_shortener_custom_domain
  ]
}

resource "azurerm_app_service_custom_hostname_binding" "url_shortener_custom_domain_prd" {
  count = var.env == "prd" ? 1 : 0
  hostname            = "link.niels.freier.fr"
  app_service_name    = azurerm_linux_function_app.url_shortener_function_app.name
  resource_group_name = azurerm_resource_group.url_shortener_rg.name

  # Ignore ssl_state and thumbprint as they are managed using
  # azurerm_app_service_certificate_binding.example
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }

  depends_on = [
    azurerm_app_service_custom_hostname_binding.url_shortener_custom_domain
  ]
}

resource "azurerm_app_service_managed_certificate" "url_shortener_managed_certificate" {
  count = var.env == "dev" ? 1 : 0
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.url_shortener_custom_domain[0].id
}

resource "azurerm_app_service_certificate_binding" "url_shortener_managed_certificate_binding" {
  count = var.env == "dev" ? 1 : 0
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.url_shortener_custom_domain[0].id
  certificate_id      = azurerm_app_service_managed_certificate.url_shortener_managed_certificate[0].id
  ssl_state           = "SniEnabled"
}

resource "azurerm_app_service_managed_certificate" "url_shortener_managed_certificate_prd" {
  count = var.env == "prd" ? 1 : 0
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.url_shortener_custom_domain_prd[0].id
}

resource "azurerm_app_service_certificate_binding" "url_shortener_managed_certificate_binding_prd" {
  count = var.env == "prd" ? 1 : 0
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.url_shortener_custom_domain_prd[0].id
  certificate_id      = azurerm_app_service_managed_certificate.url_shortener_managed_certificate_prd[0].id
  ssl_state           = "SniEnabled"
}

resource "cloudflare_record" "url_shortener_dns_txt" {
  count = var.env == "dev" ? 1 : 0
  zone_id = data.cloudflare_zone.freier_fr.id
  name    = "asuid.link-${var.env}.niels"
  value   = azurerm_linux_function_app.url_shortener_function_app.custom_domain_verification_id
  type    = "TXT"
  ttl     = 300
}

resource "cloudflare_record" "url_shortener_cname" {
  count = var.env == "dev" ? 1 : 0
  zone_id = data.cloudflare_zone.freier_fr.id
  name    = "link-${var.env}.niels"
  value   = azurerm_linux_function_app.url_shortener_function_app.default_hostname
  type    = "CNAME"
  proxied = false
}

resource "cloudflare_record" "url_shortener_dns_txt_prd" {
  count = var.env == "prd" ? 1 : 0
  zone_id = data.cloudflare_zone.freier_fr.id
  name    = "asuid.link.niels"
  value   = azurerm_linux_function_app.url_shortener_function_app.custom_domain_verification_id
  type    = "TXT"
  ttl     = 300
}

resource "cloudflare_record" "url_shortener_cname_prd" {
  count = var.env == "prd" ? 1 : 0
  zone_id = data.cloudflare_zone.freier_fr.id
  name    = "link.niels"
  value   = azurerm_linux_function_app.url_shortener_function_app.default_hostname
  type    = "CNAME"
  proxied = false
}
