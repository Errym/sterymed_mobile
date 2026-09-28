# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Dio (reflection-free, but keep annotations)
-keepattributes Annotation, Signature, Exception

# Dart / Flutter
-keep class io.flutter.** { *; }

# Flutter's embedding references Play Core's split-install APIs (deferred
# components / dynamic feature modules) even though this app doesn't use
# them and doesn't depend on play-core — R8 fails on the missing classes
# without this. See https://github.com/flutter/flutter/issues/89971.
-dontwarn com.google.android.play.core.**
