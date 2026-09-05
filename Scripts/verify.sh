#!/bin/bash
#
# Checks the parts of ProgGenie that Xcode's test targets can't reach.
#
# Everything real is either in the extension target (extension-only membership)
# or in the enkerli-swift package next door, and MelGenTests-shaped targets see
# neither — so a green test action in Xcode says the host app compiles and very
# little else. This is the check that means something.
#
#   Scripts/verify.sh            # all suites
#   Scripts/verify.sh curation   # one suite
#
# Suites:
#   identity — the audio component triple is unique across every sibling
#              checkout, JUCE and Swift alike, and matches the host app's lookup.
#              First, because it is the one mistake that cannot be taken back:
#              codes are forever, and this project was scaffolded from MelGen's,
#              so it started life claiming MelGen's.
#   curation — the per-transition weights, which are what this plug-in has that
#              MelGen does not, and generation steered by them.
#
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT="$REPO/ProgGenieExtension"
# The foundation is a sibling checkout, the way it is for MelGen. Override with
# ENKERLI_SWIFT=... ; a failure rather than a skip when it is missing, because a
# suite that quietly passed without it would be checking nothing.
PACKAGE="${ENKERLI_SWIFT:-$REPO/../enkerli-swift}"

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

which="${1:-all}"
status=0

PKG_BIN=""
build_package() {
    [ -n "$PKG_BIN" ] && return 0
    if [ ! -f "$PACKAGE/Package.swift" ]; then
        echo "FAIL: no foundation package at $PACKAGE"
        echo "      git clone https://github.com/Enkerli/enkerli-swift ../enkerli-swift"
        echo "      (or set ENKERLI_SWIFT=/path/to/enkerli-swift)"
        status=1
        return 1
    fi
    swift build --package-path "$PACKAGE" >/dev/null || {
        echo "FAIL: the foundation package did not build"; status=1; return 1; }
    PKG_BIN="$(swift build --package-path "$PACKAGE" --show-bin-path)"
}

# The package's modules and objects. UI is left out: these suites are headless,
# and linking SwiftUI views into a command-line binary buys nothing.
package_flags() {
    build_package || return 1
    echo "-I $PKG_BIN/Modules"
    find "$PKG_BIN" -name "*.o" ! -path "*/UI.build/*" ! -path "*/Shell.build/*" | sort
}

# Every extension source that does not need the AU shell. The state, the
# curation and the generation are the whole of what a suite can reach; the two
# AU subclasses and the view need CoreAudioKit and a host.
headless_sources() {
    find "$EXT/Progression" -name "*.swift" | sort
}

run_identity() {
    echo "── identity ───────────────────────────────────────"
    python3 "$REPO/Scripts/tests/component-identity.py" || status=1
}

run_curation() {
    echo "── curation ───────────────────────────────────────"
    cp "$REPO/Scripts/tests/curation-main.swift" "$BUILD/main.swift"
    swiftc -Onone $(package_flags) $(headless_sources) "$BUILD/main.swift" \
        -o "$BUILD/curation" || { status=1; return 0; }
    "$BUILD/curation" || status=1
}

case "$which" in
    identity) run_identity ;;
    curation) run_curation ;;
    all) run_identity; run_curation ;;
    *) echo "unknown suite: $which"; exit 2 ;;
esac

echo
if [ $status -eq 0 ]; then echo "verify: OK"; else echo "verify: FAILURES"; fi
exit $status
