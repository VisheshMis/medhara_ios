# Phase 7: Flashcard Study Session & FSRS Review UI

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Target Subsystem**: Mobile Spaced Repetition Study Engine  

---

## 🎯 Phase Objective
Implement an intuitive, distraction-free flashcard study experience in Jetpack Compose, featuring smooth 3D card flipping gestures, 4 ergonomic bottom rating buttons (Again, Hard, Good, Easy) displaying real-time predicted next intervals from the FSRS-4.5 engine, and review logging.

---

## 📱 Study UI Architecture

```
┌──────────────────────────────────────────────┐
│  [X] Deck: Neuroscience        Card 12 / 48  │
├──────────────────────────────────────────────┤
│                                              │
│         ┌──────────────────────────┐         │
│         │                          │         │
│         │   What is the primary    │         │
│         │   function of the        │         │
│         │   hippocampus?           │         │
│         │                          │         │
│         │     (Tap to Flip)        │         │
│         │                          │         │
│         └──────────────────────────┘         │
│                                              │
├──────────────────────────────────────────────┤
│  [ Again ]   [ Hard ]    [ Good ]   [ Easy ] │
│   <10m         1d          3d         8d     │
└──────────────────────────────────────────────┘
```

---

## 🃏 Card Flip Animation (Compose)

```kotlin
@Composable
fun FlashcardView(
    front: String,
    back: String,
    isFlipped: Boolean,
    onFlip: () -> Unit
) {
    val rotation by animateFloatAsState(
        targetValue = if (isFlipped) 180f else 0f,
        animationSpec = tween(durationMillis = 350, easing = FastOutSlowInEasing),
        label = "CardFlip"
    )

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(360.dp)
            .graphicsLayer {
                rotationY = rotation
                cameraDistance = 12f * density
            }
            .clickable { onFlip() },
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
    ) {
        Box(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            if (rotation <= 90f) {
                Text(text = front, style = MaterialTheme.typography.titleLarge)
            } else {
                Text(
                    text = back,
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.graphicsLayer { rotationY = 180f }
                )
            }
        }
    }
}
```

---

## ⚡ Review Submission & FSRS Pipeline
When the user taps one of the 4 buttons:
1. `FSRSScheduler.review(state, stability, difficulty, elapsedDays, rating)` calculates the new interval, stability, and difficulty.
2. An update transaction is committed to SQLite:
   - Updates `flashcard` with new `fsrsState`, `stability`, `difficulty`, `due`, `lastReview`, and incremented `reps` (and `lapses` if Again).
   - Inserts row into `review_log`.
   - Records CDC entry in `sync_change_log`.
3. The next due card in the deck queue slides into view.

---

## 🧪 Verification Gate
- Card flips smoothly at 60/120 FPS without UI jank.
- All 4 rating buttons display accurate predicted interval strings (e.g. `10m`, `1d`, `3d`, `8d`).
- Reviews correctly update flashcard `due` timestamps and append to `review_log`.
