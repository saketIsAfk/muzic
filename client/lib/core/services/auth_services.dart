import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        log('❌ User canceled Google Sign-In');
        return null;
      }

      log('✅ Google account selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      log('✅ Google credentials obtained');

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      log('✅ Signed in to Firebase: ${userCredential.user?.email}');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      log('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        // This email already has a password-based account. We're not
        // auto-linking (see AuthService doc comment on
        // signInOrSignUpWithEmail) — just tell the user which box to use.
        throw FirebaseAuthException(
          code: e.code,
          message: "An account already exists with this email. Try continuing with email and password instead.",
        );
      }
      rethrow;
    } catch (e) {
      log('❌ Error signing in with Google: $e');
      rethrow;
    }
  }

  // One field, no separate "sign up" screen: tries to sign the user in, and
  // if no account exists yet, creates one instead. The caller never has to
  // know or ask which case it was.
  //
  // Ambiguity this can't resolve: Firebase's email-enumeration protection
  // means a sign-in failure doesn't distinguish "no account" from "wrong
  // password for an existing one" — both can surface as the same error code.
  // So if we fall through to account creation and Firebase says
  // "email-already-in-use", we genuinely don't know whether that's a
  // mistyped password on an existing password account, or an account that
  // only has Google linked. The message below is honest about that instead
  // of guessing. True account linking (merging both into one account) is a
  // deliberate later upgrade, not done here.
  Future<UserCredential?> signInOrSignUpWithEmail(String email, String password) async {
    const signInFailureCodes = {'user-not-found', 'wrong-password', 'invalid-credential'};
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      log('✅ Signed in to Firebase: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (!signInFailureCodes.contains(e.code)) {
        log('❌ Firebase Auth Error: ${e.code} - ${e.message}');
        rethrow;
      }
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      // No separate "pick a username" step in this flow — fall back to the
      // email's local part as a placeholder display name, editable later
      // from a profile screen whenever that exists.
      await userCredential.user?.updateDisplayName(email.split('@').first);
      log('✅ Account created in Firebase: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      log('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: e.code,
          message: "An account already exists with this email. Check your password, or try continuing with Google if that's how you originally signed up.",
        );
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
      log('✅ User signed out successfully');
    } catch (e) {
      log('❌ Error signing out: $e');
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
      await _googleSignIn.signOut();
      log('✅ Account deleted successfully');
    } catch (e) {
      log('❌ Error deleting account: $e');
      rethrow;
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return currentUser != null;
  }

  // Get user display name
  String? getUserDisplayName() {
    return currentUser?.displayName;
  }

  // Get user email
  String? getUserEmail() {
    return currentUser?.email;
  }

  // Get user photo URL
  String? getUserPhotoUrl() {
    return currentUser?.photoURL;
  }

  // Get user ID
  String? getUserId() {
    return currentUser?.uid;
  }

  // Check if this is a new user (useful for showing onboarding)
  bool isNewUser(UserCredential userCredential) {
    return userCredential.additionalUserInfo?.isNewUser ?? false;
  }
}
