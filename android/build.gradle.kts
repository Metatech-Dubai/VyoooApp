allprojects {
    repositories {
        // Optional local mirror for the large Insta360 AARs (sdkcamera/sdkmedia/snpe/bmgmedia).
        // Insta360's Maven serves these multi-MB files unreliably; when present, this resolves them
        // locally. Active only if the directory exists, so it is a no-op on CI / other machines.
        val insta360Mirror = file("${rootProject.projectDir}/../../../insta360-mirror")
        if (insta360Mirror.exists()) {
            maven { url = insta360Mirror.toURI() }
        }
        google()
        mavenCentral()
        // Insta360 SDK (sdkcamera/sdkmedia + transitive insbase/basecamera/basemedia/snpe).
        // Guest credentials per the Insta360 Developer SDK package. Insecure protocol allowed for this host only.
        maven {
            url = uri("https://androidsdk.insta360.com/repository/maven-public/")
            isAllowInsecureProtocol = true
            credentials {
                username = "insta360guest"
                password = "EXMSjSo8OeOrjU7d"
            }
        }
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
