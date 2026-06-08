plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.dsrv.wallet.example"
    compileSdk = 35

    buildFeatures {
        compose = true
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 4
        versionName = "0.0.3"

        val customerBackendUrl: String = project.findProperty("CUSTOMER_BACKEND_URL") as? String ?: "https://your-backend.com"
        buildConfigField("String", "CUSTOMER_BACKEND_URL", "\"$customerBackendUrl\"")

        val dsrvApiBaseUrl: String = project.findProperty("DSRV_API_BASE_URL") as? String ?: "https://api.dsrv.com"
        buildConfigField("String", "DSRV_API_BASE_URL", "\"$dsrvApiBaseUrl\"")

        val sdkId: String = project.findProperty("SDK_ID") as? String ?: "your-sdk-id"
        buildConfigField("String", "SDK_ID", "\"$sdkId\"")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    // DSRV Wallet SDK - 바이너리(AAR) 참조. app/libs/sdk-release.aar 에 위치.
    implementation(files("libs/sdk-release.aar"))

    // SDK 런타임 의존성 — files() AAR 은 transitive 의존성을 전파하지 않으므로 명시 필요.
    // (okhttp / web3j:core 는 아래에 이미 선언되어 있어 생략)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    implementation("net.zetetic:android-database-sqlcipher:4.5.3")
    implementation("androidx.sqlite:sqlite:2.4.0")
    implementation("org.web3j:rlp:4.9.8")
    implementation("org.web3j:crypto:4.9.8")
    implementation("com.google.android.play:integrity:1.4.0")
    implementation("com.google.android.gms:play-services-auth-blockstore:16.4.0")
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("androidx.biometric:biometric:1.1.0")

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)

    implementation(platform("androidx.compose:compose-bom:2024.05.00"))
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.0")
    implementation("androidx.compose.material:material-icons-extended:1.7.5")

    implementation("org.web3j:core:4.9.8")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // QR Code generation (ZXing)
    implementation("com.google.zxing:core:3.5.2")

    // Camera + ML Kit Barcode scanning (MPM QR 스캔)
    implementation("com.google.mlkit:barcode-scanning:17.2.0")
    implementation("androidx.camera:camera-camera2:1.4.0")
    implementation("androidx.camera:camera-lifecycle:1.4.0")
    implementation("androidx.camera:camera-view:1.4.0")

    // JSON 매핑 (Payment / WebSocket DTO)
    implementation("com.google.code.gson:gson:2.10.1")

    // Compose 권한 요청 (CAMERA)
    implementation("com.google.accompanist:accompanist-permissions:0.34.0")
}
