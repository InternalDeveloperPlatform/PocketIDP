output "humanitec_app" {
  description = "The ID of the Humanitec application"
  value       = humanitec_application.demo.id
}

output "humanitec_app_backstage" {
  description = "The ID of the Humanitec application for Backstage"
  value       = humanitec_application.backstage.id
}
