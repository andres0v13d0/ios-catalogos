import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release (ver scripts/build_prod_aab.sh, scripts/build_prod_apk.sh).
// Lee android/key.properties (NUNCA commiteado, ver .gitignore). Si no existe,
// releaseSigningProps queda null y el buildType `release` falla con un
// mensaje claro en vez de firmar silenciosamente con la llave de debug.
val keyPropertiesFile = rootProject.file("key.properties")
val releaseSigningProps: Properties? = if (keyPropertiesFile.exists()) {
    Properties().apply { load(FileInputStream(keyPropertiesFile)) }
} else {
    null
}

android {
    buildFeatures {
        resValues = true
    }

    namespace = "com.example.catalogos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.flystock.revendedores"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningProps != null) {
            create("release") {
                storeFile = file(releaseSigningProps.getProperty("storeFile"))
                storePassword = releaseSigningProps.getProperty("storePassword")
                keyAlias = releaseSigningProps.getProperty("keyAlias")
                keyPassword = releaseSigningProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningProps != null) {
                signingConfigs.getByName("release")
            } else {
                // Sin android/key.properties NO se firma con la llave de debug:
                // se corta el build de release con un mensaje claro. Copia
                // android/key.properties.example a android/key.properties y
                // completa las contraseñas (ver tarea de firma de release).
                throw GradleException(
                    "falta android/key.properties: el build de release no puede " +
                        "firmarse. Copia android/key.properties.example a " +
                        "android/key.properties y completa storePassword/keyPassword " +
                        "(el keystore ya debe existir en la ruta indicada por storeFile)."
                )
            }
        }
    }

    // Flavors por entorno (ver diseño §2.7). Cada flavor usa un applicationId
    // distinto para poder instalar dev/staging/prod en paralelo en un mismo
    // dispositivo, y un nombre de app distinto para identificarlos.
    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "FLYmovil Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "FLYmovil Staging")
        }
        create("prod") {
            dimension = "env"
            // Sin sufijo: applicationId productivo.
            resValue("string", "app_name", "FLYmovil")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
