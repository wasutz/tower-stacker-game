#!/usr/bin/env bash
# Build Tower for one device (debug .prg), every manifest product (smoke test), the store package, or the unit tests.
#   tools/build.sh venu3              -> bin/Tower-venu3.prg
#   tools/build.sh --run fenix7       -> build, then load into the running simulator
#   tools/build.sh --all              -> build every product in manifest.xml, stop on the first failure
#   tools/build.sh --test fr965       -> build with the unit tests and run them in the simulator
#   tools/build.sh --package          -> bin/Tower.iq for the Connect IQ Store
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_HOME="${CIQ_SDK:-$(sed 's:/*$::' "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")}"
KEY="${CIQ_DEVELOPER_KEY:-$ROOT/developer_key.der}"
mkdir -p "$ROOT/bin"

# macOS ships a /usr/bin/java stub that fails without a registered JDK; fall back to Homebrew's OpenJDK.
if ! java -version >/dev/null 2>&1 && [[ -x /opt/homebrew/opt/openjdk/bin/java ]]; then
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
fi

if [[ ! -f "$KEY" ]]; then
    echo "Developer key not found at $KEY (set CIQ_DEVELOPER_KEY or create one, see README)." >&2
    exit 1
fi

compile() {
    "$SDK_HOME/bin/monkeyc" -f "$ROOT/monkey.jungle" -y "$KEY" -w -l 2 "$@"
}

ensure_simulator() {
    pgrep -qf "ConnectIQ.app" || { open "$SDK_HOME/bin/ConnectIQ.app"; sleep 4; }
}

case "${1:-}" in
    --package)
        compile -o "$ROOT/bin/Tower.iq" -e -r
        exit 0
        ;;
    --all)
        for device in $(grep -o 'product id="[^"]*"' "$ROOT/manifest.xml" | cut -d'"' -f2); do
            echo "== $device"
            compile -o "$ROOT/bin/Tower-$device.prg" -d "$device"
        done
        exit 0
        ;;
    --test)
        device="${2:?device id required, e.g. fr965}"
        out="$ROOT/bin/Tower-test-$device.prg"
        compile -o "$out" -d "$device" --unit-test
        ensure_simulator
        "$SDK_HOME/bin/monkeydo" "$out" "$device" -t
        exit 0
        ;;
esac

run=false
if [[ "${1:-}" == "--run" ]]; then
    run=true
    shift
fi
device="${1:?device id required, e.g. venu3}"
out="$ROOT/bin/Tower-$device.prg"
compile -o "$out" -d "$device"

if $run; then
    ensure_simulator
    "$SDK_HOME/bin/monkeydo" "$out" "$device"
fi
