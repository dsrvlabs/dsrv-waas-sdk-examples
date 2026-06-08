pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "dsrv-wallet-sdk-android-example"
include(":app")

// SDK 는 app/libs/sdk-release.aar (바이너리) 로 참조합니다.
// app/build.gradle.kts 의 implementation(files("libs/sdk-release.aar")) 참고.
