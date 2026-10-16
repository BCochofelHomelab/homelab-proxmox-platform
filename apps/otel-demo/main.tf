# ----------------------------------------------------------------------------
# The OpenTelemetry demo VM: Docker Compose, sending OTLP to the EDOT
# gateway on ingest. See platform/elastic/main.tf for the shape of `vms`.
# ----------------------------------------------------------------------------

locals {
  vms = {
    # The demo needs about 3 GB of RAM, plus Docker and Elastic Agent.
    "otel-demo" = { ip = "192.168.68.35", cores = 2, memory = 6144, disk = 50, groups = ["otel_demo"] }
  }
}
