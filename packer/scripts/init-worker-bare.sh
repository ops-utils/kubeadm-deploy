#!/usr/bin/env bash
set -euo pipefail

trim() {
  sed -E 's/\s\s+//g' <("$@")
}

nmap -p8000 -- "${pod_network_cidr:-NO_POD_NETWORK_CIDR}" \
| grep -B4 -E '8000/tcp\s+open' \
| grep 'scan report' \
| grep -o -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
> /tmp/netscan || {
  trim printf "\
    ERROR: Could not find any running hosts on subnet %s with open port 8000.
    You may want to confirm the control plane is running and broadcasting.
    Exiting cleanly, so you can try again later from this node.\n" \
  "${pod_network_cidr}" \
  > /dev/stderr
  exit 0
}

while read -r host; do
  for filename in token hash; do
    curl -fsSL --connect-timeout 1 -o /tmp/"${filename}" "${host}":8000/"${filename}" || {
      trim printf "\
        ERROR: Could not retrieve %s from %s:8000.
        The host is probably up (since it was checked a few seconds ago), but the file isn't there.
        Either skipping this host, or exiting cleanly, so you can try again later from this node.\n" \
        "${filename}" "${host}" \
        > /dev/stderr
      continue
    }
  done
done < /tmp/netscan

# Join the cluster
kubeadm join \
  --token "$(cat /tmp/token)" \
  --discovery-token-ca-cert-hash "sha256:$(cat /tmp/hash)" \
  -- \
  "${control_plane_ip:-}":6443 \
|| {
  trim printf "\
  ERROR: Unable to join this node to the cluster.
  Exiting cleanly, so you can try again later from this node.\n" \
  > /dev/stderr
  exit 0
}

exit 0
