allprojects {
    repositories {
        google()
        mavenCentral()
        // Espressif's Android provisioning SDK ships only via JitPack.
        // Plugin-declared repos do not propagate to consuming apps, so
        // every host app that includes esp_provisioning_flutter must add
        // this line. See the plugin README for details.
        maven { url = uri("https://jitpack.io") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
