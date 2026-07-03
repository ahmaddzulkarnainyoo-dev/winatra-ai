pluginManagement {
    val flutterSdkPath = run {
        val localProperties = file("local.properties")
        if (localProperties.exists()) {
            val properties = java.util.Properties()
            localProperties.inputStream().use { properties.load(it) }
            val sdk = properties.getProperty("flutter.sdk")
            if (sdk != null) return@run sdk
        }
        // Fallback to FLUTTER_ROOT environment variable (used in CI)
        val envSdk = System.getenv("FLUTTER_ROOT")
        require(envSdk != null) { "flutter.sdk not set in local.properties and FLUTTER_ROOT env var not set" }
        envSdk
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
