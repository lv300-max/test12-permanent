## Play Store Verification Service

### Goal
Provide a secure backend that checks whether a submitted app exists in Google Play before allowing Fast Track access.

### Flow
1. Register a Google Cloud project, enable the **Google Play Developer API**, and create a **service account**.
2. Grant the service account access to your Play Console (e.g., reader role for the desired app).
3. Store the service-account JSON on the backend; never ship it in the mobile client.

### Endpoint
`POST /api/verify-app`

**Request**
```json
{
  "packageName": "com.example.app",
  "submissionId": "T12-123456789"
}
```

**Response**
```json
{
  "verified": true,
  "title": "Mock App",
  "status": "published",
  "publishingStatus": "completed",
  "notes": "Play Store record confirmed",
  "timestamp": "2024-08-15T12:34:56Z"
}
```

### Implementation outline
1. Authenticate using JWT:
   * Build a JWT with the play publisher scope (`https://www.googleapis.com/auth/androidpublisher`), sign with the service-account private key.
   * Exchange it for an access token at `https://oauth2.googleapis.com/token`.
2. Call the Play Developer API:
   * Example: `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/edits?access_token=...`
   * Validate the response (package exists, belongs to your publisher) and extract metadata (`title`, `packageName`, publishing status).
3. Store/log the verification result (submission ID, package, outcome) for analytics/compliance.
4. Return the structured response to the mobile client.

### Security
- Require your Flutter client to send an API key or JWT to this backend (`Authorization: Bearer <token>`).
- Rate-limit/whitelist calls (only from your known tester networks or via authenticated app).
- Log every verification attempt with timestamps and submission identifiers.

### Analytics & Legal hints
- Keep a dataset of request timestamps, package names, and verification status for audits.
- Provide the legal team with a summary of when/why you call the Google API and how you store the credentials (encrypted storage, limited access).
