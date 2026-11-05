#!/bin/sh
# Shared-scheme build post-action: brand the built runner, then sign it normally.
# Hosted unit tests use Stream14.app and have no separate installed runner.
set -eu
runner="${BUILT_PRODUCTS_DIR}/Stream14UITests-Runner.app"
if [ ! -d "$runner" ]; then exit 0; fi
icon="${PROJECT_DIR}/Tools/TestRunnerIcon/Icon.png"
plist="$runner/Info.plist"
/usr/bin/sips -z 120 120 "$icon" --out "$runner/Stream14UITestIcon60x60@2x.png" >/dev/null
/usr/bin/sips -z 180 180 "$icon" --out "$runner/Stream14UITestIcon60x60@3x.png" >/dev/null
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIcons' "$plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :CFBundleIcons dict' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIcons:CFBundlePrimaryIcon dict' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles array' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0 string Stream14UITestIcon60x60' "$plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleDisplayName' "$plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string s14 UI Tests' "$plist"
if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ]; then
    identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
    if [ -z "$identity" ]; then
        case "${PLATFORM_NAME:-}" in
            iphonesimulator) identity="-" ;;
            *)
                # Scheme post-actions may omit EXPANDED_CODE_SIGN_IDENTITY. Reuse
                # the exact public leaf certificate already chosen by Xcode.
                certificate_dir=$(mktemp -d "${TMPDIR:-/tmp}/stream14-runner.XXXXXX")
                trap 'rm -rf "$certificate_dir"' EXIT HUP INT TERM
                /usr/bin/codesign -d --extract-certificates="$certificate_dir/cert-" "$runner"
                identity=$(/usr/bin/openssl x509 -inform DER -in "$certificate_dir/cert-0" -noout -fingerprint -sha1 | /usr/bin/sed 's/.*=//; s/://g')
                [ -n "$identity" ] || { echo 'Unable to identify the existing test-runner signer.' >&2; exit 1; }
                ;;
        esac
    fi
    /usr/bin/codesign --force --sign "$identity" --preserve-metadata=entitlements,requirements,flags,runtime "$runner"
    /usr/bin/codesign --verify --strict "$runner"
fi
