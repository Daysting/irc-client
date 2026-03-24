#!/usr/bin/env zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
project_dir="$repo_root/Windows/DaystingIRC.Windows"
installer_script="$repo_root/Windows/Installer/DaystingIRC.Windows.nsi"
output_dir="$repo_root/dist/windows"

version="$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' "$project_dir/DaystingIRC.Windows.csproj" | head -n 1)"
if [[ -z "$version" ]]; then
  echo "Unable to determine app version from DaystingIRC.Windows.csproj" >&2
  exit 1
fi

publish_dir="$project_dir/bin/Release/net7.0/win-x64/publish"
version_four="$version"
while [[ "${version_four//./}" == "$version_four" || "$(awk -F. '{print NF}' <<< "$version_four")" -lt 4 ]]; do
  version_four="$version_four.0"
done

mkdir -p "$output_dir"

cd "$project_dir"
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true

makensis \
  -DAPP_VERSION="$version" \
  -DAPP_VERSION_4="$version_four" \
  -DPUBLISH_DIR="$publish_dir" \
  -DOUTPUT_DIR="$output_dir" \
  "$installer_script"

echo "Installer created at: $output_dir/DaystingIRC-Windows-Setup-$version.exe"