#!/bin/bash
# Up/Whisper installatie-script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_SRC="$SCRIPT_DIR/models/openai_whisper-large-v3_turbo"
MODEL_DEST="$HOME/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3_turbo"
APP_SRC="$SCRIPT_DIR/Up Whisper.app"
APP_DEST="/Applications/Up Whisper.app"

echo ""
echo "Up/Whisper installatie"
echo "─────────────────────"

# App installeren
echo "→ App kopiëren naar /Applications..."
if [ -d "$APP_DEST" ]; then
  rm -rf "$APP_DEST"
fi
cp -R "$APP_SRC" /Applications/
echo "  ✓ Up Whisper.app geïnstalleerd"

# Model installeren
echo "→ Taalmodel kopiëren (dit kan even duren)..."
mkdir -p "$(dirname "$MODEL_DEST")"
if [ -d "$MODEL_DEST" ]; then
  rm -rf "$MODEL_DEST"
fi
cp -R "$MODEL_SRC" "$MODEL_DEST"
echo "  ✓ large-v3-turbo geïnstalleerd"

echo ""
echo "Klaar! Open Up Whisper via je Launchpad of menubalk."
echo ""
echo "Let op: bij de eerste start vraagt macOS om toegang tot je microfoon"
echo "en Toegankelijkheid (voor automatisch plakken). Beide zijn nodig."
echo ""
read -p "Druk op Enter om dit venster te sluiten..."
