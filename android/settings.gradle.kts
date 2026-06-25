pluginManagement {
    plugins {
        id("com.android.application") version "8.11.1"
        id("org.jetbrains.kotlin.android") version "2.2.20"
        id("dev.flutter.flutter-gradle-plugin") version "1.0.0"
        id("com.google.gms.google-services") version "4.4.0" apply false
    }
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

include(":app")
