import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

    // audio_waveforms depends on the legacy ExoPlayer 2 BOM (pulls exoplayer-ui).
    // video_360 uses Media3 PlayerView — merged UI layouts crash at runtime.
    configurations.configureEach {
        exclude(group = "com.google.android.exoplayer", module = "exoplayer-ui")
        resolutionStrategy.eachDependency {
            if (requested.group == "com.google.android.exoplayer" && requested.name == "exoplayer") {
                useTarget("com.google.android.exoplayer:exoplayer-core:${requested.version}")
                because("Chat audio only needs ExoPlayer core; full BOM conflicts with Media3 VR player")
            }
        }
    }

    // Register before :app evaluation so plugin JVM targets stay aligned (Java 17 / Kotlin 17).
    afterEvaluate {
        extensions.findByType(BaseExtension::class.java)?.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
