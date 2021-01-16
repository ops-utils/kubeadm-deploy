#!/usr/bin/env bash
set -euo pipefail

# Make sure you're in a spot to run/source other scripts from the same workdir
cd "$(dirname "$0")" || exit 1

# Need to interpolate the currently-visible Subnet for the at-boot
# script
sed -i "s;SUBNET_PLACEHOLDER;${subnet:-};g" init-worker-bare-atboot.sh

# Make a cron job entry that runs every reboot, but should remove itself on
# first run
cat <<EOF > /etc/cron.d/init-k8s-worker-atboot
@reboot root bash "$(dirname "$0")"/init-worker-bare-atboot.sh
EOF

printf \
"Worker's init script has been copied to /etc/init.d/init-k8s-worker-atboot, \
and will run at first boot and then delete itself. \
The backup can still be found at %s/init-worker-bare-atboot.sh\n" "$(pwd)" \
> /dev/stderr

exit 0
