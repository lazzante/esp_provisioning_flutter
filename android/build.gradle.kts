group = "com.rainybit.esp_provisioning_flutter"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Espressif's official Android provisioning library ships exclusively
        // via JitPack — there is no Maven Central release. Pin to a tagged
        // release (no SNAPSHOTs) so the build is deterministic.
        maven { url = uri("https://jitpack.io") }
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.rainybit.esp_provisioning_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        // 23 matches the rainybit_mobile baseline and gives us the runtime
        // permission flow needed for BLUETOOTH_SCAN/CONNECT (Android 12+)
        // and ACCESS_FINE_LOCATION (Android 11 and below).
        minSdk = 23
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    // Espressif's official Android provisioning SDK. Implements the
    // ESP-IDF unified provisioning protocol (SRP6a security2, AES-GCM,
    // BLE / SoftAP transports, custom data endpoints).
    implementation("com.github.espressif:esp-idf-provisioning-android:lib-2.4.4")

    // AndroidX runtime helpers used by BluetoothStateProbe.
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.annotation:annotation:1.8.2")

    // Kotlin coroutines: SDK callbacks land on arbitrary threads; we
    // marshal onto Dispatchers.Main before touching Flutter channels
    // (analogous to DispatchQueue.main.async on iOS).
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // EventBus is pulled in transitively by esp-idf-provisioning-android,
    // but with `implementation` scope — meaning we cannot reference it
    // ourselves unless we declare it directly. ESPProvisionManager posts
    // DeviceConnectionEvent through EventBus.getDefault(), so the bridge
    // needs to subscribe. Pin to the exact version the SDK transitively
    // depends on (3.3.1) to avoid version-conflict warnings.
    implementation("org.greenrobot:eventbus:3.3.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
