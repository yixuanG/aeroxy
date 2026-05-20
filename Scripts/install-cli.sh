#!/bin/sh
set -eu

install_dir="${AEROXY_INSTALL_DIR:-$HOME/.local/bin}"
app_path="${AEROXY_APP_PATH:-/Applications/Aeroxy.app}"
repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

cli_source=""

if [ -x "$app_path/Contents/Library/Helpers/aeroxy" ]; then
    cli_source="$app_path/Contents/Library/Helpers/aeroxy"
elif [ -x "$app_path/Contents/MacOS/aeroxy" ]; then
    cli_source="$app_path/Contents/MacOS/aeroxy"
elif [ -x "$repo_root/.build/DerivedData/Build/Products/Release/aeroxy" ]; then
    cli_source="$repo_root/.build/DerivedData/Build/Products/Release/aeroxy"
elif [ -x "$repo_root/.build/DerivedData/Build/Products/Debug/aeroxy" ]; then
    cli_source="$repo_root/.build/DerivedData/Build/Products/Debug/aeroxy"
else
    echo "Aeroxy CLI binary was not found." >&2
    echo "Build Aeroxy first, or set AEROXY_APP_PATH=/path/to/Aeroxy.app." >&2
    exit 1
fi

cli_source="$(CDPATH= cd "$(dirname "$cli_source")" && pwd)/$(basename "$cli_source")"

mkdir -p "$install_dir"
ln -sf "$cli_source" "$install_dir/aeroxy"

echo "Installed aeroxy -> $cli_source"

case ":$PATH:" in
    *":$install_dir:"*) ;;
    *)
        echo "Add $install_dir to PATH to run aeroxy from any directory."
        ;;
esac
