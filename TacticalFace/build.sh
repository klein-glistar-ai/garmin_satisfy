#!/bin/bash
# 编译 Enduro 3 表盘；需要 Homebrew openjdk
export PATH=/opt/homebrew/opt/openjdk/bin:$PATH
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa"
cd "$(dirname "$0")"
"$SDK/bin/monkeyc" -f monkey.jungle -d enduro3 -o bin/TacticalFace.prg -y ../keys/developer_key.der -w -l 2 && echo "-> bin/TacticalFace.prg"
