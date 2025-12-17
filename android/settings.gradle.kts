import org.gradle.api.initialization.resolve.RepositoriesMode
import java.util.Properties // (val properties = java.util.Properties() で必要)

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // もしプラグインが別のリポジトリを要求するならここにも追加できます
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")

// プラグイン以外の「ライブラリ」（ffmpeg-kitなど）を探す場所を定義します
dependencyResolutionManagement {
    // settings 側のリポジトリを優先させる
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // Flutter のネイティブエンジンアーティファクトを提供する必須リポジトリ
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        // ffmpeg-kit を探す場合に必要になることがある
        maven { url = uri("https://jitpack.io") }
    }
}