#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MENU_LIB="$ROOT_DIR/lib/menu.sh"
REPO_ENGINE="$ROOT_DIR/pve-openwrt-edge"
INSTALLED_ENGINE=/usr/local/sbin/pve-openwrt-edge
CONFIG_DIR=/etc/pve-openwrt-edge
CONFIG_FILE="$CONFIG_DIR/edge.conf"
TARGET_FILE="$CONFIG_DIR/target-interfaces"

if [[ $EUID -ne 0 ]]; then
    printf 'setup.sh must run as root. Try: sudo ./setup.sh\n' >&2
    exit 1
fi

[[ -r "$MENU_LIB" ]] || { printf 'Missing menu module: %s\n' "$MENU_LIB" >&2; exit 1; }
[[ -r "$REPO_ENGINE" ]] || { printf 'Missing engine: %s\n' "$REPO_ENGINE" >&2; exit 1; }

install -D -m 0750 "$REPO_ENGINE" "$INSTALLED_ENGINE"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

if [[ ! -e "$CONFIG_FILE" ]]; then
    install -m 0600 "$ROOT_DIR/edge.conf.example" "$CONFIG_FILE"
    printf 'Created %s from the example. Edit it before test/apply.\n' "$CONFIG_FILE"
fi

if [[ ! -e "$TARGET_FILE" ]]; then
    install -m 0600 "$ROOT_DIR/target-interfaces.example" "$TARGET_FILE"
    printf 'Created %s from the example. Edit it before test/apply.\n' "$TARGET_FILE"
fi

# shellcheck source=lib/menu.sh
source "$MENU_LIB"
menu_run "$INSTALLED_ENGINE"
