allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect all projects to E:\Holder\build instead of E:\Holder\android\build
val newBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val subprojectDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(subprojectDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
