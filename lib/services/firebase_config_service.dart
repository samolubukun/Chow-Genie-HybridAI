import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

/// Service managing Firebase Core, App Check, Remote Config, Auth, and Firestore.
class FirebaseConfigService {
  FirebaseConfigService._();
  static final FirebaseConfigService instance = FirebaseConfigService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _userId;
  String? get userId => _userId;

  /// Initializes all Firebase services according to #BuildHybridAI 2026 specifications.
  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _isInitialized = true;
      developer.log('Firebase App initialized successfully', name: 'FirebaseConfig');

      // 1. Activate Firebase App Check with Debug Provider (Required by AI Logic rules)
      await _initializeAppCheck();

      // 2. Initialize Firebase Remote Config (Dynamic model tuning and prompt parameters)
      await _initializeRemoteConfig();

      // 3. Authenticate user anonymously for zero-friction start and Firestore security rules
      await _initializeAnonymousAuth();
    } catch (e) {
      developer.log(
        'Firebase initialization running in local sandbox fallback mode: $e',
        name: 'FirebaseConfig',
      );
    }
  }

  Future<void> _initializeAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
        // On web debug environments, use debug provider or fall back gracefully
        webProvider: kDebugMode
            ? null
            : ReCaptchaV3Provider('recaptcha-v3-site-key-placeholder'),
      );
      developer.log('Firebase App Check activated with Debug Provider', name: 'FirebaseConfig');
    } catch (e) {
      developer.log('App Check debug setup: $e', name: 'FirebaseConfig');
    }
  }

  Future<void> _initializeRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Set default parameters for hybrid AI inference
      await remoteConfig.setDefaults(const {
        'ai_routing_mode': 'PREFER_ON_DEVICE',
        'enable_cloud_fallback': true,
        'ai_prompt_prefix': 'You are ChowGenie, an expert on-device chef.',
        'max_recipe_tokens': 1024,
      });

      await remoteConfig.fetchAndActivate();
      developer.log('Firebase Remote Config activated', name: 'FirebaseConfig');
    } catch (e) {
      developer.log('Remote config init: $e', name: 'FirebaseConfig');
    }
  }

  Future<void> _initializeAnonymousAuth() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      _userId = userCredential.user?.uid;
      developer.log('User signed in anonymously with UID: $_userId', name: 'FirebaseConfig');
    } catch (e) {
      developer.log('Anonymous auth note: $e', name: 'FirebaseConfig');
    }
  }

  /// Syncs a user-generated recipe to Cloud Firestore.
  Future<void> syncRecipeToFirestore(Map<String, dynamic> recipe) async {
    try {
      final uid = _userId ?? 'local_user';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .doc(recipe['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString())
          .set({
        ...recipe,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      developer.log('Recipe synced to Firestore', name: 'FirebaseConfig');
    } catch (e) {
      developer.log('Firestore recipe sync fallback: $e', name: 'FirebaseConfig');
    }
  }
}
