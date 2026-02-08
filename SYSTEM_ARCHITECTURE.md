# NeuroWell System Architecture

## High-Level System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                      USER INTERFACE LAYER                        │
│                   lib/ui/monitoring/live_view.dart               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              LIVE MONITORING VIEW                       │   │
│  │                                                         │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │   │
│  │  │ Status Badge │  │ Telemetry    │  │ Stress Score │ │   │
│  │  │ Online/      │  │ Cards        │  │ 0-10         │ │   │
│  │  │ Offline      │  │ HR/SpO2/GSR  │  │             │ │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │   │
│  │                                                         │   │
│  │  ┌──────────────────────────────────────────────────┐ │   │
│  │  │         SESSION TIMER & CONTROLS                 │ │   │
│  │  │    START SESSION    │    END SESSION             │ │   │
│  │  │    Timer: MM:SS     │    (Shows Summary Dialog)  │ │   │
│  │  └──────────────────────────────────────────────────┘ │   │
│  │                                                         │   │
│  │  ┌──────────────────────────────────────────────────┐ │   │
│  │  │         ECG/PHYSIOLOGICAL CHART                  │ │   │
│  │  │    Real-time waveform visualization              │ │   │
│  │  └──────────────────────────────────────────────────┘ │   │
│  │                                                         │   │
│  │  ┌──────────────────────────────────────────────────┐ │   │
│  │  │    AI INSIGHTS CARD                              │ │   │
│  │  │  ┌────────────────────────────────────────────┐ │ │   │
│  │  │  │ REC Badge    Live Transcription            │ │ │   │
│  │  │  │ (when recording)                           │ │ │   │
│  │  │  ├────────────────────────────────────────────┤ │ │   │
│  │  │  │ Clinical Notes Input                       │ │ │   │
│  │  │  ├────────────────────────────────────────────┤ │ │   │
│  │  │  │ [Generate Insight]  [Processing...]        │ │ │   │
│  │  │  ├────────────────────────────────────────────┤ │ │   │
│  │  │  │ AI Analysis Output                         │ │ │   │
│  │  │  │ (Stress interpretation, observations)      │ │ │   │
│  │  │  └────────────────────────────────────────────┘ │ │   │
│  │  └──────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                      │
│                          │ Uses StreamBuilder to listen to     │
│                          │ data/status changes                 │
│                          ▼                                      │
└──────────────────────────────────────────────────────────────────┘

        │
        │ StreamBuilder<BiosensorData>
        │ StreamBuilder<BlynkStatus>
        │
        ▼

┌──────────────────────────────────────────────────────────────────┐
│                    SERVICE LAYER (BACKENDS)                      │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           BIOSENSOR SERVICE                               │ │
│  │    lib/data/services/biosensor_service.dart               │ │
│  │                                                            │ │
│  │  • Manages sensor data generation                         │ │
│  │  • Adapts data based on device status                    │ │
│  │  • Generates realistic physiological patterns            │ │
│  │  • Emits data stream (1 sample/second)                   │ │
│  │  • ✅ FIXED: Now has forceFetchStatus()                  │ │
│  │                                                            │ │
│  │  Exposes:                                                 │ │
│  │  • dataStream → BiosensorData? (HR, SpO2, GSR, ECG)      │ │
│  │  • statusStream → BlynkStatus                            │ │
│  │  • currentStatus: BlynkStatus                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                          │                                       │
│                          │ Wraps & Delegates                    │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │         BLYNK SERVICE (Singleton)                         │ │
│  │    lib/data/services/blynk_service.dart                   │ │
│  │                                                            │ │
│  │  • Polls hardware status every 3 seconds                  │ │
│  │  • Checks if ESP32 is online                             │ │
│  │  • Reads Blynk pins: D0 (normal) D1 (stress)            │ │
│  │  • Updates BlynkStatus enum                              │ │
│  │  • Handles HTTP requests to Blynk cloud                  │ │
│  │  • Logs connection attempts                              │ │
│  │  • forceFetchStatus(): Immediate check bypass            │ │
│  │                                                            │ │
│  │  Status States:                                          │ │
│  │  • offline → Hardware unreachable                        │ │
│  │  • loading → Initial connection attempt                 │ │
│  │  • onlineNoData → D0=OFF, D1=OFF → Show 0 values        │ │
│  │  • simulationNormal → D0=ON → HR 60-100, SpO2 95-100   │ │
│  │  • simulationStress → D1=ON → HR 100-140, SpO2 88-94   │ │
│  │                                                            │ │
│  │  Exposes:                                                 │ │
│  │  • statusStream → BlynkStatus                            │ │
│  │  • logStream → String (debug messages)                   │ │
│  │  • currentStatus: BlynkStatus                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                          │                                       │
│                          │ HTTP Requests                        │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │      TRANSCRIPTION SERVICE                               │ │
│  │  lib/data/services/transcription_service.dart            │ │
│  │                                                            │ │
│  │  • Initializes speech-to-text on app load               │ │
│  │  • Starts listening when session begins                 │ │
│  │  • Captures live microphone input                       │ │
│  │  • Converts speech to text in real-time                │ │
│  │  • Emits transcription updates                          │ │
│  │  • Handles permission requests                          │ │
│  │  • Stops on session end                                 │ │
│  │                                                            │ │
│  │  Exposes:                                                 │ │
│  │  • transcriptionStream → String (live transcript)        │ │
│  │  • listeningStateStream → bool (recording status)        │ │
│  │  • errorStream → String (microphone errors)             │ │
│  │  • isListening: bool                                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                          │                                       │
│                          │ Uses Web Speech API or native STT    │
│                          │                                       │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │       GEMINI SERVICE                                      │ │
│  │  lib/data/services/gemini_service.dart                   │ │
│  │                                                            │ │
│  │  • Provides AI analysis during and after sessions        │ │
│  │  • Model: gemini-2.5-flash (latest fast model)          │ │
│  │                                                            │ │
│  │  Methods:                                                 │ │
│  │  1. analyzeSession()                                      │ │
│  │     • Takes: Current sensor data + notes + transcript   │ │
│  │     • Returns: 3-sentence clinical insight              │ │
│  │     • Used: During session (on demand)                  │ │
│  │                                                            │ │
│  │  2. generateSessionReport()                               │ │
│  │     • Takes: Full transcript + timeline data +          │ │
│  │              avg stats + duration                        │ │
│  │     • Returns: Comprehensive medical report with:        │ │
│  │       - Patient state summary                           │ │
│  │       - Key topics discussed                            │ │
│  │       - Clinical observations                           │ │
│  │       - Recommendations                                  │ │
│  │     • Used: Post-session analysis                       │ │
│  │                                                            │ │
│  │  Exposes:                                                 │ │
│  │  • generateInsight(String) → Future<String>             │ │
│  │  • analyzeSession(Map, String) → Future<String>         │ │
│  │  • generateSessionReport(...) → Future<String>          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                          │                                       │
│                          │ HTTP Requests to Google AI API       │
│                          ▼                                       │
└──────────────────────────────────────────────────────────────────┘

        │
        │
        ▼

┌──────────────────────────────────────────────────────────────────┐
│                   EXTERNAL SERVICES                              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  BLYNK CLOUD                                              │ │
│  │  https://blynk.cloud/external/api                         │ │
│  │                                                            │ │
│  │  • Device connection status endpoint                      │ │
│  │  • D0 pin state (Normal Data toggle)                     │ │
│  │  • D1 pin state (Stress Mode toggle)                     │ │
│  │  • Polled every 3 seconds (or on demand)                │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  GOOGLE GEMINI 2.5 FLASH                                 │ │
│  │  https://generativelanguage.googleapis.com                │ │
│  │                                                            │ │
│  │  • AI model for text generation                          │ │
│  │  • Analyzes physiological data + conversation           │ │
│  │  • Generates clinical insights                          │ │
│  │  • Creates post-session reports                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  WEB SPEECH API / NATIVE SPEECH RECOGNITION              │ │
│  │                                                            │ │
│  │  • Browser: Web Speech API (Chrome, Edge, Safari)       │ │
│  │  • Mobile: Native Speech-to-Text (Android, iOS)         │ │
│  │  • Real-time audio capture & transcription              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  FIREBASE (for auth & data storage)                      │ │
│  │  Initialized in main.dart                                │ │
│  │                                                            │ │
│  │  • User authentication                                   │ │
│  │  • Session data storage                                  │ │
│  │  • Patient records                                       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Session Life Cycle Flow

```
START ──────────────────────────────────────────────────────────────
  │
  ├─→ User clicks "START LIVE SESSION"
  │
  ├─→ Initialize:
  │   • _isSessionActive = true
  │   • _sessionDuration = 0
  │   • _sessionTimelineData.clear()
  │   • _transcription = ''
  │
  ├─→ Start Session Timer (1-second tick)
  │   └─ Updates UI with elapsed time (MM:SS)
  │
  ├─→ Start Transcription Service
  │   └─ Activate microphone (REC badge appears)
  │
  ├─→ Start Data Stream Subscription
  │   • Listen to _service.dataStream
  │   • Collect each sample with timestamp
  │   • Add to _sessionTimelineData
  │
  ├─→ Check Hardware Connection
  │   │
  │   ├─ ONLINE? → Continue
  │   │
  │   └─ OFFLINE? → Start Rapid Retry
  │       │
  │       └─ Every 500ms: forceFetchStatus()
  │           ├─ Continues for ~40 seconds
  │           ├─ Stops if device connects
  │           └─ User can manually RETRY button
  │
  │
  DURING SESSION (Active Monitoring)
  │
  ├─→ Every 1 Second:
  │   │
  │   ├─ Biosensor Data Generated
  │   │  ├─ Heart Rate (based on mode)
  │   │  ├─ SpO2 (based on mode)
  │   │  ├─ GSR (galvanic skin response)
  │   │  └─ ECG waveform
  │   │
  │   ├─ Data Display Updated
  │   │  ├─ Telemetry cards (HR, SpO2, GSR)
  │   │  ├─ Stress score calculated
  │   │  ├─ Chart updated
  │   │  └─ Color indicators updated
  │   │
  │   └─ Data Collected in Timeline
  │      └─ {timestamp, HR, SpO2, isStressed}
  │
  ├─→ Live Transcription Captured
  │   ├─ Microphone detects speech
  │   ├─ Converted to text in real-time
  │   └─ Displayed in AI Insights card
  │
  ├─→ [Optional] Generate Instant Insight
  │   ├─ User clicks "Generate Insight"
  │   ├─ Current sensor data + notes + transcript sent to Gemini
  │   ├─ AI analysis received in 2-5 seconds
  │   └─ Insight displayed in card
  │
  │
  END SESSION ────────────────────────────────────────────────────────
  │
  ├─→ User clicks "END SESSION"
  │
  ├─→ Stop Collection:
  │   • Cancel session timer
  │   • Cancel retry timer
  │   • Unsubscribe from data stream
  │   • Stop microphone (REC badge disappears)
  │   • Stop simulation
  │   └─ _isSessionActive = false
  │
  ├─→ Calculate Averages from Timeline:
  │   • Average Heart Rate
  │   • Average SpO2
  │   • Stress events count
  │
  ├─→ Show Session Summary Dialog
  │   ├─ Display:
  │   │  ├─ Duration
  │   │  ├─ Avg stats
  │   │  ├─ Full transcript
  │   │  └─ "Generate Detailed Medical Report" button
  │   │
  │   └─ User clicks "Generate Detailed Medical Report"
  │
  ├─→ Send to Gemini 2.5 Flash:
  │   • Full transcript
  │   • Timeline data (with MM:SS timestamps)
  │   • Average stats
  │   • Session duration
  │
  ├─→ Gemini Analyzes & Generates Report:
  │   ├─ Patient State Summary
  │   │  └─ Physiological data interpretation
  │   ├─ Key Topics Discussed
  │   │  └─ Transcript analysis
  │   ├─ Clinical Observations
  │   │  └─ Stress events correlated with discussion
  │   └─ Recommendations
  │      └─ Suggested next steps
  │
  ├─→ Display Report in Dialog
  │   └─ User can read and dismiss
  │
  └─→ END
```

---

## Data Flow During Live Session

```
REALTIME DATA FLOW (1 sample/second)
═════════════════════════════════════

Hardware (ESP32) or Blynk Cloud
         │
         │ D0 Pin (Normal Mode)
         │ D1 Pin (Stress Mode)
         │ Connection Status
         │
         ▼
BlynkService
  • Polling (every 3 seconds, or on demand with forceFetchStatus)
  • Reads pin states
  • Determines BlynkStatus
  • Emits status → statusStream
         │
         ├─ BlynkStatus.offline ──────┐
         │                             ▼
         ├─ BlynkStatus.loading        (Red: STREAM OFFLINE)
         │                             (Trigger: _startRapidRetry)
         ├─ BlynkStatus.onlineNoData ┐
         │                            ├─→ BiosensorService
         ├─ BlynkStatus.simulationNormal ─→ Generates data
         │                                  Zero values
         └─ BlynkStatus.simulationStress   Normal ranges
                                           Stress ranges
         │
         ▼
BiosensorService
  • Generates realistic data
  • Emits sample → dataStream
  • Properties:
    - timestamp: DateTime.now()
    - heartRate: int (60-100 or 100-140)
    - spo2: int (95-100 or 88-94)
    - gsr: double (0.5-4.0)
    - ecgData: List<double> (PQRST waveform)
    - isStressed: bool (HR > 100 || SpO2 < 95)
         │
         ▼
LiveMonitoringView (Multiple listeners)
  │
  ├─ UI Update:
  │  ├─ Telemetry Cards
  │  │  ├─ HR display: ${heartRate} BPM
  │  │  ├─ SpO2 display: ${spo2} %
  │  │  └─ GSR display: ${gsr.toStringAsFixed(1)} µS
  │  │
  │  ├─ Stress Score Calculation:
  │  │  ├─ hrScore = ((HR - 60) / 80) * 10
  │  │  ├─ spo2Score = ((100 - SpO2) / 10) * 10
  │  │  └─ score = (hrScore + spo2Score) / 2
  │  │
  │  ├─ Color Indicators:
  │  │  ├─ isStressed = false → Red heart (normal)
  │  │  └─ isStressed = true → Orange heart (stressed)
  │  │
  │  └─ Chart Update:
  │     └─ ECG waveform plotted
  │
  └─ Data Collection:
     └─ Timeline Data Entry:
        {
          'timestamp': 'MM:SS',
          'heartRate': 75,
          'spo2': 98,
          'isStressed': false
        }
        └─ Added to _sessionTimelineData list
           └─ Sent to Gemini on session end

TRANSCRIPTION PARALLEL FLOW
═════════════════════════════

Microphone
    │
    ├─ Speech Audio
    │
    ▼
TranscriptionService
  • Detects speech
  • Converts to text
  • Emits → transcriptionStream
    │
    ▼
LiveMonitoringView
  • Displays in AI Insights card
  • Live transcript box shows:
    "Hello, I'm feeling anxious today..."
  • Sent with sensor data to Gemini
    on session end
```

---

## Rapid Retry Algorithm

```
CONDITION: Device goes offline while session is running
═══════════════════════════════════════════════════════

Initial State:
  • _isSessionActive = true
  • _service.currentStatus = BlynkStatus.offline

Trigger: _startRapidRetry()
  ├─ if (_retryTimer != null && _retryTimer!.isActive) return;
  │   └─ Prevent multiple timers
  │
  └─ Timer.periodic(500ms):
      │
      ├─ Check: Is session still active?
      │  └─ if (!_isSessionActive) cancel timer and return
      │
      ├─ Check: Is device still offline?
      │  ├─ if (status != offline) → CONNECTED!
      │  │  ├─ Log: "Connection established"
      │  │  ├─ Cancel timer
      │  │  └─ _retryTimer = null
      │  │
      │  └─ if (status == offline) → Continue retrying
      │      └─ Call: _service.forceFetchStatus()
      │         └─ Immediately check hardware status
      │            └─ Bypass normal 3-second interval
      │
      └─ Repeat every 500ms
         │
         ├─ After 0.5s: 1st check
         ├─ After 1s: 2nd check
         ├─ After 1.5s: 3rd check
         ├─ After 2s: 4th check
         ├─ ...
         └─ After 40s: ~80 checks made
            ├─ Timeout naturally
            └─ User can manually click RETRY


FLOW DIAGRAM:
─────────────

Device Offline          → _startRapidRetry() begins
         │
         ├─ 500ms: forceFetchStatus() [Check 1]
         │
         ├─ 1s: forceFetchStatus() [Check 2]
         │
         ├─ 1.5s: forceFetchStatus() [Check 3]
         │
         ├─ [... continue every 500ms ...]
         │
         ├─ At some point:
         │  └─ Device reconnects
         │     └─ forceFetchStatus() detects online
         │        └─ Timer cancelled immediately
         │           └─ UI shows: STREAM ONLINE (green)
         │
         └─ OR timeout (~40s):
            └─ Timer naturally stops
               └─ User can:
                  ├─ Wait for device to reconnect (no auto-retry)
                  ├─ Click RETRY button (manual restart)
                  └─ End session


PSEUDOCODE:
───────────

void _startRapidRetry() {
  if (_retryTimer?.isActive == true) return;
  
  _retryTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
    // 1. Session ended?
    if (!_isSessionActive) {
      timer.cancel();
      return;
    }
    
    // 2. Device connected?
    if (_service.currentStatus != BlynkStatus.offline) {
      log('✅ Connected!');
      timer.cancel();
      _retryTimer = null;
      return;
    }
    
    // 3. Still offline → Try again
    log('🔄 Retrying... (attempt ${retryCount++})');
    _service.forceFetchStatus();
    
    // 4. Repeat in 500ms
  });
}


EXPECTED BEHAVIOR:
──────────────────

[0:00] User clicks "START SESSION"
[0:01] Hardware offline detected
[0:01] Rapid retry starts
[0:01] forceFetchStatus() called (attempt 1)
[0:01] Status: offline → continue
[0:02] forceFetchStatus() called (attempt 2)
[0:02] Status: offline → continue
[0:03] forceFetchStatus() called (attempt 3)
[0:03] Status: offline → continue
...
[0:20] Device reconnected!
[0:20] forceFetchStatus() called (attempt 40)
[0:20] Status: simulationNormal → STOP RETRY
[0:20] UI shows: ✅ STREAM ONLINE
[0:20] Data begins flowing again
```

---

## Data Model Structures

```
BiosensorData
──────────────
{
  timestamp: DateTime,        // When data was generated
  heartRate: int,             // 60-100 (normal) or 100-140 (stress)
  spo2: int,                  // 95-100 (normal) or 88-94 (stress)
  gsr: double,                // 0.5-4.0 µS (galvanic skin response)
  ecgData: List<double>,      // 100 points of PQRST waveform
  
  get isStressed: bool {
    return heartRate > 100 || spo2 < 95;
  }
}


Session Timeline Data (List)
──────────────────────────────
[
  {
    'timestamp': '00:01',     // MM:SS from session start
    'heartRate': 75,          // From BiosensorData
    'spo2': 98,               // From BiosensorData
    'isStressed': false,      // Derived from HR and SpO2
  },
  {
    'timestamp': '00:02',
    'heartRate': 76,
    'spo2': 98,
    'isStressed': false,
  },
  // ... more entries (1 per second)
]


BlynkStatus Enum
─────────────────
offline              // Cannot reach Blynk cloud
loading              // Initial connection attempt
onlineNoData         // D0=OFF, D1=OFF → All zeros
simulationNormal     // D0=ON → Normal ranges (60-100 BPM)
simulationStress     // D1=ON → Stress ranges (100-140 BPM)


Gemini Prompt Format
──────────────────────
{
  transcript: String,         // Full conversation text
  duration: String,           // "MM:SS" format
  avgStats: {
    'avgHr': String,          // "75"
    'avgSpo2': String,        // "98"
    'stressEvents': int,      // 5
  },
  timelineData: List<Map> {   // Full timeline with timestamps
    'timestamp': 'MM:SS',
    'heartRate': int,
    'spo2': int,
    'isStressed': bool,
  }
}
```

---

## Component Interaction Matrix

```
                │ live_view.dart │ biosensor_service │ blynk_service │ gemini_service │ transcription_service
────────────────┼────────────────┼───────────────────┼───────────────┼────────────────┼──────────────────────
  Calls         │ startSession() │ startSimulation() │ startPolling()│ analyzeSession│ startListening()
  (Methods)     │ endSession()   │ stopSimulation()  │ stopPolling() │ generateReport│ stopListening()
                │ _startRapidRe..│ forceFetchStatus()│ forceFetch... │ generateInsi..│ dispose()
                │ _toggleSession │ dispose()         │ dispose()     │ getApiKey()  │
────────────────┼────────────────┼───────────────────┼───────────────┼────────────────┼──────────────────────
  Listens to    │ dataStream     │ statusStream      │ logStream     │ (N/A)          │ transcriptionStream
  (Streams)     │ statusStream   │ logStream         │               │                │ listeningStateStream
                │ transcription  │ dataStream        │               │                │ errorStream
                │ currentStatus  │ currentStatus     │               │                │
────────────────┼────────────────┼───────────────────┼───────────────┼────────────────┼──────────────────────
  Reads         │ currentStatus  │ _blynkService     │ environment   │ apiKey from    │ microphone access
  (External)    │ microphone     │ lastError         │ vars          │ .env           │ speech-to-text API
                │ session data   │ _statusController │ Blynk cloud   │ Gemini API    │
────────────────┼────────────────┼───────────────────┼───────────────┼────────────────┼──────────────────────
  Passes to     │ Gemini service │ (None)            │ HTTP client   │ (None)         │ (None)
  (Dependencies)│ UI layers      │                   │               │                │
```

---

## Error Handling Flow

```
ERROR SCENARIOS
═══════════════

1. NETWORK ERROR (Hardware unreachable)
   ──────────────────────────────────
   BlynkService._fetchStatus()
     └─ Network timeout or 4xx/5xx response
        ├─ _consecutiveFailures++
        └─ if (_consecutiveFailures >= 2):
           └─ _updateStatus(BlynkStatus.offline)
              └─ UI shows: STREAM OFFLINE (red banner)
              └─ Triggers: _startRapidRetry()
              
   Recovery: Device comes back online
     ├─ forceFetchStatus() succeeds
     ├─ _consecutiveFailures reset to 0
     └─ Status changes to online


2. MICROPHONE PERMISSION DENIED
   ─────────────────────────────
   TranscriptionService.startListening()
     └─ Permission denied error
        ├─ _errorController.add('Microphone permission denied')
        └─ UI shows: SnackBar with error
           └─ REC badge doesn't appear
           
   Recovery: User grants permission
     ├─ Must restart session
     └─ Microphone access enabled


3. GEMINI API ERROR
   ────────────────
   GeminiService.generateSessionReport()
     └─ API error, invalid key, or quota exceeded
        ├─ Exception caught
        └─ Return: "Failed to generate insight: <error>"
           └─ UI shows: Error message in dialog
           
   Recovery: Check API key
     ├─ Verify GEMINI_API_KEY in .env
     ├─ Check Google AI Studio quota
     └─ Retry button works immediately


4. BLYNK API ERROR
   ───────────────
   BlynkService._isHardwareConnected()
     └─ HTTP timeout, CORS error, or invalid token
        ├─ Exception caught
        ├─ Return: false (treated as offline)
        └─ _lastError = "Exception checking hardware: <error>"
           └─ Debug info shown in offline banner
           
   Recovery: Check authentication
     ├─ Verify BLYNK_AUTH_TOKEN in .env
     ├─ Check Blynk cloud status
     └─ Retry button forces immediate check


5. STREAM ERROR (During data collection)
   ────────────────────────────────────
   _service.dataStream.listen() throws error
     ├─ Caught in error handler
     └─ Session continues
        └─ Data collection pauses
           └─ Timeline may have gaps
           
   Recovery: Check logs
     ├─ Look for [BiosensorService] errors
     └─ Restart session if data stops
```

---

## Performance Metrics

```
OPERATION TIMING
═════════════════

Blynk Status Poll:         3 seconds (normal interval)
Rapid Retry:               500 milliseconds
Data Generation:           1 second (1 Hz sampling)
UI Update:                 < 100ms (StreamBuilder rebuilds)
Transcription Latency:     1-2 seconds (cloud-based)
Gemini Analysis:           3-5 seconds (cloud API)
Gemini Report:             5-10 seconds (comprehensive)

RESOURCE USAGE
───────────────
Memory:
  • BiosensorData (single): ~1 KB
  • Timeline (100 samples):  ~100 KB
  • Full transcript:         ~10-50 KB
  • Total for 5-min session: ~300 KB

Network:
  • Blynk poll: ~1 KB per request
  • Gemini API: ~5-10 KB request, 10-50 KB response

Samples:
  • Data collection: 1 sample per second
  • For 60-minute session: 3,600 samples (360 KB)
```

---

**Last Updated**: 2024
**Version**: 1.0.0
**Status**: Complete Architecture Reference

