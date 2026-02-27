variable "labelPrefix" {
  description = "Your college username. This will form the beginning of various resource names."
  type        = string
  default     = "yang0447"
}

variable "region" {
  description = "Azure region to deploy resources into"
  type        = string
  default     = "canadacentral"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default    = "azureadmin"
}
