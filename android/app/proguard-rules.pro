# Keep Google Play Services Auth classes
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep interface com.google.android.gms.auth.api.credentials.** { *; }

# Keep ProGuard annotations
-keepattributes *Annotation*
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
-keepclassmembers class * {
    @proguard.annotation.Keep *;
}


# Keep SmartAuthPlugin classes
-keep class fman.ge.smart_auth.** { *; }

# Suppress warnings for missing classes related to Google Play Services Credentials API
-dontwarn com.google.android.gms.auth.api.credentials.Credential$Builder
-dontwarn com.google.android.gms.auth.api.credentials.Credential
-dontwarn com.google.android.gms.auth.api.credentials.CredentialPickerConfig$Builder
-dontwarn com.google.android.gms.auth.api.credentials.CredentialPickerConfig
-dontwarn com.google.android.gms.auth.api.credentials.CredentialRequest$Builder
-dontwarn com.google.android.gms.auth.api.credentials.CredentialRequest
-dontwarn com.google.android.gms.auth.api.credentials.CredentialRequestResponse
-dontwarn com.google.android.gms.auth.api.credentials.Credentials
-dontwarn com.google.android.gms.auth.api.credentials.CredentialsClient
-dontwarn com.google.android.gms.auth.api.credentials.HintRequest$Builder
-dontwarn com.google.android.gms.auth.api.credentials.HintRequest

