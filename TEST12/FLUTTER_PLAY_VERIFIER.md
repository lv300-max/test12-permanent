## Flutter Play Store Verification Integration

### New state in `Try12Machine`
- Add `PlayCheckStatus playStoreCheckStatus = PlayCheckStatus.pending;`
- Provide metadata such as `String? playStoreAppTitle; String? playStoreStatus;`
- Update the state when the gate submission validates:
  ```dart
  Future<void> verifyPlayStore(String packageName, String submissionId) async {
    playStoreCheckStatus = PlayCheckStatus.inFlight;
    notifyListeners();
    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/verify-app'),
      headers: {'Authorization': 'Bearer $clientToken'},
      body: jsonEncode({'packageName': packageName, 'submissionId': submissionId}),
    );
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      playStoreCheckStatus = payload['verified'] == true
          ? PlayCheckStatus.verified
          : PlayCheckStatus.failed;
      playStoreAppTitle = payload['title'] as String?;
      playStoreStatus = payload['status'] as String?;
    } else {
      playStoreCheckStatus = PlayCheckStatus.failed;
    }
    notifyListeners();
  }
  ```

### Trigger point
Call `verifyPlayStore` from the gate flow once `_allFieldsValid` is true and right before `_runSubmissionScan()` so the terminal knows whether the Play Store record is real before enabling fast track. Provide the `packageName` by parsing the submitted store link (`Uri.parse(...).queryParameters['id'] ?? last path segment`).

### UI feedback
- Add a badge in the Watchtower tab showing `playStoreCheckStatus` (Pending / Verified / Failed).
- Only mark `fastTrackReady` true when `playStoreCheckStatus == PlayCheckStatus.verified`.
- Add terminal log entries such as `"TERMINAL > GOOGLE PLAY VERIFICATION QUEUED"` and `"TERMINAL > GOOGLE PLAY VERIFIED"` so testers track the step.
- Provide a Retry button (`play store verification tab`) that reruns the HTTP call if the first attempt fails.

### Notes
- Use `package:http` (or `dio`) with a short timeout and handle offline/dns errors by setting `PlayCheckStatus.networkError`.
- Remember to keep API tokens in secure storage (Keychain/Keystore) and refresh them via your backend.
