# Up/Whisper

On-device speech-to-text for macOS. Lives in your menu bar — press a hotkey anywhere, dictate, and your words appear instantly in whatever text field is active.

No cloud. No API key. No subscription. Everything runs locally via [WhisperKit](https://github.com/argmaxinc/WhisperKit).

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## Features

- **System-wide hotkey** — press `Control + Option` anywhere to start and stop recording
- **Auto-paste** — transcription inserts directly into the active text field using Accessibility API
- **Streaming transcription** — results are ready almost instantly after stopping (WhisperKit processes audio in real time while you speak)
- **Fully on-device** — no internet required after the model is downloaded
- **Transcription history** — last 50 entries, persistent across restarts
- **Multiple models** — choose between speed and accuracy in Settings
- **Language support** — Dutch, English, or auto-detect
- **Menu bar status** — mic icon turns red while recording, orange while processing

---

## Download

**[Download the latest release →](https://github.com/Upscailed/Up-Whisper/releases/latest)**

1. Download `Up Whisper.zip` and unzip it
2. Move `Up Whisper.app` to your Applications folder
3. Right-click the app → **Open** (required on first launch — macOS will warn about an unverified developer)
4. Grant microphone and accessibility permissions when prompted

> The app is ad-hoc signed. Apple's warning on first launch is expected — right-click → Open bypasses it.

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1 or later)
- ~1 GB disk space for the default model (downloaded on first run)

---

## Getting Started

```bash
git clone https://github.com/Upscailed/Up-Whisper.git
cd Up-Whisper
open Package.swift  # opens in Xcode
```

Or build from the command line:

```bash
swift build -c release
```

### Build a distributable .app

To produce a packaged `Up Whisper.app` (with icon, Info.plist, and bundled resources):

```bash
./bundle.sh
```

The app is written to `dist/Up Whisper.app` — drag it to your Applications folder.

### First run

1. Grant **microphone access** when prompted
2. Grant **accessibility access** in System Settings → Privacy & Security → Accessibility (required for auto-paste)
3. The default model (`openai_whisper-large-v3_turbo`, ~950 MB) downloads automatically from Hugging Face on first launch

---

## Usage

| Action | How |
|---|---|
| Start recording | `⌃⌥` (Control + Option) |
| Stop recording | `⌃⌥` again — text pastes into the active field |
| Open Up/Whisper | Click the mic icon in the menu bar |
| View history | Click the clock icon in the popover header |
| Change model or language | Click the gear icon in the popover header |

---

## Available Models

| Model | Size | Best for |
|---|---|---|
| `openai_whisper-large-v3_turbo` | ~950 MB | Default — fast, accurate, multilingual |
| `openai_whisper-medium` | ~500 MB | Balanced |
| `openai_whisper-small` | ~250 MB | Low-memory or older hardware |
| `openai_whisper-large-v3` | ~3 GB | Maximum accuracy |

Models are downloaded from Hugging Face (`argmaxinc/whisperkit-coreml`) on first use and cached locally.

---

## Architecture

```
UpWhisperApp.swift          App entry point
AppDelegate.swift           NSStatusItem + NSPopover + hotkey wiring
Services/
  TranscriptionService.swift  WhisperKit wrapper, model loading, stream factory
  RecordingCoordinator.swift  Orchestrates recording state + streaming callbacks
  HotkeyManager.swift         Global hotkey via NSEvent.addGlobalMonitorForEvents
  PasteService.swift          Auto-paste via AXUIElementSetAttributeValue
  HistoryManager.swift        Local JSON history (~/Library/Application Support/UpWhisper/)
Views/
  PopoverView.swift           Main popover UI
  SettingsView.swift          Model + language picker
  HistoryView.swift           Scrollable transcript history
  RecordingButton.swift       Animated recording button
Models/
  TranscriptionEntry.swift    Codable history entry
```

---

## Permissions

| Permission | Why |
|---|---|
| Microphone | Audio capture |
| Accessibility | Auto-paste into active text fields without clipboard |

---

## Roadmap

- [x] Customizable hotkey in Settings
- [ ] Medical / domain-specific model evaluation (Dutch vocabulary)
- [ ] iOS app (standalone, whisper-small)

---

## License

MIT — see [LICENSE](LICENSE)
