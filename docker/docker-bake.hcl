variable "TAG" { default = "0.1.0" }
variable "REGISTRY" { default = "ghcr.io/eknathdj" }

group "default" {
  targets = ["api", "ml-pipeline"]
}

target "api" {
  dockerfile = "docker/Dockerfile.api"
  tags = ["${REGISTRY}/anomaly-api:${TAG}"]
  platforms = ["linux/amd64", "linux/arm64"]
  context = ".."
}

target "ml-pipeline" {
  dockerfile = "docker/Dockerfile.ml-pipeline"
  tags = ["${REGISTRY}/ml-pipeline:${TAG}"]
  platforms = ["linux/amd64", "linux/arm64"]
  context = "."
}