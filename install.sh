#!/bin/sh
# Installs the latest cribelo release into /usr/local/bin, or ~/.local/bin when
# /usr/local/bin is not writable. CRIBELO_VERSION=1.2.0 pins a version,
# CRIBELO_INSTALL_DIR=/some/dir chooses the destination.
set -eu

repo="cribelo/cribelo"
os=$(uname -s)
case "$os" in
  Linux) os=Linux ;;
  Darwin) os=Darwin ;;
  MINGW*|MSYS*|CYGWIN*) os=Windows ;;
  *) echo "cribelo: unsupported OS $os" >&2; exit 1 ;;
esac
arch=$(uname -m)
case "$arch" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "cribelo: unsupported architecture $arch" >&2; exit 1 ;;
esac

name="cribelo_${os}_${arch}"
[ "$os" = Windows ] && name="$name.exe"
if [ -n "${CRIBELO_VERSION:-}" ]; then
  url="https://github.com/$repo/releases/download/v${CRIBELO_VERSION#v}/$name"
else
  url="https://github.com/$repo/releases/latest/download/$name"
fi

dir="${CRIBELO_INSTALL_DIR:-}"
if [ -z "$dir" ]; then
  if [ -w /usr/local/bin ]; then dir=/usr/local/bin; else dir="$HOME/.local/bin"; fi
fi
mkdir -p "$dir"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
echo "Downloading $url"
curl -fsSL "$url" -o "$tmp"
chmod +x "$tmp"
mv "$tmp" "$dir/cribelo"
trap - EXIT

echo "Installed $("$dir/cribelo" --version) in $dir"
cmd=cribelo
case ":$PATH:" in
  *":$dir:"*) ;;
  *) cmd="$dir/cribelo"; echo "$dir is not in your PATH: add it, or use the full path below." ;;
esac

cat <<EOF

Now go to a repository, check out the branch you want reviewed, and run:

  $cmd

Short on time? $cmd --budget 30m
EOF
