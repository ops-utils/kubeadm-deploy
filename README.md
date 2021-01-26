Deployer utilities for various Kubernetes distributions
=======================================================

=== NEED TO UPDATE ===

Deployment wrapper for various [Kubernetes](https://kubernetes.io)
distributions. Currently, there is support for the following Kubernetes
distributions:

* [k3s](https://k3s.io/), a very quick-to-get-started distro from [Rancher
  Labs](https://rancher.com)
* [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm),
  a lower-level cluster bootstrapper from the core Kubernetes team.

Each deployment ...

This is an "easy" way to get `kubeadm` installed on both control plane node(s)
and worker nodes, especially for the examples that include infracode to help
manage . If you don't understand what `kubeadm` is for, or what these scripts
are doing, ***do not use these helpers!***. Read through each script, and
understand what it's doing & what it's asking for before you blindly run this
stuff in production.

Any script not containing a public cloud provider's acronym (e.g. `aws`) in the
filename is intended to be a generic script for any deployment on any host(s).
Those that *are* cloud-provider-specific are either labeled, or entered directly
in the relevant `user-data` etc. fields in the infracode.

How to use
----------

***IN PROGRESS***

The included utilities in this repo can be used as-is to get you up & running
quickly, on various public cloud hosting platforms. You may either fork &
maintain your own version of this repo, or just clone directly and get started.
The included `Makefile` can be used to manage most of the deployment steps for
you automatically. For example, running `make deploy-aws` from the repo
top-level will launch a (private) Kubernetes control plane & Pod nodes using
sensible defaults.

However, by modifying the existing codebase found here, you are free to tailor
the tooling to your own infrastructure constraints, hardware availability, 

The primary value in this repo lies in the contents of the `scripts/` directory.

- The `init-core.sh` script sets up all the `kubeadm` requirements on *all*
  nodes, including the Kubernetes control plane; so, this should be run on every
  node you deploy.

- The `init-control-plane.sh` script will pick up where `init-core.sh` left off,
  and initialize the control plane node(s).

- The `init-node-*.sh` scripts will pick up where `init-core.sh` left off, and
  join your Pod-hosting nodes to the cluster.

Some catches have been provided in the form of error handling and unset-variable
failures in the appropriate scripts. For example, regardless of your hosting
choice, `init-control-plane.sh` needs an environment variable named
`POD_NETWORK_CIDR` to be set prior to running it, and the script will fail if
you don't provide it. Additionally, the example `init-node-*.sh` scripts will
(safely) crash-loop indefinitely until the required data is provided to them
from the control plane node(s) -- which some of the examples will handle for
you. You will find other safeguard examples like this throughout the codebase,
and should you modify it for your own needs, it is recommended to have your own
as well.

The common theme among these scripts is that every node, including the control
plane, will need shared access to several files: the scripts themselves, as well
as things like the cluster token and CA cert hash for joining the other nodes to
the cluster. You can choose to have these various files show up in an AWS S3
bucket, GCP GCS Bucket, an NFS drive (including AWS EFS), or even an FTP server
-- it's entirely up to you. The examples shown in this repo for various public
cloud provider deployments have made opinionated choices in that regard (e.g.
AWS will store everything in an S3 bucket).
