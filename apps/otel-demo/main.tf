# The OTel Astronomy Shop is a customer of the platform: its data lands in
# the otel_demo workspace. ArgoCD deploys the demo; whatever it needs from
# OpenTofu (e.g. the ArgoCD Application bootstrap) goes here.
# TODO: move from homelab-proxmox-workloads. Its collector must set
# data_stream.namespace = otel_demo.
