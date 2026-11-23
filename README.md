<p align="center">
  <img src="assets/icons/chowgenie_app_icon.png" width="140" alt="ChowGenie App Icon" />
</p>

<h1 align="center">ChowGenie Hybrid AI</h1>

<p align="center">
  <strong>Offline-First Smart Kitchen Companion Powered by Firebase AI Logic Hybrid Inference</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Firebase_AI_Logic-Hybrid_Inference-FFA000?style=for-the-badge&logo=firebase" alt="Firebase AI Logic" />
  <img src="https://img.shields.io/badge/Gemini_Nano-On--Device_AICore-4285F4?style=for-the-badge&logo=google-gemini" alt="Gemini Nano" />
  <img src="https://img.shields.io/badge/Gemini_3.8_Flash-Cloud_Fallback-34A853?style=for-the-badge&logo=google" alt="Gemini Flash" />
  <img src="https://img.shields.io/badge/Flutter-3.24%2B-02569B?style=for-the-badge&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Web-3DDC84?style=for-the-badge&logo=android" alt="Android & Web" />
  <img src="https://img.shields.io/badge/IDE-Google_Antigravity-8E24AA?style=for-the-badge" alt="Google Antigravity" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License" />
</p>

---

## 🏆 #BuildHybridAI 2026 Hackathon Submission

ChowGenie Hybrid AI is built for Google's **#BuildHybridAI 2026** competition. It implements a multi-platform **Firebase AI Logic Hybrid Inference** engine combining:
1. **⚡ On-Device Gemini Nano**: Sub-second, zero-cost, privacy-preserving AI running locally via Android AICore & Chrome Desktop Prompt API for instant pan-side cooking advice, offline ingredient swaps, and smart pantry inventory queries.
2. **☁️ Cloud Gemini 3.8 Flash**: Dynamic cloud fallback for complex 7-day nutritional planning, heavy multimodal ingredient vision, and automated synchronization across Cloud Firestore.
3. **🛡️ Firebase App Check & Security**: Gated via App Check (with pre-seeded Debug Token `e4b3c2a1-5678-4901-abcd-ef0123456789` for judges) to ensure protected client execution.
4. **🎛️ Firebase Remote Config & Auth**: Real-time prompt parameter tuning (`PREFER_ON_DEVICE`) and zero-friction anonymous authentication.

> [!NOTE]
> **For Hackathon Judges & Evaluators:**
> In compliance with submission requirements (*"Firebase AI Logic requires App Check; debug tokens are accepted in submissions"*), the app automatically injects and registers the debug token:
> `e4b3c2a1-5678-4901-abcd-ef0123456789`
> Cloud fallback executes seamlessly on any test device or emulator out of the box.

---

## 🚀 Existing App Upgrade Delta (Hackathon Period)

In accordance with official hackathon rules for existing projects, the table below documents the major architectural and runtime additions built during the competition:

| Capability | Prior Version | #BuildHybridAI 2026 Upgrade |
| :--- | :--- | :--- |
| **AI Inference** | Heavy local model (~2.7GB Hugging Face download block) | **Firebase AI Logic Hybrid SDK** (Gemini Nano local + Gemini 3.8 Flash Cloud cascade) |
| **Android Integration** | Basic Flutter activity | **Native Kotlin Bridge** (`MainActivity.kt`) importing `com.google.firebase:firebase-ai` & `firebase-ai-ondevice` |
| **Web Platform** | Desktop/mobile only | **Multi-Platform Web Support** (Chrome Desktop Gemini Nano Prompt API interop) |
| **Security Gate** | None | **Firebase App Check** (`DebugAppCheckProviderFactory` configured) |
| **Prompt Tuning** | Hardcoded strings | **Firebase Remote Config** (dynamic `ai_routing_mode` & prompt templates) |
| **Offline Library** | Remote API dependency | **Instant Tier-3 SQLite Fallback** (73,322 offline recipes with zero-latency local fallback) |
| **Pantry Intake** | Manual typing only | **Receipt Scanner $\rightarrow$ Auto-Pantry** (Multimodal Gemini 3.8 Flash auto-extracting items & shelf-life) |
| **Recipe Adaptation** | Static recipes | **One-Tap Recipe Transforms & Scaler** (Gemini Nano on-device: Vegan, High-Protein, Budget + dynamic scaler) |
| **Cooking Guidance** | Static step text | **Embedded Smart Cooking Timers** (Regex duration detection, circular countdown ring, audio-haptic alerts) |
| **Grocery Planning** | Manual list entry | **Smart Missing-Item Grocery Sync** (Cross-checks 7-day meal plan against active pantry stock) |
| **Autonomous Agent** | None (Passive chat only) | **Autonomous Kitchen Agent Dispatcher** (Gemini Nano tool calling across Voice & Chat: timers, groceries, pantry, meal slots) |

---

## 🧠 System Architecture & Hybrid Flow

```mermaid
flowchart TD
    User([Chef / User Action]) --> UI[Flutter Material 3 Layer]
    UI --> ModelMgr[ModelManager Singleton]
    ModelMgr --> HybridSvc[HybridAiService Layer]

    subgraph PlatformRouting["Platform Dispatch"]
        HybridSvc -->|Android| MethodChan["MethodChannel: com.example.chow_genie/hybrid_ai"]
        HybridSvc -->|Web| WebInterop["Chrome Prompt API (JS Interop)"]
    end

    subgraph NativeAndroid["Android Native Layer (MainActivity.kt)"]
        MethodChan --> KotlinBridge[Kotlin Method Call Handler]
        KotlinBridge --> FirebaseAI["Firebase.ai(GenerativeBackend.googleAI())"]
        FirebaseAI --> RoutingPolicy{"InferenceMode.PREFER_ON_DEVICE"}
        
        RoutingPolicy -->|AICore Compatible| LocalNano["⚡ On-Device Gemini Nano (<200ms)"]
        RoutingPolicy -->|Unsupported / Cloud Fallback| CloudFlash["☁️ Cloud Gemini 3.8 Flash Fallback Cascade"]
    end

    subgraph FirebaseSecurity["Firebase Cloud Ecosystem"]
        AppCheck["Firebase App Check (Debug Token Gate)"] -.-> CloudFlash
        RemoteConfig["Firebase Remote Config (Dynamic Rules)"] -.-> KotlinBridge
    end

    LocalNano --> ResultReturn[Result Map + Latency Measurement]
    CloudFlash --> ResultReturn
    WebInterop --> ResultReturn
    ResultReturn --> BadgeDisplay["UI Update with Real-Time HybridAiBadge"]
```

---

## 📱 Offline vs. Online Division of Labor

| Action | Execution Tier | Latency | Why |
| :--- | :--- | :--- | :--- |
| **Pan-Side Cooking Q&A** | ⚡ On-Device | `<200ms` | Instant response while stirring a pan; works in kitchen Wi-Fi dead zones. |
| **Emergency Ingredient Swap** | ⚡ On-Device | `<150ms` | Zero lag when missing eggs or buttermilk. |
| **Smart Pantry Inventory** | ⚡ On-Device | `<250ms` | Complete privacy; home groceries remain on-device. |
| **Voice Hands-Free Cooking** | ⚡ On-Device | `<300ms` | Device-native Speech-to-Text with local Nano step progression. |
| **One-Tap Recipe Transforms** | ⚡ On-Device | `<250ms` | Instant dietary adaptation (Vegan, High-Protein, Budget) on Gemini Nano. |
| **Smart Cooking Timers** | ⚡ On-Device | Instant | In-app countdown ring, duration presets, and audio-haptic alerts without internet. |
| **Receipt Scanner $\rightarrow$ Auto-Pantry** | ☁️ Cloud Fallback | ~950ms | Dense multimodal OCR and shelf-life prediction using Gemini 3.8 Flash. |
| **Meal Plan Grocery Cross-Check** | ⚡ On-Device | Instant | Local SQLite cross-referencing between scheduled meals and pantry stock. |
| **7-Day Meal Plan Optimization** | ☁️ Cloud Fallback | ~800ms | Multi-parameter reasoning across 21 meals, calories, and macros. |
| **Packaging Safety Scanner** | ☁️ Cloud Fallback | ~900ms | High-resolution multimodal analysis of complex ingredient warning labels. |
| **Peer-to-Peer Recipe Mesh** | ⚡ On-Device | Instant | Direct local Wi-Fi / Hotspot UDP multicast recipe card sharing. |
| **Offline Library Fallback** | ⚡ On-Device | Instant | 73,322 SQLite recipes provide instant answers when offline or under high quota load. |

---

## 💻 Running the Project

### Prerequisites
- Flutter SDK (3.24+)
- Android device / emulator or Google Chrome

```bash
flutter pub get
```

### 1. Run on Android
```bash
flutter run
```

### 2. Run on Web (Chrome Desktop)
```bash
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```

---

## 📜 License & Credits

- **License**: Released under the open-source **MIT License** (see [`LICENSE`](LICENSE)).
- **Recipe Dataset**: Adapted from [dpapathanasiou/recipes](https://github.com/dpapathanasiou/recipes).
- **Google AI & Firebase**: Powered by Firebase AI Logic, Gemini Nano, and Gemini Flash.
