SHELL = /usr/bin/env bash -euo pipefail

# If you pass 'only=<builder>', it will get sent to the '-only=' flag for
# 'packer build'
ifdef only
onlyflag = -only=$(only)
endif

validate:
	shellcheck scripts/*
	packer validate \
		-var node_type="$${node_type}" \
		-var platform="$${platform}" \
		-var-file vars.json \
		packer.json

build: validate
	packer build \
		-var-file vars.json \
		-var node_type="$${node_type}" \
		-var platform="$${platform}" \
		-force \
		$(onlyflag) \
		-- \
		packer.json

convert-vbox-to-raw:
	@vboxmanage clonemedium disk --format RAW "$${disk}" "$${disk}".img

convert-qemu-to-raw:
	@qemu-img convert -f qcow2 -O raw "$${disk}" "$${disk}".img

convert-qemu-to-vbox:
	@for i in control-plane worker; do \
		printf "Converting $${i} from QEMU qcow2 to VMDK...\n"; \
  	qemu-img convert -O vmdk output-qemu-"$${i}"/packer-k8s-"$${i}"-debian-10.7.0-amd64 output-virtualbox-iso-"$${i}"/packer-k8s-"$${i}"-debian-10.7.0-amd64-disk001.vmdk; \
	done

# Some of these flags need to be set explicitly here; e.g.:
#
# * if RAM is too low you get a kernel panic on boot
#
# * QEMU should know how to handle user-mode networking automatically, but I've
#   had to set the netdev manually to the same that Packer uses at build time
start-qemu:
	qemu-system-x86_64 \
		-drive file="$${disk}" \
		-smp cpus=2 \
		-m size=2048 \
		-device VGA,vgamem_mb=128 \
		-enable-kvm
# Still trying to get the following to work:
# -netdev user,id=user.0 -device virtio-net,netdev=user.0 \
# -device virtio-net,netdev=network0 -netdev tap,id=network0,ifname=tap0,script=no,downscript=no,vhost=on \

packer-write-to-device:
	@printf "\nYou can write the .img created with the 'convert-vbox-to-raw' target to a \n" > /dev/stderr
	@printf "physical disk by running (for example) the 'dd' or 'pv' tools: \n\n" > /dev/stderr
	@printf "$$ dd if=./disk.img of=/dev/sdX status=progress \n" > /dev/stderr
	@printf "# or \n" > /dev/stderr
	@printf "$$ pv < ./disk.img > /dev/sdX \n\n" > /dev/stderr
	@printf "both of which specify '/dev/sdX' as the target device to write to. \n\n" > /dev/stderr
