## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

## Supabase
-keep class io.supabase.** { *; }
-keepclassmembers class io.supabase.** { *; }

## Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

## Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

## Gson (used by many libraries)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

## Image Picker
-keep class androidx.core.content.FileProvider { *; }

## Notifications
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$* { *; }
