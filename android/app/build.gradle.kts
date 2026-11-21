plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.neaserisgod.mireparto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildTypes { getByName("release") { signingConfig = signingConfigs.getByName("debug") } }
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
