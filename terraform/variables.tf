####################
# GLOBAL VARIABLES #
####################


variable "application_short" {
  description = "The name of the application"
  type        = string
  default     = "iiot"
}

// use a map or object vor location! so long and short name are one variable, or use a list to name id automaticly
variable "location" {
  description = "The Resource Location as long name used in Azure like: westeurope"
  type        = string
  default     = "westeurope"
  validation {
    condition     = contains(["Switzerland North", "switzerlandnorth", "Switzerland West", "switzerlandwest", "westeurope"], var.location)
    error_message = "The location has to be switzerlandnorth, switzerlandwest or westeurope"
  }
}

variable "location_short" {
  description = "The Resource Location as short name like: chn"
  type        = string
  default     = "euw"
  validation {
    condition     = contains(["chn", "chw", "euw"], var.location_short)
    error_message = "The location has to be switzerlandnorth, switzerlandwest or westeurope"
  }
}
