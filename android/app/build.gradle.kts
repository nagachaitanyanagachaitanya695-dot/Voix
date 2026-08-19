import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// gitignored and never committed. See docs/RELEASE.md for how to create it.
// When the file is absent — a fresh clone, or CI that only builds debug — the
// release build falls back to debug keys so `flutter run --release` still
// works. Such a build cannot be uploaded to Play, which is the point: an
// unsigned release fails at upload rather than shipping with throwaway keys.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.voix.voix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time on the Android side, which
        // needs desugaring to run below API 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.voix.voix"
        // Pinned rather than inherited: firebase_auth requires 23, and pinning
        // stops a Flutter upgrade from silently moving the floor under a
        // release that has already shipped to users.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String

                // All three schemes, explicitly.
                //
                // AGP turns v1 off by default once minSdk is 24, on the
                // grounds that v2 is enough from Android 7 onwards. That is
                // true of stock Android and not true of every OEM: MIUI's
                // package installer refuses a v2-only APK and reports it as a
                // bare "App not installed." with no reason given, which is
                // indistinguishable from a signature conflict or a corrupt
                // download.
                //
                // v1 costs a little size and nothing else, so there is no
                // reason to make a phone prove it can do without it.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Left off deliberately. R8 can strip classes that plugins reach
            // reflectively, and the failure only ever shows up in a release
            // build — the one build you cannot iterate on quickly. Turn it on
            // once you can test a release APK on a device; proguard-rules.pro
            // already carries the keep rules this app needs.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
