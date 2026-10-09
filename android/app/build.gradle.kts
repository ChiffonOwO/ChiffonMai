import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── 正式发布签名 ────────────────────────────────────────────────────────────
// 口令与 keystore 文件名放在 android/key.properties（已被 android/.gitignore 忽略）。
//
// 为什么必须有：release 包以前用 debug key 签名，而 debug keystore 是**每台机器各自的**，
// 一旦装机就永远无法覆盖更新，应用商店也不收。且 APP 备案要填「安卓平台软件包名称 +
// 公钥 + 证书MD5指纹」，这三项都必须与最终上架的那个包一致，所以签名必须在上架前定死。
//
// 缺 key.properties 时 debug 构建照常可用，但 assembleRelease/bundleRelease 会直接失败
// —— 绝不静默退回 debug 签名（那正是这次要消除的坑）。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // namespace 只决定 R 类与资源解析，跟 App 在设备/商店里的身份无关，保持不变，
    // 免得挪动 MainActivity.kt 所在的包目录（动它没有收益、只有风险）。
    namespace = "com.example.my_first_flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // ⚠️ applicationId 才是 App 的永久身份：APP 备案 的「安卓平台软件包名称」填它，
        // 应用商店的包名也是它。**备案通过后改它要走变更备案**，老用户还会装成第二个 App
        // （本地数据不迁移），所以定下来就别再动。
        applicationId = "cloud.chiffonmai.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // 占位而已：真正的拦截在文件末尾的前置检查里。
                // 这里不能 throw —— buildTypes 在配置阶段就会执行，throw 会连
                // `flutter run`（debug）一起搞挂。
                signingConfigs.getByName("debug")
            }
            // 暂不启用 R8 混淆和资源压缩：项目包含多处网络请求、动态 JSON 解析、
            // 反射和第三方登录/同步流程，当前 keep 规则无法覆盖全部路径，混淆后
            // 可能出现请求参数、响应模型或回调被破坏的间歇性网络问题。
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// 没有 android/key.properties 时，明确地让 release 打包失败，而不是静默用 debug key 出包。
tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }.configureEach {
    doFirst {
        if (!hasReleaseKeystore) {
            throw GradleException(
                "缺少 android/key.properties —— release 包必须用正式签名，不能退回 debug key。" +
                    "请从离线备份恢复 keystore 与 key.properties" +
                    "（字段：storePassword / keyPassword / keyAlias / storeFile）。"
            )
        }
    }
}

flutter {
    source = "../.."
}
