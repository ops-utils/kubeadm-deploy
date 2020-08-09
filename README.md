Deployer utilities for `kubeadm`
================================

Deployment wrappers for the
[kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm)
bootstrapper for [Kubernetes](https://kubernetes.io).

Any script not containing a public cloud provider's acronym (e.g. `aws`) in the
filename is intended to be a generic script for any deployment on any host(s).
Those that *are* cloud-provider-specific are either labeled, or entered directly
in the relevant `user-data` etc. fields in the infracode.

...
