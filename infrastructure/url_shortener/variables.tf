variable "env" {
    type = string
}

variable "location" {
  type=string
}

variable "PASSWORD" {
  type = string
  sensitive = true
}

variable "CLOUDFLARE_API_TOKEN" {
  type = string
  sensitive = true
}



