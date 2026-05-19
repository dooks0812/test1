import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

fun forceCompileSdkIfMissing(androidExt: Any, sdk: Int) {
    val clazz = androidExt.javaClass
    val getCompileSdk = clazz.methods.firstOrNull {
        it.name == "getCompileSdk" && it.parameterCount == 0
    }
    val setCompileSdk = clazz.methods.firstOrNull {
        it.name == "setCompileSdk" && it.parameterCount == 1
    }
    val compileSdkVersion = clazz.methods.firstOrNull {
        it.name == "compileSdkVersion" && it.parameterCount == 1
    }

    val current = (getCompileSdk?.invoke(androidExt) as? Int) ?: 0
    if (current > 0) return

    if (setCompileSdk != null) {
        setCompileSdk.invoke(androidExt, sdk)
        return
    }

    compileSdkVersion?.invoke(androidExt, sdk)
}

// Add the Google Services Gradle plugin to the classpath (with version)
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Firebase Google Services plugin version
        classpath("com.google.gms:google-services:4.4.2")
    }
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

subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.findByName("android")?.let { androidExt ->
            forceCompileSdkIfMissing(androidExt, 35)
        }
    }
    pluginManager.withPlugin("com.android.application") {
        extensions.findByName("android")?.let { androidExt ->
            forceCompileSdkIfMissing(androidExt, 35)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
