#!/usr/bin/env bash
set -euo pipefail

# The following is an opinionated method of providing the cluster join info to
# worker nodes. It's a good approach if all your nodes will be running on the
# same network, like a homelab or within a single cloud VPC. Feel free to modify
# as you see fit.

# This script runs the core control-plane init, and then sets up a systemd unit
# to host an endpoint for workers to retrieve the cluster token & hash, so those
# workers can join the cluster. The workers will need to scan the subnet to find
# where port 8000 is open, then try to retrieve these files from the provided
# endpoint.

# Run the base init script for the control plane
bash ./init-control-plane.sh

printf "Initializing Control Plane for platform 'bare'...\n" > /dev/stderr

# # Give the control plane node a static IP -- though this seems to break DNS on the host
# iface=$(grep -E -o 'eth[^ ]+ |en[^ ]+ ' /etc/network/interfaces)
# sed -E -i "/iface ${iface}/d" /etc/network/interfaces
# printf "iface %s inet static\n\taddress 10.0.2.15\tnetmask 255.255.255.0\n" "${iface}" >> /etc/network/interfaces

cat <<EOF > /etc/systemd/system/k8s-join.service
[Unit]
Description=HTTP server helper for joining nodes to this Kubernetes cluster

[Service]
ExecStart=/usr/bin/env python3 -m http.server -d /root/k8s-join
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable k8s-join.service
systemctl is-enabled k8s-join.service

exit 0
