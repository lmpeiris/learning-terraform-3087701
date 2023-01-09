module "tomcat_ha" {
    source "../modules/terra"
    instance_type = "t3a.nano"
    min_size = 1
    max_size = 1
    public_port = 80
}