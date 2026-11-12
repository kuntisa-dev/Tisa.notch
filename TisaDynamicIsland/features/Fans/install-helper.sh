#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

label=com.kuntisa.tisadynamicisland.fanhelper
daemon="/Library/LaunchDaemons/$label.plist"
tool_dir="/Library/PrivilegedHelperTools"
tool="$tool_dir/$label"
action="${1:-}"
app="${2:-}"

die() { printf '%s\n' "$*" >&2; exit 1; }
[[ "$action" == install || "$action" == uninstall ]] || die "Usage: install-helper.sh install|uninstall "/path/to/Tisa Dynamic Island.app""
[[ "$(id -u)" == 0 ]] || die "Run the command copied from Tisa Dynamic Island with sudo."

stop_daemon() {
    if launchctl print "system/$label" >/dev/null 2>&1; then
        launchctl bootout "system/$label"
        for _ in {1..30}; do
            launchctl print "system/$label" >/dev/null 2>&1 || return 0
            sleep 1
        done
        die "The helper is still running. Try again after it finishes restoring Automatic."
    fi
}

if [[ "$action" == uninstall ]]; then
    stop_daemon
    if [[ -f "/Library/Application Support/TisaFanStudio/helper-state.json" ]]; then
        [[ -f "$daemon" && -x "$tool" ]] && launchctl bootstrap system "$daemon" || true
        die "Cooling recovery is still pending. Leave the helper installed and reconnect in the app."
    fi
    rm -f "$daemon" "$tool"
    printf '%s\n' 'Tisa fan helper removed.'
    exit
fi

[[ "$app" == /*.app && -d "$app" ]] || die "Pass the full path to the built Tisa Dynamic Island app."
[[ "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist")" == com.kuntisa.tisadynamicisland ]] || die "This app has a different bundle identifier."
source_helper="$app/Contents/Library/LaunchDaemons/TisaFanHelper"
[[ -f "$source_helper" && ! -L "$source_helper" ]] || die "The bundled helper is missing."
codesign --verify --deep --strict "$app"
info="$(codesign -dv --verbose=4 "$app" 2>&1)"
printf '%s\n' "$info" | grep -Eq '^CodeDirectory .*flags=.*\(.*runtime.*\)' || die "Build a hardened local app with Scripts/build-release.sh before installing the helper."
team="$(printf '%s\n' "$info" | sed -n 's/^TeamIdentifier=//p')"
[[ "$team" =~ ^[A-Z0-9]{10}$ ]] || die "This build isn't signed by a developer team. Build it with Scripts/build-release.sh."
entitlements="$(codesign -d --entitlements :- "$app" 2>/dev/null)"
if [[ -n "$entitlements" ]]; then
    for key in com.apple.security.get-task-allow com.apple.security.cs.disable-library-validation com.apple.security.cs.allow-dyld-environment-variables com.apple.security.cs.allow-unsigned-executable-memory; do
        value="$(printf '%s' "$entitlements" | plutil -extract "$key" raw - 2>/dev/null || true)"
        # plutil treats dots as key-path separators, so inspect the actual key too.
        if [[ "$value" == true ]] || printf '%s' "$entitlements" | grep -Fq "<key>$key</key>"; then
            die "The app includes a debugging entitlement. Use the hardened release build."
        fi
    done
fi

stage="$(mktemp -d /private/var/tmp/tisa-fan-helper.XXXXXXXX)"
trap 'rm -rf "$stage"' EXIT
install -m 0755 "$source_helper" "$stage/helper"
codesign --verify --strict "$stage/helper"
unexpected="$(otool -L "$stage/helper" | awk '/^[[:space:]]+[^[:space:]]/ { print $1 }' | grep -vE '^(/usr/lib/|/System/Library/)' || true)"
[[ -z "$unexpected" ]] || die "The helper is not self-contained."
cat > "$stage/daemon.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$label</string>
    <key>ProgramArguments</key><array><string>$tool</string></array>
    <key>MachServices</key><dict><key>$label</key><true/></dict>
    <key>EnvironmentVariables</key><dict><key>TISA_FAN_CLIENT_TEAM</key><string>$team</string></dict>
    <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
</dict>
</plist>
PLIST
plutil -lint "$stage/daemon.plist"
stop_daemon
install -d -o root -g wheel -m 0755 "$tool_dir"
install -o root -g wheel -m 0755 "$stage/helper" "$tool"
install -o root -g wheel -m 0644 "$stage/daemon.plist" "$daemon"
launchctl bootstrap system "$daemon"
printf 'Helper installed. It trusts Tisa Dynamic Island builds signed by team %s, so rebuilding needs no reinstall. Click Reconnect in Tisa Fan Studio.\n' "$team"
