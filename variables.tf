variable "namespace" {
  type    = string
  default = "istio-system"
}

variable "email" {
  type    = string
  default = "test@example.com"
}

variable "dnsZone" {
  type    = string
  default = "your.domain"
}

variable "dnsName" {
  type    = string
  default = "your.domain"
}

variable "vpnInstanceCount" {
  default = 1
}

variable "aksInstanceCount" {
  default = 1
}
