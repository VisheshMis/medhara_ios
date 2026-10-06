# 🎓 Medha: Student Feature Backlog & Future Problem List

This document outlines key real-world student pain points and feature requirements for upcoming development cycles of **Medha**. These problems were identified from active college/university study workflows, particularly bridging desktop macOS with mobile/Android devices and course-specific curriculum realities.

---

## 📑 Table of Contents
1. [Problem 1: Lecture Slide & PDF Ingestion Pipeline](#1--lecture-slide--pdf-ingestion-pipeline)
2. [Problem 2: Image Occlusion Flashcards for STEM & Anatomy](#2--image-occlusion-flashcards-for-stem--anatomy)
3. [Problem 3: "Exam in 24 Hours" Panic Mode (Cram & Filtered Decks)](#3--exam-in-24-hours-panic-mode-cram--filtered-decks)
4. [Problem 4: Mobile Camera to Memory Palace Friction](#4--mobile-camera-to-memory-palace-friction)
5. [Implementation Roadmap & Milestones](#5--implementation-roadmap--milestones)

---

## 1. 📄 Lecture Slide & PDF Ingestion Pipeline

### 💥 The Problem
- **The Student Reality**: Medha generates comprehensive note skeletons from scratch using encyclopedic search (Wikipedia, OpenAlex, PubMed). However, course exams do **not** test general Wikipedia knowledge—professors test students directly on their **60-to-100-slide lecture slide decks (`.pdf`, `.pptx`)** or assigned textbook chapters.
- **The Friction**: Students currently cannot drag and drop `Lecture_04_Metabolism.pdf` into Medha to automatically extract slide contents, parse diagrams, and generate structured hierarchical block notes and cloze-deletion cards grounded strictly in the professor's material.

### 🎯 Feature Requirements & User Story
> *“As a student with an upcoming midterm, I want to drag my professor's lecture PDF directly into a notebook so that Medha parses each slide, identifies core concepts, and auto-generates structured notes and flashcards without hallucinating outside the lecture scope.”*

### 🛠️ Proposed Technical Architecture
1. **Document Ingestion Engine**:
   - Native macOS: Use Apple's `PDFKit` (`PDFDocument`, `PDFPage`) to extract embedded text, outline bookmarks, and high-res slide snapshots.
   - Web Companion: Integrate `pdfjs-dist` for zero-install client-side text and slide canvas rendering.
2. **Slide Chunking & Structural Parsing**:
   - Group slides by major section headers (detecting font size / slide title hierarchy).
   - Filter slide noise (e.g., recurring slide footers, course codes, professor names).
3. **Pipeline Grounding Adapter**:
   - Route slide text chunks into Medha's **P1–P3 Skeleton Planner** and **P7 Note Writer** as primary context (overriding or supplementing external open APIs).
   - Generate automated cloze-deletion cards (`{{c1::term}}`) from slide bullet points and bold definitions.

---

## 2. 🫀 Image Occlusion Flashcards for STEM & Anatomy

### 💥 The Problem
- **The Student Reality**: Pre-med, biology, neuroscience, engineering, and architecture students survive on **Image Occlusion** (hiding labels on a heart diagram, anatomical chart, histology slide, or circuit schematic to test recall).
- **The Friction**: Standard text-based front/back or cloze flashcards cannot replicate spatial visual recall. Without native image occlusion, STEM students are forced to abandon Medha and return to Anki.

### 🎯 Feature Requirements & User Story
> *“As a medical/biology student, I want to paste a diagram into Medha, draw occluding rectangles or masks over labels, and test myself by having Medha hide one mask while testing my recall.”*

### 🛠️ Proposed Technical Architecture
1. **Interactive Occlusion Mask Canvas**:
   - Canvas overlay on top of any imported image (`NSImage` / SwiftUI `Canvas` or HTML5 Canvas).
   - Tooling: Rectangle tool, polygon mask tool, label text group, and multi-mask selection.
2. **Review Modes**:
   - **Hide One, Reveal One**: Only one mask is active (red/highlighted) as the question; all other labels are visible as context.
   - **Hide All, Reveal One**: All masks remain obscured; tapping/pressing space reveals only the active target mask.
3. **FSRS-4.5 Database Integration**:
   - Extend `Flashcard` schema to store `image_path`, `occlusion_rects` (JSON array of `[x, y, w, h]`), and `mask_index`.
   - Each mask operates as an independent reviewable card with its own Stability ($S$), Difficulty ($D$), and scheduled due dates.

---

## 3. ⏰ "Exam in 24 Hours" Panic Mode (Cram & Filtered Decks)

### 💥 The Problem
- **The Student Reality**: FSRS-4.5 is scientifically calibrated to optimize retention over months and years. However, **24 hours before a midterm or final exam**, long-term intervals are irrelevant—students need to review all 150 cards tagged `#Midterm1` right now.
- **The Friction**: 
  - Standard spaced repetition blocks students from reviewing cards that are "not due yet".
  - If a student forces early reviews, standard scheduling algorithms recalculate intervals prematurely, potentially distorting the long-term memory stability and difficulty parameters.

### 🎯 Feature Requirements & User Story
> *“As a student the night before an exam, I want a ‘Cram Mode’ where I can filter by tag or deck and rapidly review all cards multiple times without distorting my long-term FSRS memory stability.”*

### 🛠️ Proposed Technical Architecture
1. **Filtered / Custom Study Deck**:
   - Create ephemeral study queues based on queries: e.g., `tag:Cardiovascular AND deck:Biology`.
   - Support options:
     - *Review Ahead*: Review cards due in the next $N$ days.
     - *Cram All*: Review all selected cards regardless of due date.
2. **Non-Destructive Review State (Cram Isolation)**:
   - Toggle: `[x] Isolate Cram Session (Do not update FSRS interval parameters)`.
   - In isolated mode, ratings log to a temporary review session for immediate session stats, while leaving the main card's `due_date`, `stability`, and `difficulty` intact.
3. **Emergency Retention HUD**:
   - Display a high-tempo sprint counter: cards mastered in current sprint vs. cards failed, enabling repeated rounds until 100% of the filtered deck is cleared.

---

## 4. 🏛️ Mobile Camera to Memory Palace Friction

### 💥 The Problem
- **The Student Reality**: The 2D Spatial Memory Palace (Method of Loci) relies on importing photographs of real-world physical environments (dorm rooms, libraries, campus walking paths, cafes).
- **The Friction**: 
  - Students carry **phones (Android / iOS) with high-resolution cameras**, not MacBooks, when exploring or studying in physical spaces.
  - Currently, capturing a space requires snapping photos on a phone, manually transferring/AirDropping them to macOS, and importing them into Medha before placing locus pins.

### 🎯 Feature Requirements & User Story
> *“As a student walking through the university library, I want to snap photos with my Android/mobile phone and have them immediately available on my Medha desktop canvas so I can build memory palaces on the fly.”*

### 🛠️ Proposed Technical Architecture
1. **Local Companion Camera Bridge**:
   - Display a **"Scan to Snap & Anchor" QR Code** inside Medha's Memory Palace view.
   - Pointing the phone camera opens a lightweight web capture endpoint served locally by Medha over Wi-Fi (`http://<mac-ip>:port/palace-upload`).
2. **Direct Mobile Upload & Canvas Placement**:
   - Taking a photo on the phone uploads it directly to Medha’s local asset directory.
   - The photo instantly appears on the 2D infinite canvas with smooth spring animation, ready for immediate locus pin drops.
3. **Mobile Locus Pin Creation**:
   - Allow students to tap on the photo directly from the phone browser to assign a note or flashcard title before it even reaches the desktop.

---

## 5. 🗺️ Implementation Roadmap & Milestones

| Milestone | Target Feature | Core Platform / Layer | Complexity | Priority |
| :--- | :--- | :--- | :--- | :--- |
| **M1** | **Cram / Filtered Deck Mode** | MedhaKit (`FSRSScheduler`, `CardBrowser`) & Web Companion | Medium | 🔴 High |
| **M2** | **PDF & Lecture Slide Ingestion** | `PDFKit` text extraction + `AutoNotePipelineService` (P1–P7) | High | 🔴 High |
| **M3** | **Image Occlusion Canvas & Cards** | SwiftUI / Web Canvas + `Flashcard` schema expansion | High | 🟡 Medium |
| **M4** | **Mobile Camera Palace Upload Bridge** | Local HTTP/WebSocket Server + Web Companion capture | Medium | 🟡 Medium |
