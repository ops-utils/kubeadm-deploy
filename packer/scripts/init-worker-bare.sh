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
* * * * * root bash /root/scripts/init-worker-bare-atboot.sh >> /var/log/init-k8s-worker-atboot.log 2>&1
EOF

printf \
"Worker's init script has been copied to /etc/init.d/init-k8s-worker-atboot, \
and will run at first boot and then delete itself. \
The backup can still be found at %s/init-worker-bare-atboot.sh\n" "$(pwd)" \
> /dev/stderr

exit 0
