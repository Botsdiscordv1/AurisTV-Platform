plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.auristv.google.tv"
    // Senior Fix: Usar SDK 37 (Requerido por flutter_secure_storage)
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.auristv.google.tv"
        minSdk = flutter.minSdkVersion 
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0"

        manifestPlaceholders["appAuthRedirectScheme"] = "auristv"

        ndk {
            abiFilters.add("x86_64")
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
