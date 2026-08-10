# pve-openwrt-edge

`pve-openwrt-edge` converts a supported single-WAN Proxmox/OpenWrt LXC setup
from a host-owned public WAN to an OpenWrt-owned physical WAN. Proxmox remains
managed through OpenWrt's LAN bridge.

It is deliberately conservative:

- `doctor` and `status` only read state.
- `test` snapshots the source topology, arms an independent systemd rollback,
  performs the real target migration, diagnoses it, then always restores source.
- `apply` performs the same migration and diagnostics as `test`, but leaves the
  target topology active only after every validation check passes. Otherwise it
  restores source immediately.
- `rollback` restores the selected apply/test snapshot from the provider console.

## Topology

Before cutover:

```text
Internet
   |
WAN_PHYS
   |
Proxmox
   |
LAN_BRIDGE
   |
OpenWrt LXC
```

After a successful `apply`:

```text
Internet
   |
WAN_PHYS
   |
OpenWrt LXC
   |
LAN
   |
LAN_BRIDGE
   |
Proxmox
```

> **Remote-host warning:** `test` and `apply` perform a real management-path
> change and temporarily move the physical WAN away from Proxmox. Keep the
> provider console, IPMI, or another out-of-band recovery path available.

## Quick start

Clone the repository and start the interactive wrapper:

```bash
git clone https://github.com/nhogenson/pve-openwrt-edge.git
cd pve-openwrt-edge
sudo bash setup.sh
```

`setup.sh` installs the current engine to `/usr/local/sbin/pve-openwrt-edge` and,
only when they do not already exist, creates:

```text
/etc/pve-openwrt-edge/edge.conf
/etc/pve-openwrt-edge/target-interfaces
```

from the included examples. Existing configuration is never overwritten by the
wrapper.

The menu provides:

```text
1) Doctor / check readiness
2) Test WAN cutover (always restores source)
3) Apply WAN cutover permanently
4) Roll back last apply
5) Status
6) Last report
0) Exit
```

The menu is intentionally thin. All networking work is still performed by the
`pve-openwrt-edge` CLI, so interactive use and direct/automated use share the
same migration, validation, and rollback implementation.

## Recommended workflow

1. Run `sudo bash setup.sh`.
2. Edit `/etc/pve-openwrt-edge/edge.conf` and `target-interfaces` for the host.
3. Bootstrap the LAN-only OpenWrt container if one does not already exist.
4. Run **Doctor** until readiness checks pass.
5. Run **Test**. This performs the real WAN handoff and then always restores the
   original topology.
6. Review the report and confirm the machine returned to the source topology.
7. Run **Apply**. It performs the same cutover again and keeps it only if every
   target validation check succeeds.

`bootstrap --dry-run` and `test` are very different operations: bootstrap dry-run
only previews initial container creation; `test` performs the real WAN migration
and then rolls it back.

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

## Direct CLI

The interactive wrapper is optional. The engine remains directly scriptable:

```bash
pve-openwrt-edge bootstrap --template ROOTFS
pve-openwrt-edge doctor
pve-openwrt-edge status
pve-openwrt-edge test --rollback-after 90
pve-openwrt-edge apply
pve-openwrt-edge rollback --run 20260807T000000Z-apply
pve-openwrt-edge report --last
```

`test` and `apply` both arm a systemd rollback watchdog before the first
network-changing operation. The watchdog is independent of the SSH session and
is cancelled only after source recovery (`test`) or successful target validation
(`apply`). Logs, source snapshots, target diagnostics, recovery diagnostics, and
a readable `report.txt` are mode 0600 under `/var/lib/pve-openwrt-edge/runs/`.

The tool changes OpenWrt through `pct exec` and `uci`; it does not mount and
write the unprivileged container's files from the host, avoiding ownership
problems with `/etc/config/network`.

## Scope

This tool supports a direct physical-WAN handoff: the public address must be on
the physical `WAN_PHYS` interface before the operation, and the supplied target
interfaces template must describe the desired LAN-only Proxmox state.

It intentionally does not guess how to preserve unrelated bridges, VLANs,
bonded uplinks, or provider-specific routing arrangements.

Rollback snapshots are created per operation. A system that was cut over before
this tool was installed retains its original recovery script and backup; run one
new reversible `test` from the source topology before relying on this tool's
`rollback` command for a future deployment.

## Code layout

```text
pve-openwrt-edge           transactional CLI / networking engine
setup.sh                    clone-and-run installer + menu launcher
lib/menu.sh                 interactive menu and confirmations
edge.conf.example           configuration template
target-interfaces.example  target Proxmox interfaces template
```

The interactive UI is kept separate from the transactional engine so future
refactoring can split the engine into focused modules without creating a second
implementation of the migration logic.
