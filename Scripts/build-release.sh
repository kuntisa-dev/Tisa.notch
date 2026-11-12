#!/bin/bash
# Builds a hardened Release copy of Tisa Dynamic Island, signed with your
# Apple Development certificate.
#
# The fan helper (Tisa Fan Studio) only accepts this kind of build: it trusts the app
# when it is signed by your developer team and refuses builds that allow debugging
# (Debug builds carry that entitlement). Install it once from Fan Studio's Settings;
# later rebuilds keep working. (Helpers installed before this change pinned one exact
# build, so install once more to switch.)
#
# Everything inside the app (Sparkle, Lottie, MediaRemoteAdapter, the XPC service and
# the fan helper) is re-signed with the same certificate, because the hardened runtime
# only loads frameworks signed by the app's own team.
#
# Usage: Scripts/build-release.sh [build folder]
# Set TISA_SIGN_IDENTITY to pick a certificate when you have more than one.
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${1:-$project_dir/build}"

die() { printf '%s\n' "$*" >&2; exit 1; }

identity="${TISA_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
[[ -n "$identity" ]] || die "No valid Apple Development certificate. Add one in Xcode › Settings › Accounts › Manage Certificates, and install Apple's WWDR G3 intermediate from https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
printf 'Signing with %s\n' "$identity"

xcodebuild -project "$project_dir/TisaDynamicIsland.xcodeproj" -scheme TisaDynamicIsland \
    -configuration Release -destination "platform=macOS,arch=$(/usr/bin/uname -m)" -derivedDataPath "$build_dir" \
    ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO -quiet build

app="$build_dir/Build/Products/Release/Tisa Dynamic Island.app"

# Keeps each item's identifier and the entitlements Xcode gave it.
sign() {
    /usr/bin/codesign --force --options runtime --timestamp=none \
        --preserve-metadata=identifier,entitlements,flags --sign "$identity" "$1"
}

# Inside out: nested apps, XPC services and tools first, then their frameworks, the app last.
while IFS= read -r -d '' item; do
    sign "$item"
done < <(find "$app/Contents/Frameworks" -depth \( \( -type d \( -name '*.app' -o -name '*.xpc' \) \) -o \( -type f -name Autoupdate \) \) -print0)
for item in "$app"/Contents/Frameworks/*.framework "$app"/Contents/XPCServices/*.xpc "$app"/Contents/Library/LaunchDaemons/*; do
    [[ -e "$item" ]] && sign "$item"
done
sign "$app"

/usr/bin/codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
printf 'Copy it to /Applications, open it, then set up fan control in Tisa Fan Studio > Settings > Fan Control.\n'
