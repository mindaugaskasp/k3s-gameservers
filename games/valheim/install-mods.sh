#!/usr/bin/env bash
# Puts the plugin DLLs of every mods.json package (its pinned "version", else the
# latest Thunderstore release) in the pod's /config/bepinex/plugins. DLLs the server
# already has are kept as they are unless --update is given.
# Run via `make install-mods` / `make update-mods`.
set -euo pipefail

NAMESPACE=${NAMESPACE:-games}
POD=${POD:-valheim-0}
mode=${1:-install}
mods_file=$(dirname "$0")/mods.json
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

installed_dlls=$(kubectl -n "$NAMESPACE" exec "$POD" -c gameserver -- ls -1 /config/bepinex/plugins 2>/dev/null || true)

list_plugins() {
  python3 -c 'import json, sys
for plugin in json.load(open(sys.argv[1]))["plugins"]:
    print(plugin["package"], plugin.get("version", "latest"))' "$mods_file"
}

read_latest_version() {
  curl -fsSL "https://thunderstore.io/api/experimental/package/$1/$2/" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["latest"]["version_number"])'
}

copy_plugin_dll() {
  local dll_name
  dll_name=$(basename "$1")
  if [ "$mode" != --update ] && printf '%s\n' "$installed_dlls" | grep -qx "$dll_name"; then
    echo "  $dll_name is already installed; make update-mods replaces it"
    return
  fi
  kubectl -n "$NAMESPACE" cp "$1" "$POD:/config/bepinex/plugins/$dll_name" -c gameserver
  echo "  installed $dll_name"
}

list_plugins | while read -r package version; do
  owner=${package%%/*}
  name=${package##*/}
  [ "$version" != latest ] || version=$(read_latest_version "$owner" "$name")
  echo "$package $version"
  package_dir="$workdir/$name"
  mkdir -p "$package_dir"
  curl -fsSL "https://thunderstore.io/package/download/$owner/$name/$version/" -o "$package_dir.zip"
  unzip -qo "$package_dir.zip" -d "$package_dir"
  find "$package_dir" -maxdepth 2 -name '*.dll' | while read -r dll; do copy_plugin_dll "$dll"; done
done

kubectl -n "$NAMESPACE" exec "$POD" -c gameserver -- sh -c \
  'chown valheim:valheim /config/bepinex/plugins/*.dll 2>/dev/null; ls -1 /config/bepinex/plugins'
echo "Mods load on the next start: make approve-mods (if the build changed) and make restart"
