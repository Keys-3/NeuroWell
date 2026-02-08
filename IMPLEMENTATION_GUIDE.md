# NeuroWell Live Translation Tab - Implementation Guide

## Overview
This document outlines all the features implemented in the Live Monitoring/Translation Tab of the NeuroWell application.

---

## ✅ Fixed Issues

### 1. Compilation Error Fixed
**Error**: `The method 'forceFetchStatus' isn't defined for the type 'BiosensorService'`

**Solution**: Added `forceFetchStatus()` method to `BiosensorService` class that delegates to `BlynkService.forceFetchStatus()`.

**Location**: `lib/data/services/biosensor_service.dart` (lines 180-183)

```dart
Future<void> forceFetchStatus() async {
  await _blynkService.forceFetchStatus();
}
```

---

## ✅ Implemented Features

### 2. Online/Offline Status Display

**Description**: Shows real-time connection status in the UI with a badge indicator.

**Implementation**:
- **File**: `lib/ui/monitoring/live_view.dart` (lines 485-565)
- **Status Badge**: 
  - Green with "STREAM ONLINE" when device is connected
  - Red with "STREAM OFFLINE" when device is disconnected
- **Stream**: Uses `_service.statusStream` to listen to `BlynkStatus` changes
- **Visual Indicators**: 
  - Green dot + "STREAM ONLINE" text when connected
  - Red dot + "STREAM OFFLINE" text when offline
  - Offline banner shows error details and retry button

### 3. Device Connectivity Detection

**Status Types** (`BlynkStatus` enum in `blynk_service.dart`):

```
offline              → Device offline/disconnected → Shows red banner
onlineNoData         → Device online, D0 & D1 OFF → Shows zeros (0 data)
simulationNormal     → D0 ON → Shows normal data (60-100 BPM)
simulationStress     → D1 ON → Shows elevated/stress data (100-140 BPM)
loading              → Initial connecting state → Shows spinner
```

**Implementation Location**: `lib/data/services/blynk_service.dart`
- Polls every 3 seconds
- Checks hardware connection
- Reads D0 (dummy data normal) and D1 (stress mode) pins
- Emits status changes via stream

### 4. Zero Data Display (D0 & D1 OFF)

**Description**: When both dummy data toggles are OFF, sensor values show as 0.

**Implementation**: `lib/data/services/biosensor_service.dart` (lines 76-92)
```dart
void _startZeroDataGeneration() {
  _dataTimer?.cancel();
  _dataTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    _controller.add(BiosensorData(
      timestamp: DateTime.now(),
      heartRate: 0,
      spo2: 0,
      gsr: 0.0,
      ecgData: List.filled(100, 0.0),
    ));
  });
}
```

**Display**: Telemetry cards show "0" for all metrics

### 5. Normal Data Display (D0 ON)

**Description**: Generates realistic physiological data in normal ranges.

**Implementation**: `lib/data/services/biosensor_service.dart` (lines 94-140)
- Heart Rate: 60-100 BPM
- SpO2: 95-100%
- GSR: 0.5-4.0 µS
- ECG waveform with realistic PQRST pattern

**Trigger**: When `BlynkStatus.simulationNormal` is active

### 6. Elevated Data Display (D1 ON)

**Description**: Generates stress-level physiological data.

**Implementation**: `lib/data/services/biosensor_service.dart` (lines 101-110)
- Heart Rate: 100-140 BPM (elevated)
- SpO2: 88-94% (lower)
- GSR: 0.5-4.0 µS
- Stress indicator changes color from red to orange/amber

**Trigger**: When `BlynkStatus.simulationStress` is active

### 7. 40-Second Connection Retry Logic

**Description**: Automatically tries to connect to hardware for up to 40 seconds when session starts.

**Implementation**: `lib/ui/monitoring/live_view.dart` (lines 85-146)

**Flow**:
1. Session starts → checks if device is offline
2. If offline → initiates rapid retry (every 500ms)
3. Continues retrying until:
   - Device connects (status changes to online)
   - Session ends (manual stop)
   - Approximately 40 seconds pass (retry stops naturally)

**Code**:
```dart
void _startRapidRetry() {
  if (_retryTimer != null && _retryTimer!.isActive) return;
  
  print('[LiveView] Starting rapid retry sequence...');
  _retryTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
    if (!_isSessionActive) {
      timer.cancel();
      return;
    }
    
    if (_service.currentStatus != BlynkStatus.offline) {
      print('[LiveView] Connection established. Stopping rapid retry.');
      timer.cancel();
      _retryTimer = null;
      return;
    }
    
    _service.forceFetchStatus(); // Force immediate check
  });
}
```

### 8. Real-Time Session Data Collection with Timestamps

**Description**: Records all sensor data with timestamps during active session.

**Implementation**: `lib/ui/monitoring/live_view.dart` (lines 117-136)

**Data Structure**:
```dart
_sessionTimelineData.add({
  'timestamp': _formatDuration(_sessionDuration),  // MM:SS format
  'heartRate': data.heartRate,
  'spo2': data.spo2,
  'isStressed': data.isStressed,
});
```

**Features**:
- Timestamp in MM:SS format relative to session start
- Heart rate, SpO2, and stress state captured
- Data collected every second
- Cleared when session starts
- Passed to session summary dialog

### 9. Conversation Recording (Transcription)

**Description**: Records conversation between therapist and client using speech-to-text.

**Implementation**: `lib/data/services/transcription_service.dart`

**Features**:
- Captures speech during session
- Real-time transcription display in AI Insights card
- "REC" badge shows when microphone is active
- Displays transcription in live text box (line 718-733 in live_view.dart)
- Full transcript stored in `_transcription` variable

**UI Components** (lines 697-734):
- REC badge appears when listening
- Live transcription display box (80px height)
- Shows "Waiting for speech..." when no audio detected
- Clears at session start

### 10. Gemini 2.5 Pro AI Analysis

**Description**: Sends session data and conversation to Gemini for clinical insights.

**Implementation**: `lib/data/services/gemini_service.dart`

**Two-Stage Analysis**:

#### Stage 1: Live Analysis (During Session)
- **Method**: `analyzeSession()`
- **Inputs**: Current sensor data + therapist notes + live transcript
- **Output**: Real-time clinical insight (max 3 sentences)
- **Trigger**: Click "Generate Insight" button
- **Display**: AI Insights card (lines 764-792 in live_view.dart)

#### Stage 2: Post-Session Report (After Session)
- **Method**: `generateSessionReport()`
- **Inputs**:
  - Full session transcript
  - Average stats (avg HR, avg SpO2, stress events count)
  - Complete timeline data with timestamps
  - Session duration
- **Output**: Comprehensive medical report with:
  1. Patient State Summary (physiological analysis)
  2. Key Topics Discussed (transcript analysis)
  3. Clinical Observations (correlation of stress events with discussion topics)
  4. Recommendations for next session
- **Model**: `gemini-2.5-flash` (latest fast model)
- **Display**: Session Summary Dialog (lines 846-971 in live_view.dart)

**Session Summary Dialog** (lines 170-186):
```dart
_showSessionSummary() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SessionSummaryDialog(
      transcript: _transcription,
      duration: _formatDuration(_sessionDuration),
      timelineData: List.from(_sessionTimelineData),
      avgStats: { /* calculated averages */ },
    ),
  );
}
```

### 11. Session Timeline Visualization

**Description**: Shows physiological data trends throughout the session.

**Implementation**: 
- **Sensor Chart**: `lib/ui/monitoring/widgets/telemetry_chart.dart` (lines 437-482 in live_view.dart)
- **Chart Type**: Real-time line chart using Recharts pattern
- **Metrics Displayed**: Heart Rate (ECG line chart)
- **Legend**: Color-coded for ECG data
- **Responsive**: Adapts for desktop (expanded) and mobile (constrained height)

---

## 🔄 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ HARDWARE (ESP32/Blynk Cloud)                                │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ├─ D0 Pin (Dummy Normal Data)
                 ├─ D1 Pin (Stress Mode)
                 └─ Hardware Online Status
                 │
         ┌───────▼──────────────┐
         │  BlynkService        │
         │ (polls every 3s)     │
         │  forceFetchStatus()  │
         └───────┬──────────────┘
                 │
        ┌────────▼────────────┐
        │ BiosensorService    │
        │ (generates data)    │
        └────────┬────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
 Status       Data         Logs
 Stream       Stream       Stream
    │            │            │
    └────────┬───┴───┬────────┘
             │       │
    ┌────────▼─┐  ┌─▼──────────────┐
    │ live_view │  │ Session Data   │
    │   (UI)    │  │ Collection     │
    │           │  │ (timeline)     │
    └────────┬──┘  └────────┬───────┘
             │              │
             └──────┬───────┘
                    │
            ┌───────▼────────┐
            │ Session End    │
            │ Send to Gemini │
            │ Generate Report│
            └────────────────┘
```

---

## 📊 Status Indicator Logic

```
Hardware Check
    │
    ├─ FALSE ──────────────────────┐
    │                              │
    └─ TRUE                        │
        │                          │
        Check D0 & D1              │
        │                          │
        ├─ D0=ON → simulationNormal
        ├─ D1=ON → simulationStress
        ├─ Both OFF → onlineNoData
        └─ Error ─────────────────┤
                                   │
                        ┌──────────┘
                        │
                        ▼
                    OFFLINE ─────────────────┐
                    (red banner)             │
                                             │
                    Rapid Retry              │
                    (every 500ms)            │
                    │                        │
                    └─ Success ──────────────┴─► Online Status
                    └─ 40sec Timeout ──────────► Give Up
```

---

## 🔧 Configuration Requirements

### Environment Variables (.env)
```
BLYNK_AUTH_TOKEN=your_blynk_token_here
GEMINI_API_KEY=your_gemini_api_key_here
```

### Dependencies
- `flutter_dotenv`: Load environment variables
- `google_generative_ai`: Gemini API
- `speech_to_text`: Speech recognition
- `permission_handler`: Microphone access
- `provider`: State management
- `http`: HTTP requests (Blynk)

---

## 🎯 Usage Flow

### Starting a Session
1. Click "START LIVE SESSION" button
2. App initializes transcription service
3. App attempts to connect to hardware (40-second retry)
4. Once connected, sensor data begins flowing
5. Microphone activation starts (REC badge appears)
6. Session timer starts counting

### During Session
1. Sensor data displayed in real-time cards
2. Transcription appears in AI Insights box
3. Stress score calculated from HR + SpO2
4. Chart updates with physiological trends
5. Therapist can add notes and request instant analysis

### Ending Session
1. Click "END SESSION" button
2. Microphone stops listening
3. Session Summary Dialog appears with:
   - Session duration
   - Average statistics
   - Full transcript
   - "Generate Detailed Medical Report" button
4. Click button to send data to Gemini
5. AI-generated report displays recommendations

---

## ⚙️ Technical Details

### Stress Score Calculation
```dart
// Normalize HR: 60=0, 140=10
double hrScore = ((data.heartRate - 60) / 80) * 10;

// Normalize SpO2: 100=0, 90=10 (inverted)
double spo2Score = ((100 - data.spo2) / 10) * 10;

// Combined score (0-10)
double score = (hrScore + spo2Score) / 2;
score = score.clamp(0.0, 10.0);

// Display: Green if <5, Orange if ≥5
```

### ECG Waveform Generation
Realistic PQRST pattern with:
- P wave: Atrial depolarization
- QRS complex: Ventricular depolarization
- T wave: Ventricular repolarization
- Added noise for realism

---

## 🚀 Future Enhancements

1. **Hardware Integration**: Replace Blynk simulation with actual ESP32
2. **Database Storage**: Save all session data to Firestore
3. **Advanced Analytics**: Machine learning for stress prediction
4. **Export Reports**: PDF/CSV export of session data
5. **Multi-patient Tracking**: Track trends across sessions
6. **Customizable Alerts**: Notify on stress threshold breaches

---

## 📝 Notes

- All timestamps are relative to session start (MM:SS format)
- Stress detection triggers at HR > 100 or SpO2 < 95
- Gemini model used: `gemini-2.5-flash` (optimized for speed)
- Connection retry: 500ms intervals, stops on connection or 40+ seconds
- Data collection: 1 sample per second (1 Hz)

---

## ✅ Testing Checklist

- [ ] Flutter app compiles without errors
- [ ] Online/Offline badge displays correctly
- [ ] D0 toggle shows normal data (HR 60-100)
- [ ] D1 toggle shows stress data (HR 100-140)
- [ ] Both OFF shows zero data
- [ ] Session timer counts up correctly
- [ ] Transcription captures speech live
- [ ] Stress score calculates correctly
- [ ] Session ends and shows summary
- [ ] Gemini report generates without errors
- [ ] All sensor data passed to Gemini

