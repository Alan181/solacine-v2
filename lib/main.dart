import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart'; // <-- 1. Import media_kit di sini
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/drame_reel_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Wajib dipanggil sebelum aplikasi berjalan
  MediaKit.ensureInitialized(); 

  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'firebase_core'));
  }
  try {
    await WakelockPlus.enable();
  } catch (_) {}
  runApp(const ProviderScope(child: DrameReelApp()));
}
