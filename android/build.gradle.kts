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
    project.evaluationDependsOn(":app")
}

// pay_android 3.2.0 define Java em 11, mas mantém Kotlin em 1.8.
// Aplica o alvo Kotlin depois da avaliação do módulo para prevalecer sobre
// a configuração padrão definida pelo próprio plugin.
subprojects {
    if (name == "pay_android") {
        afterEvaluate {
            tasks.withType<KotlinCompile>().configureEach {
                kotlinOptions.jvmTarget = "11"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
