plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ❌ Do NOT add google-services here (you apply it at the bottom)
}

android {
    namespace = "com.example.test1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.test1"

        // ✅ IMPORTANT: flutter_local_notifications needs desugaring, and minSdk should be >= 21
        // If flutter.minSdkVersion is < 21, force 21.
        minSdk = maxOf(flutter.minSdkVersion, 21)

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ FIX: Enable desugaring (required by flutter_local_notifications)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    // ✅ Keep Kotlin aligned with Java 8
    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            // For now, sign with debug keys so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ✅ REQUIRED for core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}

// ✅ Apply Google Services plugin
apply(plugin = "com.google.gms.google-services")
