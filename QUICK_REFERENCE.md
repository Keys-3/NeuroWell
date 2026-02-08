# NeuroWell Live Translation Tab - Quick Reference

## ✅ Status: Ready to Run

The compilation error has been fixed. All features are implemented and ready to test.

---

## 🎯 Quick Feature Map

| Feature | File | Status | What It Does |
|---------|------|--------|--------------|
| **Online/Offline Badge** | `live_view.dart` (lines 485-565) | ✅ Complete | Green/Red indicator for device status |
| **Zero Data Display** | `biosensor_service.dart` (lines 76-92) | ✅ Complete | Shows 0 when D0 & D1 are OFF |
| **Normal Data (D0)** | `biosensor_service.dart` (lines 94-140) | ✅ Complete | HR 60-100 BPM, SpO2 95-100% |
| **Stress Data (D1)** | `biosensor_service.dart` (lines 101-110) | ✅ Complete | HR 100-140 BPM, SpO2 88-94% |
| **40s Retry Logic** | `live_view.dart` (lines 148-168) | ✅ Complete | Auto-reconnect for 40 seconds |
| **Session Timeline** | `live_view.dart` (lines 117-136) | ✅ Complete | Records all sensor data with timestamps |
| **Live Transcription** | `transcription_service.dart` | ✅ Complete | Speech-to-text capture with REC badge |
| **Gemini Analysis** | `gemini_service.dart` | ✅ Complete | AI insights + post-session report |
| **Stress Score** | `live_view.dart` (lines 604-670) | ✅ Complete | 0-10 score based on HR & SpO2 |
| **Error Fix** | `biosensor_service.dart` (lines 180-183) | ✅ **FIXED** | Added missing `forceFetchStatus()` method |

---

## 🚀 How to Run

```bash
# 1. Ensure dependencies are installed
flutter pub get

# 2. Set environment variables (create .env file)
cat > .env << EOF
BLYNK_AUTH_TOKEN=your_blynk_token
GEMINI_API_KEY=your_gemini_api_key
EOF

# 3. Run the app
flutter run

# Choose device:
# [1]: Windows (desktop)
# [2]: Chrome (web)
# [3]: Edge (web)
```

---

## 🔌 What Connects to What

```
Hardware (ESP32)
    ↓ (via Blynk Cloud)
BlynkService (checks D0, D1, online status)
    ↓
BiosensorService (generates realistic data)
    ↓
LiveMonitoringView (displays UI)
    ↓
TranscriptionService + GeminiService (AI analysis)
```

---

## 📊 Data Display States

### Offline State
```
❌ STREAM OFFLINE (red)
└─ Retry Button
└─ Error Details
└─ Rapid reconnect attempts (every 500ms)
└─ Gives up after ~40 seconds
```

### Online - No Data (D0 & D1 OFF)
```
✅ STREAM ONLINE (green)
└─ HR: 0 BPM
└─ SpO2: 0%
└─ GSR: 0 µS
└─ Stress Score: 0/10 (green)
```

### Normal Mode (D0 ON)
```
✅ STREAM ONLINE (green)
└─ HR: 60-100 BPM (realistic variation)
└─ SpO2: 95-100% (realistic variation)
└─ GSR: 0.5-4.0 µS (realistic variation)
└─ Stress Score: 0-5/10 (green)
└─ Color: Red heart icon
```

### Stress Mode (D1 ON)
```
✅ STREAM ONLINE (green)
└─ HR: 100-140 BPM (elevated)
└─ SpO2: 88-94% (lowered)
└─ GSR: 0.5-4.0 µS (realistic variation)
└─ Stress Score: 5-10/10 (orange)
└─ Color: Orange/amber heart icon
```

---

## 🎤 Session Recording Flow

```
START SESSION
    ↓
Connect to Hardware (40s retry)
    ↓
Start Microphone (REC badge appears)
    ↓
Record Transcription (live display)
    ↓
Collect Sensor Data with Timestamps
    ├─ Every 1 second
    ├─ Format: MM:SS, HR, SpO2, Stress
    ├─ Sent to GeminiService
    └─ Displayed in timeline
    ↓
[Optional] Click "Generate Insight"
    ↓
END SESSION
    ↓
Show Summary Dialog
    ├─ Session Duration
    ├─ Avg Stats
    ├─ Full Transcript
    └─ "Generate Detailed Medical Report" Button
    ↓
[Click Button]
    ↓
Send to Gemini 2.5 Flash:
    ├─ Full transcript
    ├─ Timeline data (with timestamps)
    ├─ Average stats
    └─ Duration
    ↓
Receive AI Report:
    ├─ Patient State Summary
    ├─ Key Topics Discussed
    ├─ Clinical Observations (correlations)
    └─ Recommendations
```

---

## 🔑 Key Configuration Files

### 1. `.env` (Create this file in project root)
```env
BLYNK_AUTH_TOKEN=your_auth_token_here
GEMINI_API_KEY=your_gemini_key_here
```

### 2. `lib/main.dart`
Initializes:
- Firebase
- DotEnv (loads .env)
- Providers (AuthService, GeminiService)

### 3. `lib/data/services/blynk_service.dart`
- Polls Blynk cloud every 3 seconds
- Checks hardware status
- Reads D0 (normal) and D1 (stress) pins
- Emits BlynkStatus changes

### 4. `lib/data/services/biosensor_service.dart`
- **Fixed**: Now has `forceFetchStatus()` method
- Generates realistic sensor data
- Adapts ranges based on BlynkStatus

---

## 📱 Status Badge Meanings

| Badge | Color | Meaning | Action |
|-------|-------|---------|--------|
| STREAM ONLINE | 🟢 Green | Device connected | Normal operation |
| STREAM OFFLINE | 🔴 Red | Device disconnected | Auto-retrying (40s) |
| REC | 🔴 Red (on badge) | Recording audio | Session is active |
| LIVE SESSION | 🔵 Blue | Session active | Cannot start another |

---

## 🧮 Stress Score Formula

```
Score = (HR_Score + SpO2_Score) / 2

Where:
  HR_Score = ((HR - 60) / 80) × 10      [Range: 0-10]
  SpO2_Score = ((100 - SpO2) / 10) × 10 [Range: 0-10]
  
Examples:
  Normal (HR=75, SpO2=98):   Score = 2.5  (Green ✅)
  Elevated (HR=120, SpO2=92): Score = 7.5 (Orange ⚠️)
  Stress (HR=140, SpO2=88):   Score = 10.0 (Red 🔴)
```

---

## 🐛 The Bug That Was Fixed

**Error Message**:
```
The method 'forceFetchStatus' isn't defined for the type 'BiosensorService'
```

**Location**: `lib/ui/monitoring/live_view.dart:166`

**Root Cause**: Called `_service.forceFetchStatus()` but method didn't exist.

**Fix Applied**:
```dart
// Added to BiosensorService (line 180-183)
Future<void> forceFetchStatus() async {
  await _blynkService.forceFetchStatus();
}
```

**Why It Matters**: This method is called during rapid retry to force an immediate connection check instead of waiting 3 seconds.

---

## 🎯 Testing Checklist

### Before Running
- [ ] `.env` file created with API keys
- [ ] `flutter pub get` completed successfully
- [ ] No compilation errors: `flutter analyze`

### During Session (Normal Mode D0 ON)
- [ ] Green "STREAM ONLINE" badge appears
- [ ] HR 60-100 BPM, SpO2 95-100%
- [ ] Stress Score 0-5 (green)
- [ ] Red heart icon
- [ ] Chart shows ECG waveform

### During Session (Stress Mode D1 ON)
- [ ] Green "STREAM ONLINE" badge appears  
- [ ] HR 100-140 BPM, SpO2 88-94%
- [ ] Stress Score 5-10 (orange)
- [ ] Heart icon changes color to orange
- [ ] Chart shows elevated pattern

### Transcription
- [ ] REC badge appears when session starts
- [ ] Microphone opens automatically
- [ ] Spoken words appear in AI Insights box
- [ ] REC badge disappears on session end

### AI Analysis
- [ ] Can click "Generate Insight" during session
- [ ] Report dialog shows on session end
- [ ] "Generate Detailed Medical Report" button works
- [ ] Gemini response appears within 10 seconds

### End Session
- [ ] Summary dialog shows duration
- [ ] Avg stats calculated correctly
- [ ] Full transcript displayed
- [ ] Report generation succeeds

---

## 💡 Troubleshooting Tips

| Issue | Quick Fix |
|-------|-----------|
| App won't compile | Run `flutter clean && flutter pub get` |
| Always shows offline | Check `.env` BLYNK_AUTH_TOKEN is correct |
| No transcription | Ensure microphone permission granted |
| Gemini fails | Check `.env` GEMINI_API_KEY is valid |
| Data shows 0 | Toggle D0 or D1 in Blynk dashboard |
| Session won't start | Check hardware connection in Blynk cloud |
| Stress score incorrect | Verify HR and SpO2 ranges match mode |

---

## 📚 File Reference

```
lib/
├── main.dart                                    (App entry point)
├── data/
│   ├── models/
│   │   └── biosensor_data_model.dart           (Data structure)
│   └── services/
│       ├── biosensor_service.dart              (✅ FIXED - Data generation)
│       ├── blynk_service.dart                  (Hardware connection)
│       ├── gemini_service.dart                 (AI analysis)
│       └── transcription_service.dart          (Speech recognition)
├── ui/
│   └── monitoring/
│       ├── live_view.dart                      (Main UI - Status, Retry, Timeline)
│       └── widgets/
│           ├── telemetry_card.dart             (Data display cards)
│           └── telemetry_chart.dart            (ECG chart)
└── core/
    ├── constants.dart                          (App colors, strings)
    └── theme.dart                              (UI theme)
```

---

## 🎓 Understanding the Architecture

```
┌─────────────────────────────────────┐
│    UI Layer (live_view.dart)        │
│  ┌─────────────────────────────┐    │
│  │ Status Badge (Online/Offline)   │
│  │ Telemetry Cards (HR, SpO2)      │
│  │ Stress Score                     │
│  │ Session Timer                    │
│  │ Transcription Display            │
│  │ AI Insights Card                 │
│  └─────────────────────────────┘    │
└──────────┬──────────────────────────┘
           │ StreamBuilder
           │ listens to
           ▼
┌─────────────────────────────────────┐
│  Service Layer                      │
│  ┌──────────────────────────────┐   │
│  │ BiosensorService ✅ FIXED    │   │
│  │ • Generates data             │   │
│  │ • Manages BlynkService       │   │
│  │ • Exposes data stream        │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ BlynkService                 │   │
│  │ • Polls every 3 seconds      │   │
│  │ • Reads D0, D1, connection   │   │
│  │ • Has forceFetchStatus()     │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ TranscriptionService         │   │
│  │ • Captures speech            │   │
│  │ • Emits transcript           │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ GeminiService                │   │
│  │ • Analyzes live data         │   │
│  │ • Generates reports          │   │
│  └──────────────────────────────┘   │
└──────────┬──────────────────────────┘
           │ HTTP requests
           │ Emits streams
           ▼
┌─────────────────────────────────────┐
│    External APIs                    │
│  ├─ Blynk Cloud (hardware status)   │
│  ├─ Google Gemini 2.5 Flash (AI)    │
│  └─ Web Speech API (transcription)  │
└─────────────────────────────────────┘
```

---

## 📞 Support Resources

- **Flutter Issues**: Visit the error location mentioned in console
- **Blynk Help**: https://support.blynk.io/
- **Google AI**: https://support.google.com/googleai
- **Project Docs**: See `IMPLEMENTATION_GUIDE.md`
- **Detailed Troubleshooting**: See `TROUBLESHOOTING.md`

---

**Last Updated**: 2024
**Version**: 1.0.0
**Status**: ✅ Ready for Testing

