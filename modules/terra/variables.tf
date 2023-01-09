variable "instance_type" {
  description = "Type of EC2 instance to provision"
  type        = string
  default     = "t3.nano"
}

variable "min_size" {
  description = "min tomcat instances"
  type = number
  default = 1
}

variable "max_size" {
  description = "max tomcat instances"
  type = number
  default = 1
}

variable "public_port" {
  description = "port to open to public"
  type        = number
  default     = 80
  validation {
    condition     = contains([80, 443], var.public_port)
    error_message = "Valid values for var: public_port are (80,443)."
  } 
}