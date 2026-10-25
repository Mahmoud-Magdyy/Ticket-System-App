# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# flutter_inappwebview
-keep class com.pichillilorenzo.** { *; }

# حماية إضافية عشان أي كلاس بيتحول لـ JSON ما يتشالش
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses