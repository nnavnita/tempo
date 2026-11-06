# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications reflects over these when rescheduling after a
# reboot; stripping them makes pending reminders silently disappear.
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { <fields>; }

# Gson, used by flutter_local_notifications to persist scheduled items.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Tink, pulled in by flutter_secure_storage.
-dontwarn com.google.crypto.tink.**

# Flutter's PlayStoreDeferredComponentManager references Play Core, which is
# not a dependency here (no deferred components are used). R8 treats the
# missing classes as a hard error without this.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
