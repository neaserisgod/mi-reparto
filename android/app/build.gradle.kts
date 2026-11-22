plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
val appSigningPath = System.getenv("APP_SIGNING_KEYSTORE")
android {
    namespace = "com.neaserisgod.mireparto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        create("personal") {
            storeFile = appSigningPath?.let { file(it) }
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeType = "PKCS12"
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("personal")
            // También filtrar las bibliotecas JNI que agregan los SDK de mapas.
            // El APK distribuido incluye el motor Flutter para ARM64.
            ndk { abiFilters.add("arm64-v8a") }
        }
    }
    defaultConfig {
        applicationId = "com.neaserisgod.mireparto"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}
flutter { source = "../.." }

dependencies { implementation("androidx.core:core:1.15.0") }
