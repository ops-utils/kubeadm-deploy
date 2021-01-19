#!/usr/bin/env bash
set -euo pipefail

# Set number of workers based on the second CLI arg; defaults to 1 if not provided
# worker_count="${2:-1}"

if [[ "${1:-}" == "up" ]]; then

  vboxmanage natnetwork add \
    --netname k8sNatNetwork \
    --network '10.0.2.0/24' \
    --dhcp on \
    --enable \
  || true

  # for name in control-plane worker{1.."${worker_count}"}; do
  for name in control-plane worker; do
    vboxmanage createvm \
      --name k8s-"${name}" \
      --basefolder "${HOME}"/k8s-vms \
      --ostype Linux_64 \
      --default \
      --register \
    || true
    
    vboxmanage modifyvm k8s-"${name}" \
      --memory 2048 \
      --cpus 2 \
      --nic1 natnetwork \
      --nat-network1 k8sNatNetwork \
    || true
    
    vboxmanage storageattach k8s-"${name}" \
      --storagectl IDE \
      --port 0 \
      --device 0 \
      --type hdd \
      --medium ./packer/output-virtualbox-iso-"${name}"/packer-k8s-"${name}"-debian-10.7.0-amd64-disk001.vmdk \
    || true

    vboxmanage startvm k8s-"${name}" || true

  done

elif [[ "${1:-}" == "down" ]]; then

  # for name in control-plane worker{1.."${worker_count}"}; do
  for name in control-plane worker; do

    # Poweroff and wait for it to finish/unlock
    vboxmanage controlvm k8s-"${name}" poweroff || true
    sleep 2

    # 'none' medium removes the device, so we can delete the VM and all the
    # associated files without losing the disk
    vboxmanage storageattach k8s-"${name}" \
      --storagectl IDE \
      --port 0 \
      --device 0 \
      --type hdd \
      --medium none \
    || true

    vboxmanage unregistervm --delete k8s-"${name}"
  
  done
  
  sed -i '/HardDisk/d' ~/.config/VirtualBox/VirtualBox.xml
  rm -rf "${HOME}"/k8s-vms

else
  printf "You must pass 'up' or 'down' as the arg to this script\n" 2>&1
  exit 1
fi
