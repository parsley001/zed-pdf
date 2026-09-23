#!/usr/bin/env bash
# Symlink bin/zed-pdf into ~/.local/bin and make sure that is on PATH.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="$HOME/.local/bin"

mkdir -p "$dest"
ln -sf "$here/bin/zed-pdf" "$dest/zed-pdf"
echo "linked $dest/zed-pdf -> $here/bin/zed-pdf"

case ":$PATH:" in
  *":$dest:"*) ;;
  *)
    rc="$HOME/.zshrc"
    if ! grep -q '\.local/bin' "$rc" 2>/dev/null; then
      printf '\n# added by zed-pdf setup\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
      echo "added ~/.local/bin to PATH in $rc — run 'source $rc' or open a new shell"
    fi
    ;;
esac

missing=()
command -v pdftoppm >/dev/null || missing+=("poppler (brew install poppler)")
command -v zed      >/dev/null || missing+=("the zed CLI (Zed > Install CLI)")
if [ ${#missing[@]} -gt 0 ]; then
  echo
  echo "missing dependencies:"
  printf '  - %s\n' "${missing[@]}"
  exit 1
fi

echo "ready. try: zed-pdf $here/examples/sample.pdf"
