import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/drame_reel_app.dart';

void main() {
  // 1. Wajib yang pertama dan tanpa await yang menahan UI
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inisialisasi engine media_kit langsung
  MediaKit.ensureInitialized(); 

  // 3. Jalankan aplikasi terlebih dahulu agar Splash Screen langsung tampil tanpa jeda hitam
  runApp(const ProviderScope(child: DrameReelApp()));

  // 4. Inisialisasi background/plugin pendukung dijalankan setelah aplikasi berjalan
  _initBackgroundTasks();
}

void _initBackgroundTasks() async {
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'firebase_core'));
  }
  try {
    await WakelockPlus.enable();
  } catch (_) {}
}
