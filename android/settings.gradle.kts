import org.gradle.api.initialization.resolve.RepositoriesMode
import java.util.Properties
import java.io.FileInputStream

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven {
            val localProperties = Properties()
            val localPropertiesFile = rootProject.file("local.properties")
            if (localPropertiesFile.exists()) {
                localProperties.load(FileInputStream(localPropertiesFile))
            }
            val flutterRoot = localProperties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")
            if (flutterRoot == null) {
                throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
            }
            url = uri("$flutterRoot/packages/flutter_tools/gradle")
        }
    }
}

plugins {
    id("com.android.application") version "7.3.0" apply false
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
    id("org.jetbrains.kotlin.android") version "1.7.10" apply false
}

include(":app")

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}