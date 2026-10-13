# Medhara Development Guidelines & Rules

## Platform Implementation Priority

- **Default Target Platform (macOS First)**:
  - Whenever a new feature, improvement, or architectural change is requested, it **must always be implemented for macOS (Mac) first**.
  - Do **not** implement features for Windows, Android, or Web unless explicitly requested or mentioned.
- **Ambiguity & Clarification**:
  - If a feature request is ambiguous regarding target platform scope, or if the requirements are not clear, always ask for clarification before proceeding.

## Feature Research & Grounding (Inspirations & Sources)

- **Mandatory Source/Inspiration Verification**:
  - Whenever a feature request references an external inspiration, source, or reference app (e.g., "formatting tools like Google Docs", "Obsidian-style backlinks", "Notion-like slash commands", etc.):
    - Do **not** rely solely on internal model memory or assumptions based on the prompt description alone.
    - The agent **must actively research and check the real-world source** (via web searches, official documentation, or inspecting the actual tool's UX, features, and behaviors) before planning or coding.
  - Features must match the actual patterns, workflows, and standards of the referenced source rather than guessing.
