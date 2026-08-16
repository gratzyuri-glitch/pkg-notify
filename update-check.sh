#!/bin/bash
#
# update-check.sh — checks for pending pacman + AUR (paru) updates
# and pops a persistent KDE Plasma notification. Distinguishes real
# failures (no network, missing tools, command errors, timeouts) from
# a genuine "no updates" result, so a broken check never looks the
# same as an up-to-date system.
#
# Requirements:
#   sudo pacman -S pacman-contrib   # provides `checkupdates`
#   paru must be installed
#   flock, timeout, mktemp          # util-linux / coreutils, standard on Arch
#
set -uo pipefail

# HOME is required before anything else — logging, the lock file, and
# notification state all live under it. Fail loudly and immediately
# rather than crash later on an unbound-variable or bad-path error.
: "${HOME:?HOME is not set — cannot determine where to write logs/lock/notify state}"

# --- tunables ---
CHECKUPDATES_TIMEOUT=60   # seconds
AUR_TIMEOUT=120           # seconds — AUR RPC lookups can be slow with many foreign pkgs

# --- logging ---
# Writes straight to a plain text file and truncates itself once it
# passes ~10MB — no logrotate, no extra services, just a size check.
LOG_FILE="$HOME/.local/share/update-check.log"
MAX_LOG_BYTES=$((10 * 1024 * 1024))  # 10MB

LOG_DIR="$(dirname "$LOG_FILE")"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
    # Logging isn't set up yet, so this one failure gets a direct
    # notify-send instead of going through send_notify/the log.
    notify-send -u critical -a "Update Check" -t 0 \
        "Update check failed" "Cannot write to $LOG_DIR — check permissions." 2>/dev/null
    exit 1
fi

if [[ -f "$LOG_FILE" ]]; then
    log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null) || log_size=0
    if (( log_size >= MAX_LOG_BYTES )); then
        : > "$LOG_FILE"
    fi
fi

# Verify that the actual log file can be created/opened before redirecting
# stdout/stderr into it. A writable directory does not guarantee an
# existing log file is itself writable.
if ! touch "$LOG_FILE" 2>/dev/null || [[ ! -w "$LOG_FILE" ]]; then
    notify-send -u critical -a "Update Check" -t 0         "Update check failed" "Cannot write to $LOG_FILE — check permissions." 2>/dev/null
    exit 1
fi

exec >>"$LOG_FILE" 2>&1
echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"

# --- 1. concurrency guard ---
# Prevents overlapping runs (e.g. a slow network causing one invocation
# to still be running when the next timer fire happens) from racing on
# the log file and spamming duplicate notifications.
LOCK_FILE="$HOME/.local/share/update-check.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Another instance is already running — exiting."
    exit 0
fi

# --- icons ---
# Use a theme icon name (e.g. "emblem-checked") or an absolute path
# to your own image, e.g. "$HOME/.local/share/icons/update-check/ok.png"
ICON_OK="emblem-checked"          # green tick — no updates
ICON_UPDATES="emblem-important"   # red alert — updates found
ICON_ERROR="dialog-error"         # check itself failed

# --- notifications ---
# Persistent notifications use stable IDs so repeated timer runs replace
# the existing notification instead of stacking indefinitely.
# Normal "up to date" notifications intentionally use no replacement ID
# and disappear after a few seconds.
send_notify() {
    # usage: send_notify icon urgency timeout_ms title body [replace_id]
    # Always returns 0 — notification failures must never change the
    # update-check result. stderr is captured in the log.
    local notify_output notify_rc replace_id="${6:-}"

    if [[ -n "$replace_id" ]]; then
        notify_output="$(notify-send -i "$1" -a "Update Check" -u "$2" -t "$3" -r "$replace_id" "$4" "$5" 2>&1)"
    else
        notify_output="$(notify-send -i "$1" -a "Update Check" -u "$2" -t "$3" "$4" "$5" 2>&1)"
    fi
    notify_rc=$?

    if [[ $notify_rc -ne 0 ]]; then
        echo "WARNING: notify-send exited with code $notify_rc ($notify_output)"
    fi

    return 0
}

# Stable IDs prevent persistent notifications from stacking across runs.
NOTIFY_ID_UPDATES=1001
NOTIFY_ID_ERROR=1002

notify_error() {
    echo "ERROR: $1"
    send_notify "$ICON_ERROR" critical 0 "Update check failed" "$1" "$NOTIFY_ID_ERROR"
}

# --- 2. make sure the tools we need actually exist ---
if ! command -v checkupdates >/dev/null 2>&1; then
    notify_error "checkupdates not found. Install pacman-contrib."
    exit 1
fi

if ! command -v paru >/dev/null 2>&1; then
    notify_error "paru not found."
    exit 1
fi

if ! tmp_err="$(mktemp)"; then
    notify_error "Could not create a temp file (is \$TMPDIR writable?)."
    exit 1
fi
trap 'rm -f "$tmp_err"' EXIT

# --- 3. official repo updates ---
# (checkupdates itself fails with exit code 1 if it can't sync —
# including when there's no network — so that's caught below)
official_updates="$(timeout "$CHECKUPDATES_TIMEOUT" checkupdates 2>"$tmp_err")"
official_exit=$?
official_err="$(<"$tmp_err")"
official_count=0

if [[ $official_exit -eq 124 ]]; then
    notify_error "checkupdates timed out after ${CHECKUPDATES_TIMEOUT}s."
    exit 1
elif [[ $official_exit -eq 1 ]]; then
    notify_error "checkupdates failed to sync the package database.${official_err:+ ($official_err)}"
    exit 1
elif [[ $official_exit -eq 0 && -n "$official_updates" ]]; then
    official_count=$(printf '%s\n' "$official_updates" | awk 'END { print NR }')
elif [[ $official_exit -ne 0 && $official_exit -ne 2 ]]; then
    # Unexpected exit code — treat it as a failure rather than risking
    # a false "system up to date" result.
    notify_error "checkupdates exited unexpectedly with code $official_exit.${official_err:+ ($official_err)}"
    exit 1
fi
# exit code 2 = ran fine, just nothing to update — official_count stays 0

# --- 4. AUR updates ---
# A single call captures both stdout and stderr. Do not use paru's exit
# status to mean "updates found": paru can return non-zero when there are
# simply no AUR updates. An empty stdout result is the reliable indication
# of no updates; stderr/non-zero is still treated as a genuine failure.
: > "$tmp_err"
aur_updates="$(timeout "$AUR_TIMEOUT" paru -Qua 2>"$tmp_err")"
aur_exit=$?
aur_err="$(<"$tmp_err")"
aur_count=0

if [[ $aur_exit -eq 124 ]]; then
    notify_error "paru timed out checking AUR updates after ${AUR_TIMEOUT}s."
    exit 1
elif [[ $aur_exit -ne 0 ]]; then
    if [[ -n "$aur_updates" ]]; then
        aur_count=$(printf '%s\n' "$aur_updates" | awk 'END { print NR }')
    elif [[ -n "$aur_err" ]]; then
        notify_error "paru failed to check AUR updates.${aur_err:+ ($aur_err)}"
        exit 1
    fi
elif [[ -n "$aur_updates" ]]; then
    aur_count=$(printf '%s\n' "$aur_updates" | awk 'END { print NR }')
fi

total=$((official_count + aur_count))

echo "Official updates: $official_count"
[[ $official_count -gt 0 ]] && echo "$official_updates"
echo "AUR updates: $aur_count"
[[ $aur_count -gt 0 ]] && echo "$aur_updates"

# --- 5. report result ---
if (( total > 0 )); then
    send_notify "$ICON_UPDATES" critical 0 "Updates available ($total)" "Official: $official_count   AUR: $aur_count" "$NOTIFY_ID_UPDATES"
else
    send_notify "$ICON_OK" normal 5000 "System up to date" "No pending updates."
fi

exit 0
