#!/usr/bin/env bash

menu_pause() {
  printf '\nPress Enter to return to the menu...'
  read -r _
}

menu_confirm() {
  local prompt=$1 answer
  printf '%s [y/N] ' "$prompt"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

menu_header() {
  clear 2>/dev/null || true
  cat <<'EOF'
PVE OpenWrt Edge
================

Interactive front-end for the pve-openwrt-edge transactional CLI.
The underlying CLI remains the source of truth for all networking changes.
EOF
}

menu_run() {
  local engine=$1
  while true; do
    menu_header
    cat <<'EOF'

  1) Doctor / check readiness
  2) Test WAN cutover (always restores source)
  3) Apply WAN cutover permanently
  4) Roll back last apply
  5) Status
  6) Last report
  0) Exit

EOF
    printf 'Choose an option: '
    read -r choice
    printf '\n'
    case "$choice" in
    1)
      "$engine" doctor
      menu_pause
      ;;
    2)
      cat <<'EOF'
TEST MODE

This performs the real WAN handoff, validates the target topology, observes it,
and then ALWAYS restores the exact source snapshot.

Keep provider-console access available during the test.
EOF
      if menu_confirm 'Continue with the real temporary cutover?'; then
        "$engine" test
      fi
      menu_pause
      ;;
    3)
      cat <<'EOF'
APPLY MODE

This performs the same real migration as TEST. If every validation check passes,
the rollback watchdog is cancelled and OpenWrt remains the WAN owner.
If validation fails, the source topology is restored automatically.

A successful TEST should be completed first. Keep provider-console access available.
EOF
      if menu_confirm 'Make the validated target topology permanent?'; then
        "$engine" apply
      fi
      menu_pause
      ;;
    4)
      cat <<'EOF'
ROLLBACK

This restores the source snapshot from the latest apply operation.
Use the direct CLI with --run RUN_ID when a specific historical apply is required.
EOF
      if menu_confirm 'Roll back the latest apply snapshot?'; then
        "$engine" rollback
      fi
      menu_pause
      ;;
    5)
      "$engine" status
      menu_pause
      ;;
    6)
      "$engine" report --last
      menu_pause
      ;;
    0 | q | Q)
      return 0
      ;;
    *)
      printf 'Unknown selection: %s\n' "$choice"
      sleep 1
      ;;
    esac
  done
}
