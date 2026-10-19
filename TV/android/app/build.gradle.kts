import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Firma con el keystore de release persistente si existe (key.properties).
            // Sin él cae a la firma debug para que `flutter run --release` siga funcionando.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Watch Next: fila "Continuar Viendo" en el launcher de Android/Google TV.
    implementation("androidx.tvprovider:tvprovider:1.1.0")
}
