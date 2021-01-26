`kubeadm` image helpers
=======================

This directory contains helpers for building a set of `kubeadm` machine images.
Specifically, it is intended to leverage [HashiCorp Packer](https://packer.io)
as the build utility, but the shell scripts are generic enough for you to
leverage any way you please.

The utilities target [Debian](https://debian.org) hosts, since frankly Ubuntu
has increasingly become a pain in my ass. You can modify the target OS as you
wish.

Expectation during the agnostic init step(s) is that the cluster join
information (the token and the hash) are found in `/root/k8s-join/*`.

Variables are expected to be stored in a `vars.json` file in this directory.

Packer Notes
------------

* The `amazon-ebs` builder starts with a base AMI that [the Debian team
  maintains](https://wiki.debian.org/Cloud/AmazonEC2Image). This base image
  doesn't come with much of what the Ubuntu AMIs do (SSM agent, etc), so bear
  that in mind when reviewing the contents of the `scripts/` directory. Ideally,
  I'd like to get the `amazon-ebssurrogate` builder working (I can't get the AMI
  to boot), so that if the Debian team ever stops publishing AMIs then the OS
  would still be buildable, but it's working now, so.

  This builder also needs you to provide a target VPC & (public) subnet to build
  in, because the control plane node(s) will misconfigure if the Pod network
  CIDR changes between build time & launch time. Put these in the `vars.json`
  file, as `builder_vpc_id` and `builder_subnet_id`, respectively.

* The `qemu` builder has `"disk_interface": "virtio-scsi"` instead of the
  default `virtio`, because the `grub` install can't seem to find `/dev/sda` on
  my laptop. Not sure about other machines just yet.

`make build` expects a file named `vars.json` to be in this directory -- there
is not one here now, to prevent committing potentiall-sensitive data. Be sure to
add one if you use the Make targets!
