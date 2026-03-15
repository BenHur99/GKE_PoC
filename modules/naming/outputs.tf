output "prefix" {
  description = "Naming prefix: {client}-{product}-{env}-{region_short}"
  value       = local.prefix
}

output "region_short" {
  description = "Short region code (e.g. euw1)"
  value       = local.region_short
}

output "common_labels" {
  description = "Common GCP labels for all resources"
  value       = local.common_labels
}
