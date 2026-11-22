#!/bin/sh
# Run after scripts/feeds update -a and before scripts/feeds install -a.
# The pinned LuCI revision selects the ambiguous weechat virtual package.
set -eu
cd "$(dirname "$0")/../.."
file=feeds/luci/applications/luci-app-weechat/Makefile
if [ -f "$file" ]; then
    sed -i 's/+weechat +rpcd-mod-ucode/+weechat-minimal +rpcd-mod-ucode/' "$file"
fi
