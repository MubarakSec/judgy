#!/usr/bin/env bash
# Downloads the multilingual Whisper base model used for offline voice entry.
# The binary is intentionally gitignored; run this once before building.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/assets/models/whisper"
FILE="$DIR/ggml-base-q5_1.bin"
URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin"
SHA="422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898"

mkdir -p "$DIR"

if [[ -f "$FILE" ]] && [[ "$(sha256sum "$FILE" | cut -d' ' -f1)" == "$SHA" ]]; then
  echo "Whisper model is already present and verified: $FILE"
  exit 0
fi

echo "Downloading $URL"
curl -L --fail --continue-at - --output "$FILE" "$URL"
echo "$SHA  $FILE" | sha256sum -c -
echo "Model ready: $FILE"
