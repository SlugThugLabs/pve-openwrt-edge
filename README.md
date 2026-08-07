# pve-openwrt-edge

`pve-openwrt-edge` converts a supported single-WAN Proxmox/OpenWrt LXC setup
from a host-owned public WAN to an OpenWrt-owned physical WAN. Proxmox remains
managed through OpenWrt's LAN bridge.

It is deliberately conservative:

- `doctor` and `status` only read state.
- `test` snapshots the source topology, arms an independent systemd rollback,
  performs the real target migration, diagnoses it, then always restores source.
- `apply` performs the identical migration and diagnostics. It keeps the target
  only after all checks pass; otherwise it restores source immediately.
- `rollback` restores the selected apply/test snapshot from the provider console.

## Install

```bash
install -D -m 0750 pve-openwrt-edge /usr/local/sbin/pve-openwrt-edge
install -D -m 0600 edge.conf.example /etc/pve-openwrt-edge/edge.conf
install -D -m 0600 target-interfaces.example /etc/pve-openwrt-edge/target-interfaces
```

Edit both files before proceeding. The target interfaces file is intentionally
explicit: it prevents the tool from guessing about additional bridges, VLANs,
or provider-specific interfaces.

## Commands

```bash
pve-openwrt-edge doctor
pve-openwrt-edge status
pve-openwrt-edge test --rollback-after 90
pve-openwrt-edge apply
pve-openwrt-edge rollback --run 20260807T000000Z-apply
pve-openwrt-edge report --last
```

## Initial OpenWrt LXC

Download or otherwise place an OpenWrt **rootfs tarball** on the Proxmox host,
then create the LAN-only container:

```bash
pve-openwrt-edge bootstrap --template /var/lib/vz/template/cache/openwrt-x86-64-rootfs.tar.gz --dry-run
pve-openwrt-edge bootstrap --template /var/lib/vz/template/cache/openwrt-x86-64-rootfs.tar.gz
```

Bootstrap refuses to replace an existing CT. It creates an `unmanaged`,
unprivileged CT with `nesting=1`, one named LAN veth on `LAN_BRIDGE`, boot
startup enabled, OpenWrt LAN set to `LAN_ROUTER_IP`, and DHCP enabled on that
LAN. It deliberately does **not** attach or modify the physical WAN.

Set the initial OpenWrt root password from the Proxmox console after creation.
Only after confirming the LAN-only CT is healthy should `test` be used to trial
the WAN handoff.

`test` and `apply` both arm a systemd rollback watchdog before the first
network-changing operation. The watchdog is independent of the SSH session and
is cancelled only after source recovery (`test`) or successful target validation
(`apply`). Logs, source snapshots, target diagnostics, recovery diagnostics, and
a readable `report.txt` are mode 0600 under `/var/lib/pve-openwrt-edge/runs/`.
Keep the provider console available as an additional recovery path.

The tool changes OpenWrt through `pct exec` and `uci`; it does not mount and
write the unprivileged container's files from the host, avoiding ownership
problems with `/etc/config/network`.

## Scope and migration

This tool supports a direct physical-WAN handoff: the public address must be on
the physical `WAN_PHYS` interface before the operation, and the supplied target
interfaces template must describe the desired LAN-only Proxmox state. It does
not guess how to preserve unrelated bridges, VLANs, or bonded uplinks.

Rollback snapshots are created per operation. A system that was cut over before
this tool was installed retains its original recovery script and backup; run one
new reversible `test` from the source topology before relying on this tool's
`rollback` command for a future deployment.
