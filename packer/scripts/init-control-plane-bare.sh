#!/usr/bin/env bash
set -euo pipefail

# The following is an opinionated method of providing the cluster join info to
# worker nodes. It's a good approach if all your nodes will be running on the
# same network, like a homelab or within a single cloud VPC. Feel free to modify
# as you see fit.

# This script sets up a systemd unit to host an endpoint for workers to retrieve
# the cluster token & hash, so those workers can join the cluster. The workers
# will need to scan the subnet to find where port 8000 is open, then try to
# retrieve these files from the provided endpoint.

cat <<EOF > /etc/systemd/system/kubeadm-join.service
[Unit]
Description=HTTP server helper for joining nodes to this kubeadm cluster

[Service]
ExecStart=/usr/bin/env python3 -m http.server -d /root/kubeadm-join
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF

exit 0
