#!/bin/bash
# 编译表盘。默认 Forerunner 970；也可：./build.sh enduro3 | ./build.sh fr955 | ./build.sh fr255 | ./build.sh fr965
set -euo pipefail
if [ -x "$HOME/.local/jdk/jdk-21.0.12.1+1-jre/Contents/Home/bin/java" ]; then
  export JAVA_HOME="$HOME/.local/jdk/jdk-21.0.12.1+1-jre/Contents/Home"
fi
export PATH="${JAVA_HOME:+$JAVA_HOME/bin:}/opt/homebrew/opt/openjdk/bin:/usr/local/opt/openjdk/bin:$PATH"

DEVICE="${1:-fr970}"
cd "$(dirname "$0")"

SDK=""
for d in \
  "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"/connectiq-sdk-mac-* \
  "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"/connectiq-sdk-lin-* \
  "$HOME/.Garmin/ConnectIQ/Sdks"/connectiq-sdk-* \
  /Users/mac/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-*; do
  if [ -x "$d/bin/monkeyc" ]; then
    SDK="$d"
  fi
done
if [ -z "$SDK" ]; then
  echo "找不到 Connect IQ SDK。请先安装 Garmin SDK Manager 并下载 SDK。" >&2
  exit 1
fi

KEY=""
for k in \
  "$(dirname "$0")/keys/developer_key.der" \
  "$(dirname "$0")/../keys/developer_key.der"; do
  if [ -f "$k" ]; then KEY="$k"; break; fi
done
if [ -z "$KEY" ]; then
  mkdir -p "$(dirname "$0")/../keys"
  KEY="$(dirname "$0")/../keys/developer_key.der"
  openssl genrsa -out "$(dirname "$0")/../keys/developer_key.pem" 4096 >/dev/null 2>&1
  openssl pkcs8 -topk8 -inform PEM -outform DER \
    -in "$(dirname "$0")/../keys/developer_key.pem" -out "$KEY" -nocrypt
  echo "已生成开发者密钥 $KEY（不要提交 keys/ 里的 der/pem）"
fi

OUT="bin/TacticalFace-${DEVICE}.prg"
mkdir -p bin
"$SDK/bin/monkeyc" -f monkey.jungle -d "$DEVICE" -o "$OUT" -y "$KEY" -w -l 2
echo "-> $OUT"
if [ "$DEVICE" = "fr970" ]; then
  cp "$OUT" bin/TacticalFace.prg
  echo "-> bin/TacticalFace.prg"
fi
