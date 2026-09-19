#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resource_dir="$project_root/src-tauri/resources/warp"
download_dir="$project_root/target/warp-download"
arch="${1:-$(uname -m)}"

os="$(uname -s)"
case "$os" in
  Darwin) platform="darwin" ;;
  Linux)  platform="linux" ;;
  *) echo "Unsupported OS: $os" >&2; exit 2 ;;
esac

case "$arch" in
  arm64|aarch64) asset_arch="arm64" ;;
  amd64|x86_64)  asset_arch="amd64" ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 2 ;;
esac

# macOS 使用硬编码校验和
if [[ "$platform" == "darwin" ]]; then
  case "$asset_arch" in
    arm64) expected="762e2dc875669566207a3c776a53dc6bb50770da25f90e1ab69fbc53e91f8da1" ;;
    amd64) expected="1eb41e34bf4cd0b81e06222ef844cea75eb56229a62fe29c07cf8e7bd253357d" ;;
  esac
else
  # Linux 从 checksums.txt 动态获取
  expected=""
fi

url="https://github.com/Diniboy1123/usque/releases/download/v4.2.1/usque_4.2.1_${platform}_${asset_arch}.zip"
archive="$download_dir/usque-${platform}-${asset_arch}.zip"
unpacked="$download_dir/usque-${platform}-${asset_arch}"
mkdir -p "$download_dir" "$resource_dir"

# 跨平台 SHA-256 命令
if command -v shasum >/dev/null 2>&1; then
  hash_cmd="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
  hash_cmd="sha256sum"
else
  echo "No SHA-256 tool found" >&2; exit 1
fi

# 下载 zip（若不存在）
if [[ ! -f "$archive" ]]; then
  curl -fL --retry 3 --connect-timeout 15 --max-time 120 "$url" -o "$archive"
fi

# 若 expected 为空，从 release 的 checksums.txt 查找
if [[ -z "$expected" ]]; then
  checksums_url="https://github.com/Diniboy1123/usque/releases/download/v4.2.1/checksums.txt"
  checksums_file="$download_dir/checksums.txt"
  curl -fL --retry 3 --connect-timeout 15 --max-time 120 "$checksums_url" -o "$checksums_file"
  filename="usque_4.2.1_${platform}_${asset_arch}.zip"
  expected=$(grep "$filename" "$checksums_file" | awk '{print $1}')
  if [[ -z "$expected" ]]; then
    echo "Could not find checksum for $filename in checksums.txt" >&2
    exit 1
  fi
fi

# 校验
actual="$($hash_cmd "$archive" | awk '{print tolower($1)}')"
expected_lower="$(echo "$expected" | tr 'A-Z' 'a-z')"
[[ "$actual" == "$expected_lower" ]] || { echo "usque archive checksum mismatch" >&2; exit 1; }

rm -rf "$unpacked"
mkdir -p "$unpacked"
unzip -q -o "$archive" -d "$unpacked"
rm -f "$resource_dir/usque" "$resource_dir/usque.exe"
install -m 0755 "$unpacked/usque" "$resource_dir/usque"
echo "Bundled usque v4.2.1 (${platform} ${asset_arch}); SHA-256 verified."
