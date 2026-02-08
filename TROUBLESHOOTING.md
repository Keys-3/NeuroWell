# NeuroWell - Troubleshooting Guide

## Error: "The method 'forceFetchStatus' isn't defined for the type 'BiosensorService'"

**Status**: ✅ **FIXED**

**What was wrong**: The `live_view.dart` file was calling `_service.forceFetchStatus()` on line 166, but this method didn't exist in the `BiosensorService` class. The method existed in `BlynkService` but wasn't exposed.

**Solution Applied**:
Added the following method to `BiosensorService` (lib/data/services/biosensor_service.dart):

```dart
/// Force an immediate status check (bypass timer)
Future<void> forceFetchStatus() async {
  await _blynkService.forceFetchStatus();
}
```

**How it works**:
1. The method delegates to the underlying `_blynkService` instance
2. It bypasses the normal 3-second polling interval
3. Used during rapid retry when trying to reconnect to offline hardware
4. Called every 500ms until connection is restored or 40 seconds pass

**Verification**:
- [ ] Run `flutter pub get` to ensure dependencies are up to date
- [ ] Run `flutter analyze` to check for other issues
- [ ] Run `flutter run -t lib/main.dart` to test on your device/emulator

---

## Common Issues & Solutions

### Issue: App shows "STREAM OFFLINE" constantly

**Possible Causes**:
1. Blynk authentication token missing or incorrect
2. Network connectivity issues
3. Blynk cloud API is down
4. CORS issues on web version

**Solutions**:
1. **Check .env file**:
   ```bash
   # Verify BLYNK_AUTH_TOKEN is set correctly
   cat .env
   ```

2. **Reload environment variables**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check network connectivity**:
   - Ensure device has internet connection
   - Check firewall/proxy settings

4. **For Web CORS issues**:
   - The BlynkService uses CORS proxy: `https://corsproxy.io/`
   - This may be rate limited; check logs for "CORS" errors

5. **Debug logs**:
   - Check console output for `[BlynkService]` messages
   - Look for error details in the offline banner

---

### Issue: Sensor data shows as 0 when D0/D1 are supposed to be ON

**Possible Causes**:
1. D0/D1 pins are actually OFF on the Blynk device
2. Simulation isn't starting
3. Data generation is disabled

**Solutions**:
1. **Check Blynk cloud dashboard**:
   - Ensure D0 or D1 toggle switches are ON
   - Verify hardware is connected in Blynk

2. **Verify simulator is running**:
   - Session must be active (not showing "Live Monitoring Stopped")
   - Check that `_service.startSimulation()` was called

3. **Check data stream**:
   - Look at console logs for `[BiosensorService]` messages
   - Should see "Status changed" messages

---

### Issue: Transcription not working (no REC badge)

**Possible Causes**:
1. Microphone permission denied
2. Speech-to-text service not initialized
3. Browser doesn't support Web Speech API

**Solutions**:
1. **Grant microphone permissions**:
   - On mobile: Go to Settings → Apps → NeuroWell → Permissions → Grant Microphone
   - On web: Browser will ask on first use, click "Allow"

2. **Check transcription service initialization**:
   ```dart
   // In live_view.dart, startListening should be called when session starts
   await _transcriptionService.startListening();
   ```

3. **For web browsers**:
   - Chrome/Edge: Supported (native Web Speech API)
   - Firefox: Supported with plugin
   - Safari: Limited support

4. **Debug**:
   - Check console for `[TranscriptionService]` messages
   - Look for "Listening started" message

---

### Issue: Stress score shows "10.0" for normal data

**Causes**: Incorrect stress calculation

**Verification Steps**:
1. With normal D0 mode (HR 60-100, SpO2 95-100):
   - HR=75, SpO2=98 → Score should be ~2.5
   - HR=85, SpO2=97 → Score should be ~3.5

2. With stress D1 mode (HR 100-140, SpO2 88-94):
   - HR=120, SpO2=92 → Score should be ~7.5
   - HR=140, SpO2=88 → Score should be ~10.0

**If calculation is wrong**:
1. Check stress calculation in `_stressScoreCard()` (line 624-649 in live_view.dart)
2. Verify data model's `isStressed` property: `heartRate > 100 || spo2 < 95`
3. Check min/max ranges in `_generateAndEmitData()` (lines 101-110 in biosensor_service.dart)

---

### Issue: Session data not being collected (timeline empty)

**Causes**:
1. Data stream has null values
2. Timer/subscription not active
3. Session ends before data collection

**Solutions**:
1. **Check data stream**:
   ```dart
   // Verify data is being emitted
   _service.dataStream.listen((data) {
     print('[v0] Data received: ${data?.heartRate}');
   });
   ```

2. **Check subscription**:
   - `_dataSubscription` should be active when session is running
   - Check that it's not cancelled prematurely

3. **Verify session is active**:
   - Check `_isSessionActive` flag
   - Session must not end before timeline is complete

4. **Check log messages**:
   - Look for session start/end messages
   - Should see data collection messages

---

### Issue: Gemini report fails to generate

**Possible Causes**:
1. GEMINI_API_KEY missing or invalid
2. No internet connection
3. Gemini API quota exceeded
4. Invalid prompt or data format

**Solutions**:
1. **Check API key**:
   ```bash
   # Verify in .env file
   grep GEMINI_API_KEY .env
   ```

2. **Check internet connection**:
   - Ensure device/emulator has internet
   - Check firewall allows Google API calls

3. **Check API quota**:
   - Visit Google AI Studio: https://makersuite.google.com/app/apikey
   - Verify API is enabled and has available quota

4. **Check error message**:
   - Look at session summary dialog for error details
   - Check console for `[GeminiService]` error messages

5. **Test with simpler request**:
   ```dart
   // In Flutter, test Gemini directly
   final service = GeminiService();
   final result = await service.generateInsight("Test prompt");
   print(result);
   ```

---

### Issue: Connection keeps retrying forever

**Causes**: 
1. Hardware is truly offline and won't come back
2. Retry logic not stopping properly

**Solutions**:
1. **Manually check hardware**:
   - Verify ESP32 is powered on
   - Check Blynk cloud dashboard for device status
   - Look at Blynk debug logs for connection errors

2. **Force stop retry**:
   - Click "END SESSION" button to stop all timers
   - Retry will stop within 500ms

3. **Check retry timeout**:
   - Retry continues for ~40 seconds max
   - Then stops even if not connected
   - Session can continue with offline state

---

### Issue: Chart/UI not updating in real-time

**Causes**:
1. StreamBuilder not rebuilding
2. Data not flowing through stream
3. Performance issue (frame drops)

**Solutions**:
1. **Check StreamBuilder**:
   - Ensure `initialData` is set
   - Verify `builder` is being called
   - Add debug prints in builder

2. **Verify data stream**:
   ```dart
   // Add debug listener
   _service.dataStream.listen((data) {
     print('[v0] Stream emitted: $data');
   });
   ```

3. **Check setState/Provider**:
   - UI should use StreamBuilder, not setState
   - Data should flow through streams, not variables

4. **Performance**:
   - Reduce chart update frequency if stuttering
   - Profile with Flutter DevTools

---

### Issue: Permission errors on mobile

**Causes**:
1. Permissions not requested
2. User denied permissions
3. Platform-specific permission issues

**Solutions**:
1. **For microphone (Android)**:
   ```
   Settings → Apps → NeuroWell → Permissions → Microphone → Allow
   ```

2. **For microphone (iOS)**:
   ```
   Settings → NeuroWell → Microphone → Allow
   ```

3. **In code, verify permissions**:
   - `permission_handler` package handles this
   - Should automatically prompt on first use

4. **Reset permissions**:
   ```bash
   # Android
   adb shell pm reset-permissions
   
   # iOS (via Xcode)
   Reset simulator or device
   ```

---

## Debug Logging

### Enable Full Debug Logs

Add these to `live_view.dart`:

```dart
void initState() {
  super.initState();
  print('[v0] LiveView initState');
  
  // Log status changes
  _service.statusStream.listen((status) {
    print('[v0] Status changed to: $status');
  });
  
  // Log data changes
  _service.dataStream.listen((data) {
    print('[v0] Data: HR=${data?.heartRate}, SpO2=${data?.spo2}');
  });
}
```

### Check Console Output

While running:
```bash
flutter run
```

Look for lines starting with:
- `[LiveView]` - UI layer events
- `[BiosensorService]` - Data generation
- `[BlynkService]` - Connection status
- `[TranscriptionService]` - Speech recognition
- `[GeminiService]` - AI analysis

---

## Getting Help

### Where to Check Logs
1. **Flutter console**: Run `flutter run` and watch output
2. **Android Studio**: Logcat tab → search "[v0]" or service names
3. **Xcode**: Console tab (iOS)
4. **Browser DevTools**: Console tab (Web)

### Report an Issue with Details
Include:
1. Error message (exact text)
2. Steps to reproduce
3. Console logs
4. Device info (OS, version)
5. .env configuration (API keys masked)
6. Network status

### API Documentation
- Blynk: https://docs.blynk.io/
- Gemini: https://ai.google.dev/
- Flutter: https://flutter.dev/docs
- Speech-to-Text: https://pub.dev/packages/speech_to_text

