// lib/services/auth_service.dart

import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:oddsly/services/firebase_service.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseService _firebaseService = FirebaseService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Map<String, dynamic>> registerWithEmailPassword({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (name != null && name.isNotEmpty) {
        await userCredential.user?.updateDisplayName(name);
      }

      // Создать профиль в Firestore с uid
      await _firebaseService.createUserProfile(
        uid: userCredential.user!.uid,
        email: email,
        displayName: name,
      );

      final String? idToken = await userCredential.user?.getIdToken();

      return {
        'success': true,
        'token': idToken,
        'user': {
          'uid': userCredential.user?.uid,
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
        }
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Произошла ошибка: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Проверить наличие профиля в Firestore, создать если нет
      final profile = await _firebaseService.getUserProfile(userCredential.user!.uid);
      if (profile == null) {
        await _firebaseService.createUserProfile(
          uid: userCredential.user!.uid,
          email: email,
          displayName: userCredential.user?.displayName,
        );
      }

      final String? idToken = await userCredential.user?.getIdToken();

      return {
        'success': true,
        'token': idToken,
        'user': {
          'uid': userCredential.user?.uid,
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
        }
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Произошла ошибка: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {
          'success': false,
          'message': 'Вход через Google отменён',
        };
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      // Проверить наличие профиля в Firestore, создать если нет
      final profile = await _firebaseService.getUserProfile(userCredential.user!.uid);
      if (profile == null) {
        await _firebaseService.createUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email!,
          displayName: userCredential.user?.displayName,
        );
      }

      final String? idToken = await userCredential.user?.getIdToken();

      return {
        'success': true,
        'token': idToken,
        'user': {
          'uid': userCredential.user?.uid,
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
          'photoURL': userCredential.user?.photoURL,
        }
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка Google Sign-In: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return {
        'success': false,
        'message': 'Apple Sign-In доступен только на iOS и macOS',
      };
    }

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final AuthorizationCredentialAppleID appleCredential =
      await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final OAuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final fullName =
        '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
            .trim();
        if (fullName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(fullName);
        }

        // Создать профиль в Firestore
        await _firebaseService.createUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email!,
          displayName: fullName.isNotEmpty ? fullName : null,
        );
      }

      final String? idToken = await userCredential.user?.getIdToken();

      return {
        'success': true,
        'token': idToken,
        'user': {
          'uid': userCredential.user?.uid,
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
        }
      };
    } on SignInWithAppleAuthorizationException catch (e) {
      return {
        'success': false,
        'message': 'Apple Sign-In отменён: ${e.message}',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка Apple Sign-In: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Инструкции по сбросу пароля отправлены на $email',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка при сбросе пароля: ${e.toString()}',
      };
    }
  }

  Future<String?> getCurrentUserIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Пользователь не авторизован',
        };
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      return {
        'success': true,
        'message': 'Профиль успешно обновлен',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка обновления профиля: ${e.toString()}',
      };
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      return {
        'success': true,
        'message': 'Аккаунт успешно удален',
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return {
          'success': false,
          'message': 'Требуется повторная авторизация для удаления аккаунта',
          'requiresRecentLogin': true,
        };
      }
      return {
        'success': false,
        'message': _getErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка при удалении аккаунта: ${e.toString()}',
      };
    }
  }

  bool isEmailVerified() {
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<Map<String, dynamic>> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return {
        'success': true,
        'message': 'Письмо для подтверждения email отправлено',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка отправки письма: ${e.toString()}',
      };
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length,
            (_) => charset[random.nextInt(charset.length)]
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Пароль слишком слабый. Используйте минимум 6 символов.';
      case 'email-already-in-use':
        return 'Email уже используется другим аккаунтом.';
      case 'invalid-email':
        return 'Некорректный email адрес.';
      case 'user-not-found':
        return 'Пользователь с таким email не найден.';
      case 'wrong-password':
        return 'Неверный пароль.';
      case 'user-disabled':
        return 'Этот аккаунт был заблокирован.';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже.';
      case 'operation-not-allowed':
        return 'Этот метод входа не разрешен. Обратитесь к администратору.';
      case 'network-request-failed':
        return 'Ошибка сети. Проверьте интернет-соединение.';
      case 'invalid-credential':
        return 'Неверные учетные данные.';
      case 'account-exists-with-different-credential':
        return 'Аккаунт уже существует с другим методом входа.';
      case 'requires-recent-login':
        return 'Требуется повторная авторизация.';
      default:
        return 'Произошла ошибка. Попробуйте еще раз.';
    }
  }

  Future<String?> signInWithGoogleAndGetIdToken() async {
    final result = await signInWithGoogle();
    return result['success'] == true ? result['token'] : null;
  }

  Future<String?> signInWithAppleAndGetIdToken() async {
    final result = await signInWithApple();
    return result['success'] == true ? result['token'] : null;
  }
}