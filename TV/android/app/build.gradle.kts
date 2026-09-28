plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.auristv.oficial.tv"
    // Senior Fix: Usar SDK 37 (Requerido por flutter_secure_storage)
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.auristv.oficial.tv"
        minSdk = flutter.minSdkVersion 
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
        manifestPlaceholders["appAuthRedirectScheme"] = "auristv"
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
