plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.themorpheus.morphhealth.local"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "de.themorpheus.morphhealth.local"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("localRelease") {
            storeFile = file(System.getenv("MH_SIGN_KEY") ?: "../../../.signing/morphhealth.jks")
            storePassword = System.getenv("MH_SIGN_PASSWORD")
            keyAlias = "morphhealth"
            keyPassword = System.getenv("MH_SIGN_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("localRelease")
        }
    }
}

flutter {
    source = "../.."
}
