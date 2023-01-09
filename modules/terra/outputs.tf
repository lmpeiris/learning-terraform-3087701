output "alb_dns" {
  value = module.terra-alb.lb_dns_name
}

output "alb_zone_id" {
  value = module.terra-alb.lb_zone_id
}
