# k3s VMs: homelab only, not part of the platform. Ansible installs k3s;
# ArgoCD owns what runs on it.
# TODO: move the k3s VM definitions from homelab-proxmox-workloads, using
# the same core VM module as platform/ (VM tags ["terraform", "apps",
# "k3s"]), and add the "proxmox" stack tag so the provider is generated.
