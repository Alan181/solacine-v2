# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Gson / Moshi common
-keepattributes Signature
-keepattributes *Annotation*
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.Metadata

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keep class okhttp3.** { *; }

# Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Exceptions

# Dio HTTP client
-keep class retrofit2.** { *; }

# AndroidX / Jetpack
-keep class androidx.** { *; }
-dontwarn androidx.**

# Google Mobile Ads & Mediation Adapters
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
-keep class com.google.android.gms.ads.identifier.** { *; }
-keep class com.google.android.gms.common.** { *; }

# AppLovin MAX SDK
-keep class com.applovin.** { *; }
-dontwarn com.applovin.**

# Facebook / Meta Audience Network mediation
-dontwarn com.facebook.infer.annotation.Nullsafe
-dontwarn com.facebook.infer.annotation.Nullsafe$Mode
-keep class com.facebook.ads.** { *; }
-dontwarn com.facebook.ads.**
-keep class com.meta.** { *; }
-dontwarn com.meta.**

# Unity Ads / LevelPlay Mediation
-keep class com.unity3d.ads.** { *; }
-keep class com.ironsource.** { *; }
-dontwarn com.ironsource.**
-dontwarn com.unity3d.ads.**

# Sign in with Apple
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }
-dontwarn com.aboutyou.dart_packages.sign_in_with_apple.**

# FCM / Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Secure storage / encrypted shared prefs
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**
-keep class de.cberner.flutter.securestorage.** { *; }
-dontwarn de.cberner.flutter.securestorage.**

# Google Sign In
-keep class com.google.android.gms.auth.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }
-dontwarn io.flutter.plugins.googlesignin.**

# Video Player 2.13+ / AndroidX Media3 / ExoPlayer
-keep class androidx.media3.** { *; }
-keep class androidx.media3.exoplayer2.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.google.android.exoplayer.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**
-keepclassmembers class androidx.media3.common.Timeline {
  <fields>;
  <methods>;
}
-keep class * extends androidx.media3.common.Timeline { *; }

# WebView Flutter
-keep class androidx.webkit.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn androidx.webkit.**
-dontwarn io.flutter.plugins.webviewflutter.**

# In-App Purchase (Billing Library)
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Wakelock Plus
-keep class dev.fluttercommunity.plus.wakelock.** { *; }
-dontwarn dev.fluttercommunity.plus.wakelock.**

# Package Info Plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# Device Info Plus
-keep class dev.fluttercommunity.plus.deviceinfo.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# CameraX / Image Capture
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
