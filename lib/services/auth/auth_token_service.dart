import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Provides an authenticated HTTP client for use with googleapis packages.
/// Uses extension_google_sign_in_as_googleapis_auth to bridge GoogleSignIn
/// with the googleapis auth system. Tokens are refreshed automatically.
class AuthTokenService {
  AuthTokenService({required GoogleSignIn googleSignIn})
      : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;

  /// Returns an [http.Client] authenticated with the current Google user's
  /// OAuth token, suitable for passing to googleapis service clients.
  ///
  /// The returned client handles token refresh automatically.
  /// Call [client.close()] when done to free resources.
  Future<http.Client> getAuthenticatedHttpClient() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception(
        'Could not obtain authenticated client. User may not be signed in '
        'or Calendar scope may not have been granted.',
      );
    }
    return client;
  }

  /// Returns the current user's Google access token as a raw string.
  /// Prefer [getAuthenticatedHttpClient] for API calls.
  Future<String?> getAccessToken() async {
    final account = _googleSignIn.currentUser;
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }
}
