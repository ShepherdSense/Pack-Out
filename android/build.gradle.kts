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

// NOTE (2026-10-22): an earlier fix injected concurrent-futures + jspecify
// onto the camerax module's compile classpath via afterEvaluate to work
// around CameraX 1.5.3. That hook is GONE: it throws "Cannot run
// Project.afterEvaluate when the project is already evaluated" under
// this template (evaluationDependsOn(":app") evaluates plugin projects
// before the hook registers), and it is unnecessary — pubspec.yaml pins
// camera_android_camerax 0.6.17 / CameraX 1.4.1, which predates the
// JSpecify annotation change entirely.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
