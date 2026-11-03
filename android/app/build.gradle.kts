import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.techincglobal.crmcaller"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }



    buildFeatures {
        compose = true
    }

    defaultConfig {
        applicationId = "com.techincglobal.crmcaller"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    signingConfigs {
        create("release") {
            // Set these via key.properties, environment variables or a local.properties file — never commit keys.
            // keytool -genkey -v -keystore release.jks -alias crm_caller -keyalg RSA -keysize 2048 -validity 10000
            val keystorePath = keystoreProperties.getProperty("storeFile")
                ?: System.getenv("KEYSTORE_PATH")
                ?: (rootProject.projectDir.absolutePath + "/release.jks")
            val keystorePass = keystoreProperties.getProperty("storePassword")
                ?: System.getenv("KEYSTORE_PASSWORD")
                ?: ""
            val envKeyAlias = keystoreProperties.getProperty("keyAlias")
                ?: System.getenv("KEY_ALIAS")
                ?: "crm_caller"
            val envKeyPass = keystoreProperties.getProperty("keyPassword")
                ?: System.getenv("KEY_PASSWORD")
                ?: ""
            storeFile = file(keystorePath)
            storePassword = keystorePass
            keyAlias = envKeyAlias
            keyPassword = envKeyPass
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keystorePropertiesFile.exists() || System.getenv("KEYSTORE_PATH") != null) {
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
    
    val room_version = "2.8.4"
    implementation("androidx.room:room-runtime:$room_version")
    ksp("androidx.room:room-compiler:$room_version")
    implementation("androidx.room:room-ktx:$room_version")
    
    // WorkManager
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    
    // Lifecycle & SavedState (Required for ViewTree owners in system windows)
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.savedstate:savedstate-ktx:1.2.1")
    
    
    // LocalBroadcastManager (removed from core in API 26+ but kept as standalone artifact)
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")

    // HTTP client for Frappe API
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Compose dependencies
    val composeBom = platform("androidx.compose:compose-bom:2024.02.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")

    testImplementation("junit:junit:4.13.2")
}


