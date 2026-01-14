# MockMate 🎯
### Master Your Interview Skills with AI-Powered Intelligence

**MockMate** is a cutting-edge mobile application designed to bridge the gap between candidate preparation and real-world interview success. By combining **Google Gemini 2.5 Flash** for deep linguistic analysis and **Google ML Kit** for real-time behavioral tracking, MockMate provides a comprehensive, 360-degree feedback loop for any role you're targeting.

---

## 🚀 Key Features

### 1. Hybrid Intelligence Engine 🧠
- **Role-Based Simulation:** AI generates realistic, challenging questions tailored to any job title.
- **JD Processing:** Paste a specific Job Description to get hyper-focused, contextual questions that mirror the requirements of your target company.

### 2. Behavioral Biometrics (Real-Time Tracking) 👁️
Using high-performance computer vision, MockMate tracks:
- **Eye Contact:** Active monitoring of camera engagement.
- **Micro-movements:** Analysis of head stability (Yaw/Roll) to assess professional confidence.
- **Facial Affect:** Real-time smile and expression probability detection.
- **Presence:** Ensures consistent framing and professional posture.

### 3. Linguistic & Content Analytics ✍️
- **AI Transcription:** Instant, high-accuracy speech-to-text breakdown of your answers.
- **Filler Word Analytics:** Quantifies "ums," "uhs," and "likes" to improve speech fluency.
- **Sentiment Profiling:** Detects the tone and "vibe" of your response (Confident, Enthusiastic, Hesitant).

### 4. Direct Coaching & Insights 📊
- **The Scorecard:** A weighted performance score (0-100) combining physical cues and content quality.
- **Targeted Feedback:** Provides exactly 5 actionable, high-priority coaching tips after every session.
- **History Vault:** Track your progress over time with a comprehensive archive of all past sessions.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (Cross-platform performance)
- **AI Engine:** [Google Gemini 2.5 Flash](https://deepmind.google/technologies/gemini/) (Question generation & content analysis)
- **Computer Vision:** [Google ML Kit](https://developers.google.com/ml-kit) (Real-time face and pose detection)
- **Data Visualization:** [FL Chart](https://pub.dev/packages/fl_chart) (Professional performance metrics)
- **Storage:** Shared Preferences & Local File System

---

## ⚙️ Getting Started

### Prerequisites
- Flutter SDK (>= 3.0.0)
- A Gemini API Key from [Google AI Studio](https://aistudio.google.com/)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vatsal-agra/MockMate.git
   cd MockMate/mock
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Set up Environment Variables:**
   For production analysis, define your Gemini API key:
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your_actual_key_here
   ```

4. **Launch the App:**
   ```bash
   flutter run
   ```

---

## 🗺️ Roadmap
- [ ] **Multi-turn Interviews:** Interactive follow-up questions from the AI.
- [ ] **Coding Interview Mode:** Whiteboarding simulation integrated with voice.
- [ ] **AR Coaching:** Real-time visual overlays during recording for posture correction.
- [ ] **Resume Scanner:** Directly generate questions from your resume PDF.

---

## 📄 License
Distributed under the MIT License. See `LICENSE` for more information.

---
**MockMate** — *Turning interview anxiety into objective performance data.*
