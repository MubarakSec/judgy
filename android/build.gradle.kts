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

// The Whisper plugin's profile variant falls back to its debug native build,
// where CMake compiles ggml at -O0. Force optimisation so `flutter run
// --profile` and debug builds can transcribe in reasonable time.
subprojects {
    if (name == "whisper_cpp_flutter_plus") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                buildTypes.getByName("debug") {
                    externalNativeBuild {
                        cmake {
                            arguments.addAll(
                                listOf(
                                    "-DCMAKE_CXX_FLAGS_DEBUG=-O3 -g",
                                    "-DCMAKE_C_FLAGS_DEBUG=-O3 -g",
                                ),
                            )
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
