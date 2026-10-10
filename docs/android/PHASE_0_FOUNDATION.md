# Phase 0: Android Toolchain, Gradle Scaffold & Clean Architecture

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Status**: Completed / Ready for Iteration  
> **Target Environment**: Android 8.0+ (API Level 26..35), Kotlin 2.0+, Jetpack Compose Material 3  

---

## 🎯 Phase Objective
Establish a clean, modern Android mobile companion project structure in `android/` with Gradle Kotlin DSL (`.kts`), version catalogs (`libs.versions.toml`), deterministic dependency locking, and unit testing infrastructure.

---

## 🏗️ Directory Layout

```
android/
├── build.gradle.kts                   # Root build script
├── settings.gradle.kts                # Project & plugin repository configuration
├── gradle.properties                  # JVM tuning & AndroidX flags
├── gradlew / gradlew.bat              # Gradle 8.x wrapper
├── gradle/
│   └── libs.versions.toml             # Centralized version catalog
└── app/
    ├── build.gradle.kts               # Module build configuration
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml
        │   ├── java/com/medha/companion/
        │   │   ├── MedhaApplication.kt
        │   │   ├── MainActivity.kt
        │   │   ├── data/
        │   │   │   ├── model/         # Core data entities
        │   │   │   ├── local/         # Room DB & DAOs
        │   │   │   └── sync/          # Sync client & mutation tracker
        │   │   ├── domain/
        │   │   │   ├── fsrs/          # FSRS-4.5 engine
        │   │   │   └── usecase/       # Domain business logic
        │   │   └── ui/
        │   │       ├── theme/         # Material 3 colors & typography
        │   │       ├── reader/        # Note reader screen
        │   │       ├── study/         # Flashcard review screen
        │   │       └── capture/       # Quick capture sheet
        │   └── res/
        └── test/                      # Unit tests (JUnit 5 / JUnit 4 + Robolectric)
```

---

## ⚙️ Key Toolchain Configuration

### 1. `gradle/libs.versions.toml`
```toml
[versions]
agp = "8.4.1"
kotlin = "2.0.0"
compose-bom = "2024.05.00"
room = "2.6.1"
coroutines = "1.8.1"
workmanager = "2.9.0"
junit = "4.13.2"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version = "1.13.1" }
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-icons = { group = "androidx.compose.material", name = "material-icons-extended" }
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
work-runtime-ktx = { group = "androidx.work", name = "work-runtime-ktx", version.ref = "workmanager" }
junit = { group = "junit", name = "junit", version.ref = "junit" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version = "2.0.0-1.0.21" }
```

### 2. Core Build Verification
- Verify that `./gradlew tasks` runs cleanly.
- Verify that `MainActivity.kt` initializes a Material 3 Scaffold.

---

## 🧪 Verification Gate
- `./gradlew test` executes and passes with 0 failures.
- No legacy `build.gradle` (Groovy) files exist; strict Kotlin DSL is enforced throughout.
