# Ensure we don't have name conflicts
resource "random_string" "install_id" {
  length  = 4
  special = false
  upper   = false
  numeric = false
}

locals {
  app       = "5min-idp-${random_string.install_id.result}"
  backstage = "5min-backstage-${random_string.install_id.result}"
  prefix    = "${local.app}-"
  env_type  = "5min-local"
}

resource "humanitec_environment_type" "local" {
  id          = local.env_type
  description = "Local cluster used by 5min IDP."
}

# Demo application
resource "humanitec_application" "demo" {
  id   = local.app
  name = local.app
}
resource "humanitec_environment" "demo" {
  app_id = local.app
  id     = local.env_type
  name   = "5min IDP local environment"
  type   = local.env_type

  depends_on = [ humanitec_environment_type.local, humanitec_application.demo ]
}

# Backstage application & config
resource "humanitec_application" "backstage" {
  id   = local.backstage
  name = local.backstage
}
resource "humanitec_environment" "backstage" {
  app_id = local.backstage
  id     = local.env_type
  name   = "5min IDP local environment"
  type   = local.env_type

  depends_on = [ humanitec_environment_type.local, humanitec_application.backstage ]
}

# Configure k8s namespace naming
resource "humanitec_resource_definition" "k8s_namespace" {
  driver_type = "humanitec/echo"
  id          = "${local.prefix}k8s-namespace"
  name        = "${local.prefix}k8s-namespace"
  type        = "k8s-namespace"

  driver_inputs = {
    values_string = jsonencode({
      "namespace" = "$${context.app.id}-$${context.env.id}"
    })
  }
}

resource "humanitec_resource_definition_criteria" "k8s_namespace" {
  resource_definition_id = humanitec_resource_definition.k8s_namespace.id
  env_type               = local.env_type

  force_delete = true
  depends_on   = [humanitec_environment_type.local]
}

# Configure DNS for localhost
resource "humanitec_resource_definition" "dns_localhost" {
  id          = "${local.prefix}dns-localhost"
  name        = "${local.prefix}dns-localhost"
  type        = "dns"
  driver_type = "humanitec/dns-wildcard"

  driver_inputs = {
    values_string = jsonencode({
      "domain"   = "localhost"
      "template" = "$${context.app.id}-{{ randAlphaNum 4 | lower}}"
    })
  }

  provision = {
    ingress = {
      match_dependents = false
      is_dependent     = false
    }
  }
}

resource "humanitec_resource_definition_criteria" "dns_localhost" {
  resource_definition_id = humanitec_resource_definition.dns_localhost.id
  env_type               = local.env_type

  force_delete = true
  depends_on   = [humanitec_environment_type.local]
}

# Provide postgres resource
module "postgres_basic" {
  source = "github.com/humanitec-architecture/resource-packs-in-cluster//humanitec-resource-defs/postgres/basic?ref=v2024-06-05"
  prefix = local.prefix
}

resource "humanitec_resource_definition_criteria" "postgres_basic" {
  resource_definition_id = module.postgres_basic.id
  class                  = "default"
  env_type               = local.env_type

  force_delete = true
  depends_on   = [humanitec_environment_type.local]
}
