plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.raufeken.yasli_destek_sistemi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

   android {
    // ...
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17 // 1.8 yerine 17 yapıyoruz
        targetCompatibility = JavaVersion.VERSION_17 // 1.8 yerine 17 yapıyoruz
    }

    kotlinOptions {
        jvmTarget = "17" // Burayı da "17" olarak güncelliyoruz
    }
}

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.raufeken.yasli_destek_sistemi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
dependencies {
    // Mevcut diğer dependency'lerin altına ekle
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3") 
}