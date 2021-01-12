#!/usr/bin/env bash
set -euo pipefail

# I keep having issues where the guest inet interface name keeps changing
# between power cycles -- this script finds the ethernet-looking interfaces,
# adds entries for them, then tries to raise them. This should run as a cronjob
# at each boot, as is enabled by the last line here, which the Packer
# provisioner is also setting on first-run.

# Grab interfaces and put in temp file
ip link show | awk '/ en.*:| eth.*:/ { gsub(":", "", $2); print $2 }' > /tmp/ifaces

# Try to wipe old configs
rm /etc/network/interfaces.d/* > /dev/null 2>&1 || true

# Loop through interfaces found, make an entry for them, then try to raise each
while read -r iface; do
cat <<-EOF > /etc/network/interfaces.d/"${iface}"
auto ${iface}
allow-hotplug ${iface}
iface ${iface} inet dhcp
EOF
/usr/sbin/ifup "${iface}" || true
done < /tmp/ifaces

# Set cronjob to do this at boot
echo '@reboot root bash /usr/local/bin/set-iface.sh > /var/log/set-iface.log 2>&1' > /etc/cron.d/set-iface
