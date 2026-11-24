import com.android.build.api.variant.LibraryAndroidComponentsExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    // Disponibiliza a API do Kotlin para alinhar o alvo JVM do plugin pay_android.
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    if (name == "stripe_android") {
        // O Nhac usa PaymentSheet. O SDK restrito de emissão de cartões é opcional.
        configurations.matching { it.name == "compileOnly" }.configureEach {
            dependencies.withType<ExternalModuleDependency>().configureEach {
                if (group == "com.stripe" && name == "stripe-android-issuing-push-provisioning") {
                    exclude(group = "com.google.android.gms", module = "play-services-tapandpay")
                }
            }
        }
    }
    if (name == "flutter_native_splash") {
        // O plugin 2.4.4 declara API 31, abaixo da exigida pelas bibliotecas AndroidX.
        pluginManager.withPlugin("com.android.library") {
            extensions.getByType<LibraryAndroidComponentsExtension>().finalizeDsl {
                it.compileSdk = 36
            }
        }
    }
    project.evaluationDependsOn(":app")
}

// pay_android 3.2.0 define Java em 11, mas mantém Kotlin em 1.8.
// Aplica o alvo Kotlin depois da avaliação do módulo, usando a DSL atual.
subprojects {
    if (name == "pay_android") {
        afterEvaluate {
            tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(JvmTarget.JVM_11)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
