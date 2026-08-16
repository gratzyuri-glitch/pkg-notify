# update-check

A lightweight Bash script for Arch Linux that checks for available updates from both the official repositories and the AUR, then reports the result through KDE Plasma desktop notifications.

The script is designed to **never report "System up to date" when an update check has actually failed**. Failures such as network problems, missing dependencies, command errors, and timeouts are reported separately.

## Features

* Checks official Arch Linux repository updates using `checkupdates`
* Checks AUR updates using `paru -Qua`
* Distinguishes a successful "no updates" result from a failed check
* Uses separate timeouts for official repository and AUR checks
* Prevents overlapping instances with `flock`
* Logs results and errors to a local log file
* Automatically limits the log file to 10 MB
* Sends KDE Plasma desktop notifications
* Persistent update/error notifications use stable notification IDs to avoid stacking
* Temporary "System up to date" notifications disappear automatically
* Notification failures do not cause a successful update check to be reported as failed

## Requirements

This script is intended for **Arch Linux** or an Arch-based distribution with the required tools available.

### Required software

* Bash
* `pacman-contrib` — provides `checkupdates`
* `paru`
* `flock`
* `timeout`
* `mktemp`
* `notify-send`

On a standard Arch Linux installation, `flock`, `timeout`, and `mktemp` are normally provided by the base system.

Install `pacman-contrib` if necessary:

```bash
sudo pacman -S pacman-contrib
```

`paru` must also be installed and configured.

## Installation

Clone the repository:

```bash
git clone https://github.com/gratzyuri-glitch/update-check.git
cd update-check
```

Make the script executable:

```bash
chmod +x update-check.sh
```

You can then run it directly:

```bash
./update-check.sh
```

Alternatively, copy it somewhere in your user's PATH, for example:

```bash
mkdir -p ~/.local/bin
cp update-check.sh ~/.local/bin/
chmod +x ~/.local/bin/update-check.sh
```

Then run:

```bash
update-check.sh
```

## How it works

The script performs two independent update checks.

### 1. Official repository updates

It runs:

```bash
checkupdates
```

The output is captured and counted.

A successful check with no updates is treated as a normal result. Errors, synchronization failures, unexpected exit codes, and timeouts are treated as failures instead of being interpreted as "no updates".

### 2. AUR updates

It runs:

```bash
paru -Qua
```

The script captures both stdout and stderr separately and records Paru's exit status.

AUR output is only counted when:

```text
paru exit code = 0
```

Any non-zero exit code is treated as a failed AUR check.

This is intentional: if Paru cannot successfully complete the check, the script will **not** assume that there are no AUR updates.

### 3. Final result

The number of official repository updates and AUR updates are added together.

For example:

```text
Official updates: 3
AUR updates: 2
```

results in:

```text
Updates available (5)
Official: 3   AUR: 2
```

If both checks successfully report zero updates, the script reports:

```text
System up to date
No pending updates.
```

If either check fails, the script reports:

```text
Update check failed
```

instead.

## Exit status

The script uses its own exit status to distinguish successful checks from failed checks.

### `0`

The update check completed successfully.

This includes both:

* Updates being available
* No updates being available

### `1`

The update check failed.

Examples include:

* `paru` is unavailable
* `checkupdates` is unavailable
* A package database synchronization failure
* Paru returning a non-zero exit status
* An unexpected `checkupdates` exit status
* A timeout
* Required temporary/logging resources being unavailable

Importantly, a failed check does **not** result in a successful `0` exit status merely because no update information was returned.

## Timeouts

The script has separate timeouts for the two update checks:

```bash
CHECKUPDATES_TIMEOUT=60
AUR_TIMEOUT=120
```

The official repository check has a 60-second timeout.

The AUR check has a 120-second timeout because AUR RPC queries can take longer, particularly on systems with many foreign/AUR packages.

These values can be changed near the beginning of the script.

## Logging

The script writes its output to:

```text
~/.local/share/update-check.log
```

The log is automatically truncated when it reaches 10 MB.

This keeps the script self-contained without requiring a separate log rotation service.

## Concurrency protection

The script uses `flock` to prevent multiple instances from running simultaneously.

This is useful when the script is triggered automatically by a timer and a previous run is still checking the network.

If another instance is already running, the new instance exits without performing another update check.

## Notifications

The script uses `notify-send` to display desktop notifications.

There are three notification types:

### Updates available

A persistent critical notification is shown when updates are found.

The notification includes the total number of updates and separates official repository updates from AUR updates.

### System up to date

A normal notification is shown when both checks successfully report no updates.

It automatically disappears after a few seconds.

### Update check failed

A persistent critical notification is shown if the update check itself fails.

This makes an actual failure visually different from a successfully checked system with no updates.

Persistent update/error notifications use stable notification IDs so repeated runs replace the existing notification rather than creating an unlimited stack of persistent notifications.

## Configuration

The main configurable values are near the beginning of `update-check.sh`:

```bash
CHECKUPDATES_TIMEOUT=60
AUR_TIMEOUT=120
```

You can adjust these if your network or system requires longer or shorter timeouts.

The log location is:

```bash
LOG_FILE="$HOME/.local/share/update-check.log"
```

The maximum log size is:

```bash
MAX_LOG_BYTES=$((10 * 1024 * 1024))
```

## Running automatically

The script can be run manually, from a desktop autostart entry, or from a user-level systemd timer.

For example, a systemd timer can be used to periodically run the script in the background.

The script itself does not install or configure a timer, so you can choose whichever scheduling method best fits your system.

## Safety

`update-check.sh` **does not install, upgrade, remove, or modify packages**.

It only checks for available updates and reports the result.

The AUR check uses:

```bash
paru -Qua
```

rather than an installation command.

## License

This project is licensed under the MIT License.

See [`LICENSE`](LICENSE) for the full license text.
