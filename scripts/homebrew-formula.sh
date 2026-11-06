#!/bin/sh
# Prints the Homebrew formula for one cribelo release. The binaries must already
# be in DIR under their release names (cribelo_Darwin_arm64...).
#   scripts/homebrew-formula.sh 1.2.0 out/ > Formula/cribelo.rb
set -eu

version="${1#v}"
dir="$2"
base="https://github.com/cribelo/cribelo/releases/download/v$version"

sum() {
  f="$dir/$1"
  [ -f "$f" ] || { echo "homebrew-formula: missing $f" >&2; exit 1; }
  if command -v sha256sum >/dev/null; then sha256sum "$f"; else shasum -a 256 "$f"; fi | cut -d' ' -f1
}

cat <<RUBY
class Cribelo < Formula
  desc "Ranks the files of a pull request by how much they need a human reader"
  homepage "https://github.com/cribelo/cribelo"
  license "MIT"

  on_macos do
    on_arm do
      url "$base/cribelo_Darwin_arm64"
      sha256 "$(sum cribelo_Darwin_arm64)"
    end
    on_intel do
      url "$base/cribelo_Darwin_x86_64"
      sha256 "$(sum cribelo_Darwin_x86_64)"
    end
  end

  on_linux do
    on_arm do
      url "$base/cribelo_Linux_arm64"
      sha256 "$(sum cribelo_Linux_arm64)"
    end
    on_intel do
      url "$base/cribelo_Linux_x86_64"
      sha256 "$(sum cribelo_Linux_x86_64)"
    end
  end

  def install
    bin.install Dir["cribelo_*"].first => "cribelo"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/cribelo --version")
  end
end
RUBY
