# Local AI Setup Guide for Medha (मेधा)

Medha supports **100% offline, private Local AI** running directly on your Mac. You don't need any paid subscription, cloud API key, or internet connection to use AI-assisted notes expansion, hierarchical outline generation, or Socratic flashcard tutoring.

Even better, Medha features **Free Online Wikipedia Grounding**—a built-in mechanism that feeds real-time, factual context into lightweight local models so they don't hallucinate or struggle with niche trivia.

---

## 📋 System Requirements

| Specification | Minimum | Recommended |
| :--- | :--- | :--- |
| **Operating System** | macOS 14.0 (Sonoma) or later | macOS 14.0+ or macOS 15.0+ |
| **Chip / Architecture** | Apple Silicon (M1/M2/M3/M4) or Intel Mac | Apple Silicon (M-series with Metal GPU) |
| **Unified Memory / RAM** | **4 GB RAM** (using 1B or 1.5B models) | **8 GB – 16 GB RAM** |
| **Disk Space** | ~2 GB – 5 GB for model weights | SSD storage |

---

## ⚡ Quick Start (Using Ollama — Recommended)

[Ollama](https://ollama.com) is the easiest and fastest way to run open-weight models on macOS. It automatically leverages Apple Silicon Metal GPU acceleration and exposes an OpenAI-compatible REST API.

### Step 1: Install Ollama

Choose either of the two methods:

#### Method A: Download the App
1. Visit [ollama.com/download](https://ollama.com/download) and download the macOS zip.
2. Unzip and drag `Ollama.app` into your `/Applications` folder.
3. Launch Ollama once from Applications (an icon will appear in your macOS menu bar).

#### Method B: Via Homebrew (Terminal)
```bash
brew install ollama
brew services start ollama
```

---

### Step 2: Download a Lightweight Model (Runs on 4 GB RAM)

Open your **Terminal** app and run one of the following commands to download a model:

#### 🌟 Recommended Default: Qwen 2.5 (1.5B)
*Fastest, sharpest reasoning for note structures and flashcard evaluations under 2 GB RAM.*
```bash
ollama run qwen2.5:1.5b
```
*(File size: ~986 MB. Once downloaded, you can type `/bye` to exit the terminal chat; Ollama stays running in the background).*

#### Alternative Models:
- **Llama 3.2 (1B)** (Meta's ultra-compact model, ~1.3 GB):
  ```bash
  ollama run llama3.2:1b
  ```
- **Llama 3.2 (3B)** (Balanced quality and speed, ~2.0 GB):
  ```bash
  ollama run llama3.2:3b
  ```
- **SmolLM2 (1.7B)** (Compact, high efficiency, ~1.0 GB):
  ```bash
  ollama run smollm2:1.7b
  ```
- **Mistral (7B)** (For Macs with 8 GB or 16 GB+ RAM, ~4.1 GB):
  ```bash
  ollama run mistral:7b
  ```

---

### Step 3: Configure Medha

1. Open **Medha** (`Medha.app`).
2. Open the **AI Configuration Sheet**:
   - In the **Notes Editor**: Click the **AI Assistant** button (`✨` sparkles) in the top-right toolbar, then click the **Gear** (`⚙️`) icon.
   - Or in **Flashcards**: Click **AI Socratic Tutor Settings** (`⚙️`).
3. In the Settings Sheet, configure the provider:
   - **Provider**: Select **`Local AI (Ollama / Self-Hosted)`**.
   - **Endpoint URL**: `http://localhost:11434/v1` *(pre-filled by default)*.
   - **Model**: Select `qwen2.5:1.5b` (or type the name of the model you pulled in Step 2).
   - **API Key**: Leave blank (no API key needed for local execution).

---

### Step 4: Enable Free Wikipedia Knowledge Grounding (Optional but Recommended)

Under the **Factual Knowledge Grounding** section in the settings sheet:
- Toggle **`Free Wikipedia Knowledge Grounding`** to **ON**.

> **Why this matters for small models**:
> Models that fit into 4 GB of RAM (like 1.5B or 1B parameters) have limited world trivia baked into their neural weights. When this option is enabled, Medha queries Wikipedia's free public API on the fly for keywords in your notes/cards and injects authoritative facts into the model's prompt. You get the privacy and speed of a tiny local model with the factual accuracy of Wikipedia!

---

### Step 5: Validate the Connection

1. Click the **`Test & Validate Endpoint`** button.
2. Medha will ping `http://localhost:11434/v1` and verify that Ollama is responding.
3. You will see a green checkmark: `✅ Successfully connected to Local AI (Ollama)!`
4. Click **Save Changes** or close the sheet.

---

## 🔀 Dual Configuration (Notes AI vs. Flashcards AI)

Medha allows you to run independent AI configurations:

- **Option A (All Local)**: Keep *"Use same settings for Notes AI"* enabled so both Flashcard Socratic grading and Note hierarchy generation run locally on Ollama.
- **Option B (Hybrid)**: Switch to the **Notes AI** tab in settings and uncheck *"Use same settings for Notes AI"*. You can use a free Google Gemini API key for complex 10-page document synthesis while keeping Flashcard Socratic questioning 100% local on Ollama (or vice versa).

---

## 🖥️ Alternative Local AI Servers

If you prefer a visual GUI model manager instead of terminal commands:

### Using LM Studio
1. Download **LM Studio** from [lmstudio.ai](https://lmstudio.ai).
2. Search and download `Qwen2.5-1.5B-Instruct` or `Llama-3.2-3B-Instruct`.
3. Go to the **Local Server** tab (`<->` icon on the left sidebar).
4. Click **Start Server** (default port is `1234`).
5. In Medha's AI Settings:
   - **Provider**: `Local AI (Ollama / Self-Hosted)`
   - **Endpoint URL**: `http://localhost:1234/v1`
   - **Model**: Match the model selected in LM Studio.

### Using llama.cpp (CLI Server)
```bash
llama-server -m ~/models/qwen2.5-1.5b-instruct.gguf --port 8080 -ngl 99
```
In Medha's AI Settings:
- **Endpoint URL**: `http://localhost:8080/v1`

---

## ❓ Troubleshooting & FAQs

### 1. "Could not reach Local AI at http://localhost:11434/v1"
- **Cause**: Ollama is not running in the background.
- **Fix**: Open the **Ollama** app from your Applications folder or run `ollama serve` in your terminal. You can check if it is active by opening `http://localhost:11434` in Safari.

### 2. "Model 'qwen2.5:1.5b' not found"
- **Cause**: The model weights have not been downloaded yet.
- **Fix**: Run `ollama pull qwen2.5:1.5b` in your terminal. To see which models are currently downloaded, run:
  ```bash
  ollama list
  ```

### 3. Will Local AI drain my laptop battery?
- Small models (1B – 1.5B) execute in quick bursts (typically 0.5 to 2 seconds per note expansion or flashcard question). When not generating text, they consume **0% CPU/GPU**.

### 4. Can I use Local AI without Wi-Fi?
- **Yes, 100%**. If you are on an airplane or offline, Local AI works completely without internet. If Wikipedia Grounding is enabled while offline, Medha will gracefully fall back to pure local inference without any errors.

---

## 📚 Summary of Supported Local Commands

| Command | Purpose |
| :--- | :--- |
| `ollama run qwen2.5:1.5b` | Download and launch the recommended 1.5B model |
| `ollama pull llama3.2:3b` | Download Meta's 3B model without entering chat |
| `ollama list` | List all models installed on your machine |
| `ollama rm <model>` | Remove an unused model to free disk space |
| `ollama serve` | Start the Ollama background daemon manually |
