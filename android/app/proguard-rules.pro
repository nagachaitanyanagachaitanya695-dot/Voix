# Keep rules for a minified release build.
#
# Minification is currently disabled in build.gradle.kts (see the comment
# there). These rules are staged so that turning it on is a one-line change
# rather than a debugging session.

# ── Flutter engine ──────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── flutter_local_notifications ─────────────────────────────────────────────
# Scheduled notifications are restored after reboot by deserialising them from
# JSON with Gson, which resolves the model classes reflectively.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn com.dexterous.**

# Gson's generic type resolution relies on these.
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ── Firebase ────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore maps documents onto model classes by reflection.
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <methods>;
}

# ── Speech and text-to-speech ───────────────────────────────────────────────
-keep class android.speech.** { *; }
-dontwarn android.speech.**
