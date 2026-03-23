# =============================================
# JARVIS — Full Git Commit History Setup
# Run these commands in order in your terminal
# inside the D:\Data\Projects\Jarvis folder
# =============================================


# STEP 1 — Initialize git (only if not already done)
git init


# STEP 2 — Set your identity (only needed once ever)
git config user.name "Your Name"
git config user.email "your@email.com"


# =============================================
# COMMIT 1 — Project scaffold
# =============================================
git add pubspec.yaml lib/main.dart
git commit -m "feat: init Flutter Jarvis app with dark theme"


# =============================================
# COMMIT 2 — Chat UI
# =============================================
git add lib/main.dart
git commit -m "feat: add chat UI with message bubbles and input bar"


# =============================================
# COMMIT 3 — Python backend
# =============================================
git add server.py requirements.txt
git commit -m "feat: add FastAPI backend with Groq + Llama integration"


# =============================================
# COMMIT 4 — Environment setup
# =============================================
git add .gitignore .env.example
git commit -m "chore: add .gitignore and .env.example for safe secrets handling"


# =============================================
# COMMIT 5 — Speech to text
# =============================================
git add lib/main.dart pubspec.yaml
git commit -m "feat: integrate speech_to_text for voice input"


# =============================================
# COMMIT 6 — Backend fixes
# =============================================
git add server.py
git commit -m "fix: add CORS middleware and conversation memory to backend"


# =============================================
# COMMIT 7 — Device connection fix
# =============================================
git add lib/main.dart
git commit -m "fix: switch backend URL from emulator to real device IP"


# =============================================
# COMMIT 8 — Bug fixes
# =============================================
git add lib/main.dart
git commit -m "fix: remove duplicate onStatus handler and add mounted checks"


# =============================================
# COMMIT 9 — Text to speech
# =============================================
git add lib/main.dart pubspec.yaml android/settings.gradle android/build.gradle
git commit -m "feat: add flutter_tts so Jarvis speaks replies out loud"


# =============================================
# COMMIT 10 — Kotlin version fix
# =============================================
git add android/settings.gradle android/build.gradle
git commit -m "fix: bump Kotlin to 1.9.10 in settings.gradle for flutter_tts compatibility"


# =============================================
# COMMIT 11 — dotenv for backend
# =============================================
git add server.py
git commit -m "chore: load GROQ_API_KEY from .env using python-dotenv"


# =============================================
# PUSH to GitHub
# =============================================
# 1. Create a new repo on github.com (do NOT add README or .gitignore there)
# 2. Then run:

git remote add origin https://github.com/YOUR_USERNAME/jarvis.git
git branch -M main
git push -u origin main


# =============================================
# VERIFY nothing secret was committed
# =============================================
# Check what files are tracked:
git ls-files

# Check your .env is NOT in the list above
# If it is, remove it immediately:
# git rm --cached .env
# git commit -m "chore: remove .env from tracking"
