# Razorpay
-keepattributes *Annotation*
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keep class com.razorpay.** {*;}
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers

# Retrofit
-keep class retrofit2.** { *; }
-keepattributes Signature, Exceptions
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# Hive
-keep class * extends com.hive.** {*;}
-dontwarn com.hive.**

# Gson
-keep class com.google.gson.** {*;}
-keepattributes *Annotation*

# Firebase
-keep class com.google.firebase.** {*;}

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# FCM background handler
-keep class io.flutter.plugins.firebase.messaging.** {*;}
