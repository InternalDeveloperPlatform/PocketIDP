# Configure required values for backstage
resource "humanitec_value" "backstage_github_org_id" {
  app_id      = humanitec_application.backstage.id
  key         = "GITHUB_ORG_ID"
  description = ""
  value       = "5minorg"
  is_secret   = false
}

resource "humanitec_value" "backstage_humanitec_org" {
  app_id      = humanitec_application.backstage.id
  key         = "HUMANITEC_ORG_ID"
  description = ""
  value       = var.humanitec_org
  is_secret   = false
}

resource "humanitec_value" "backstage_humanitec_token" {
  app_id      = humanitec_application.backstage.id
  key         = "HUMANITEC_TOKEN"
  description = ""
  value       = var.humanitec_token
  is_secret   = true
}

resource "humanitec_value" "backstage_cloud_provider" {
  app_id      = humanitec_application.backstage.id
  key         = "CLOUD_PROVIDER"
  description = ""
  value       = "5min"
  is_secret   = false
}
