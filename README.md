# KurdTube AI

A production-ready Flutter Android application that translates YouTube video transcripts into **Central Kurdish (Sorani)** using the Gemini AI API and displays them as fully synchronized subtitles.

---

## Features

- 📱 **Share from YouTube** – Share any YouTube video directly from the official YouTube app; KurdTube AI appears in the Android Share Sheet.
- 🎬 **Embedded Playback** – Watch the video inside the app with the YouTube player.
- 🤖 **AI-Powered Translation** – Uses `gemini-2.5-flash` to translate English closed captions into natural, fluent Central Kurdish (Sorani / Arabic script).
- ⏱ **Synchronized Subtitles** – Kurdish subtitles overlay the video in real time, perfectly synced to playback.
- 📜 **Interactive Transcript** – A dual-language scrolling transcript list auto-highlights and auto-scrolls to the current segment; tap any line to seek.
- 💾 **Local Caching** – Translated transcripts are cached locally so re-watching a video never consumes extra API tokens.
- ⚡ **Streaming Translation** – First batches of subtitles appear within seconds while the rest translate in the background.

---

## Setup

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter | ≥ 3.22.0 |
| Dart | ≥ 3.3.0 |
| Android SDK | API 21+ |
| Java | 17 |

### 1. Clone & install dependencies

```bash
git clone https://github.com/YOUR_USERNAME/kurdtube_ai.git
cd kurdtube_ai
flutter pub get
```

### 2. Download fonts

The app uses **Noto Naskh Arabic** for Sorani Kurdish rendering. Run:

```bash
mkdir -p assets/fonts
curl -L "https://github.com/google/fonts/raw/main/ofl/notonaskharabic/NotoNaskhArabic-Regular.ttf" \
  -o assets/fonts/NotoNaskhArabic-Regular.ttf
curl -L "https://github.com/google/fonts/raw/main/ofl/notonaskharabic/NotoNaskhArabic-Bold.ttf" \
  -o assets/fonts/NotoNaskhArabic-Bold.ttf
```

### 3. Get a Gemini API Key

1. Visit [ai.google.dev](https://ai.google.dev) and sign in with your Google account.
2. Click **"Get API Key"** → **"Create API key"**.
3. Copy the key (starts with `AIza...`).
4. In the app, tap the ⚙️ **Settings** icon and paste your key.

### 4. Run the app

```bash
flutter run
```

---

## Build APK

### Local build

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### GitHub Actions (no local SDK needed)

1. Push this repository to GitHub.
2. Go to **Actions** → **Build KurdTube AI APK** → **Run workflow**.
3. After ~5 minutes, download the APK from the **Artifacts** section.

To create a versioned release, push a tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## Project Structure

```
kurdtube_ai/
├── lib/
│   ├── main.dart                        # App entry point & theming
│   ├── models/
│   │   ├── subtitle_segment.dart        # Data model for a caption segment
│   │   ├── app_settings.dart            # User settings model
│   │   └── translation_state.dart       # Loading/progress state model
│   ├── services/
│   │   ├── settings_service.dart        # SharedPreferences read/write & cache
│   │   ├── youtube_service.dart         # youtube_explode_dart caption extraction
│   │   └── translation_service.dart     # Gemini API batched translation
│   ├── screens/
│   │   └── home_screen.dart             # Main screen (player + transcript)
│   └── widgets/
│       ├── subtitle_overlay.dart        # RTL subtitle overlay on video
│       ├── transcript_list.dart         # Scrollable dual-language list
│       └── settings_dialog.dart         # API key & font size settings
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml          # Share intent & internet permission
│       └── kotlin/.../MainActivity.kt   # Flutter host activity
├── assets/
│   └── fonts/                           # Noto Naskh Arabic (download separately)
├── .github/
│   └── workflows/
│       └── build_apk.yml               # CI/CD: build & publish APK
└── pubspec.yaml
```

---

## How It Works

```
User shares YouTube URL
        │
        ▼
YoutubeService.extractTranscript()
  └─ youtube_explode_dart fetches captions
  └─ Prioritises: manual EN → any manual → auto EN → first track
        │
        ▼
Check local cache (SharedPreferences)
  └─ Cache hit? → Apply translations immediately
  └─ Cache miss? → Send to Gemini API
        │
        ▼
TranslationService.translateSegments()
  └─ Splits into batches of 50 segments
  └─ POST to gemini-2.5-flash with responseMimeType=application/json
  └─ Applies translations as each batch returns (live update)
  └─ Caches result locally
        │
        ▼
YoutubePlayer + SubtitleOverlay + TranscriptList
  └─ Timer polls player position every 250ms
  └─ Finds active segment by timestamp
  └─ Overlay shows Kurdish text (RTL, NotoNaskhArabic)
  └─ TranscriptList auto-scrolls to active segment
  └─ Tap any segment → seek player
```

---

## Privacy

- No backend server. All network calls go directly to YouTube (caption download) and Google Gemini API.
- Your API key is stored only in your device's local `SharedPreferences`.
- Translated transcripts are cached locally only.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
