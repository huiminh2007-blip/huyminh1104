"""Run the production Swift auth response models against Firebase REST fixtures.

API reference: https://firebase.google.com/docs/reference/rest/auth
No real accounts, API keys or tokens are used.
"""
from pathlib import Path
import subprocess
import tempfile
import sys

source = Path("ThreeOneOSFive/helpers/FirebaseKeyService.swift").read_text(encoding="utf-8")
models = source[source.index("private struct AnonymousAuthResponse:"):source.index("private struct FirestoreDocument:")]
checks = r'''
let decoder = JSONDecoder()
let signup = Data(#"{"idToken":"signup-id","localId":"same-device-uid","refreshToken":"signup-refresh","expiresIn":"3600"}"#.utf8)
private let first = try decoder.decode(AnonymousAuthResponse.self, from: signup)
guard first.idToken == "signup-id", first.localId == "same-device-uid", first.refreshToken == "signup-refresh" else { fatalError("Anonymous sign-in response mismatch") }
let refresh = Data(#"{"id_token":"renewed-id","user_id":"same-device-uid","refresh_token":"rotated-refresh","expires_in":"3600","token_type":"Bearer","project_id":"test-project"}"#.utf8)
private let renewed = try decoder.decode(RefreshAuthResponse.self, from: refresh)
guard renewed.idToken == "renewed-id", renewed.userId == first.localId, renewed.refreshToken == "rotated-refresh" else { fatalError("Refresh response lost credentials or changed device identity") }
let serverError = Data(#"{"error":{"code":400,"message":"INVALID_REFRESH_TOKEN"}}"#.utf8)
do { _ = try decoder.decode(RefreshAuthResponse.self, from: serverError); fatalError("Error response accepted as authenticated session") } catch is DecodingError { }
let incomplete = Data(#"{"id_token":"renewed-id","refresh_token":"rotated-refresh"}"#.utf8)
do { _ = try decoder.decode(RefreshAuthResponse.self, from: incomplete); fatalError("Missing UID accepted") } catch is DecodingError { }
let token = "refresh+/=&?#% value"
let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
let encoded = token.addingPercentEncoding(withAllowedCharacters: safe)!
guard encoded == "refresh%2B%2F%3D%26%3F%23%25%20value" else { fatalError("Form token encoding corrupts reserved characters") }
print("PASS: Firebase signup, refresh, UID preservation, rejected error/missing UID and reserved token characters")
'''

with tempfile.TemporaryDirectory(prefix="firebase-auth-check-") as temp:
    test_file = Path(temp) / "AuthResponseChecks.swift"
    test_file.write_text("import Foundation\n" + models + checks, encoding="utf-8")
    run = subprocess.run(["swift", str(test_file)], check=False)
    sys.exit(run.returncode)
