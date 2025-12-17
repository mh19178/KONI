plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.form_analyzer_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // ★ 元のバージョンに戻しました (flutter.ndkVersionでも良いかもしれません)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.form_analyzer_app"

        // ★★★ 修正箇所: 24に固定します ★★★
        // ffmpeg-kit (video_trimmerが使用) は24以上が必要です
        minSdkVersion(24)

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ★ 追加: MultiDexを有効化 (推奨)
        multiDexEnabled = true
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

// ★★★ 修正箇所: 必要なdependenciesブロックを復元 ★★★
dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
}