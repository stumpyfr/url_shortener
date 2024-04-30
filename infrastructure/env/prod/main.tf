module "marvin" {
  source = "../../url_shortener"

  env=var.env
  location=var.location
  PASSWORD=var.PASSWORD
  CLOUDFLARE_API_TOKEN = var.CLOUDFLARE_API_TOKEN
}
