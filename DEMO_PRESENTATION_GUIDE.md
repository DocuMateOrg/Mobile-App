# DocuMate: Demo Presentation & Deep Technical Architecture Guide

---

## 1. Executive Summary & 30-Second Elevator Pitch

> **"DocuMate** is an intelligent, offline-first personal document digitizer and AI knowledge assistant. Unlike conventional scanner apps that merely take flat, unsearchable pictures, DocuMate combines **native edge-detection scanning**, **on-device neural OCR**, **enterprise-grade CIAM security (Asgardeo by WSO2)**, and **Google Gemini Multimodal AI**. It allows users to scan physical documents, extract text in milliseconds without cloud dependencies, generate clean structured summaries, organize files into folders, chat with their documents via an interactive **Voice AI Assistant**, and export formatted **PDF-1.4 and Word (.docx)** files directly on the device with zero network lag."

---

## 2. High-Level Feature Journey (From Beginning to End)

```
[1. Authentication & Security]
       │ (Asgardeo OIDC / PKCE / Google SSO / SCIM 2.0)
       ▼
[2. Document Ingestion]
       │ (Native Edge Scanner / Camera / Gallery Upload)
       ▼
[3. On-Device Neural OCR]
       │ (Google ML Kit on-device Text Recognition — 100% Offline)
       ▼
[4. Multimodal Generative AI Enrichment]
       │ (Gemini 2.5/3.5 Flash: Summaries, Title & Category Prediction, Visual AI)
       ▼
[5. Local-First Document Management]
       │ (SharedPreferences Negative-ID Cache + PostgreSQL Remote Sync)
       ▼
[6. Interactive DocuMate Voice AI Assistant]
       │ (SpeechToText Dictation, Stop-Word Tokenizer, Gemini Q&A, TTS Readout, SiriWave)
       ▼
[7. Document & Image Editing]
       │ (ImageCropper / UCrop Aspect Ratio & Border Adjustments + Inline Text Editor)
       ▼
[8. Zero-Dependency Native Export]
       │ (Pure-Dart PDF-1.4 Binary Generator with Embedded JPEG + Word HTML .doc)
       ▼
[9. Native OS Intent Launch]
       (OpenFilex Viewer Integration)
```

### Feature Breakdown:
1. **Enterprise Identity & Access Management (CIAM):**
   - User sign-up and password authentication with form validation.
   - Google Single Sign-On (SSO) federated through OAuth 2.0 / OpenID Connect.
   - Self-service password recovery with email OTP verification.
2. **Edge Scanning & Ingestion:**
   - Native document scanner camera with automatic document boundary detection, perspective keystoning rectification, and shadows removal.
   - Batch and single-image import from gallery.
3. **High-Speed On-Device OCR:**
   - Extracts printed and handwritten text locally on the device using ML Kit neural models with zero latency and complete user privacy.
4. **Multimodal Generative AI Intelligence:**
   - Deep structured summaries without markdown hashes or asterisks.
   - Automatic classification into categories (*Receipts, Invoices, Medical, Legal, Academic, Personal, Work*).
   - Visual inspection for image-only documents (diagrams, flowcharts, blueprints) via Gemini Multimodal Vision.
5. **Unified Dashboard & Folder Organization:**
   - Seamless fusion of local offline documents and remote cloud-stored records.
   - Folder creation and document categorization.
   - Keyword and NLP search with token-based query extraction.
6. **Voice AI Assistant & Conversational Chat:**
   - Hands-free natural speech interface with live transcription and Siri-style wave animation.
   - Answers questions by referencing the user's saved documents.
   - Text-to-Speech (TTS) audio readouts and clickable document preview cards.
7. **Document & Photo Editing:**
   - Crop, rotate, flip, and straighten document images.
   - Inline editor for document titles and OCR text content.
8. **Native Format Conversion & Exporting:**
   - Pure-Dart zero-dependency PDF-1.4 engine embedding raw JPEG byte streams.
   - Formatted Word `.doc` generation with styled typography.
   - Automatic document launch in default phone viewers via `OpenFilex`.

---

## 3. Technology Stack & Component Justification

| Technology / Library | Domain | Why It Was Chosen |
| :--- | :--- | :--- |
| **Flutter & Dart 3.x** | Mobile Framework | Cross-platform reactive framework compiling to native ARM machine code; delivers silky-smooth 60fps animations. |
| **Flutter Riverpod 3.x** | State Management | Compile-safe, unidirectional state management; cleanly isolates asynchronous AI tasks and token streams using `AsyncNotifierProvider`. |
| **GoRouter & Navigator 2.0** | Navigation | Declarative routing system providing seamless deep linking, route guards, and transition animations. |
| **Asgardeo (by WSO2)** | Identity & CIAM | Enterprise-grade identity provider supporting OpenID Connect (OIDC), OAuth 2.0 PKCE, SCIM 2.0 user provisioning, and multi-factor authentication. |
| **Google Sign-In & AppAuth** | Social Federation | Industry-standard authorization code exchange with Proof Key for Code Exchange (PKCE). |
| **Google ML Kit Document Scanner** | Computer Vision | Platform-native document scanner with edge detection, contrast optimization, and perspective warping. |
| **Google ML Kit Text Recognition** | On-Device Neural OCR | Ultra-fast on-device neural model; runs directly on phone NPU/GPU with zero latency and 100% offline capability. |
| **Google Generative AI (Gemini 2.5/3.5)** | Generative LLM | State-of-the-art multimodal model with deep reasoning for text summaries, entity extraction, and visual document inspection. |
| **SpeechToText** | Speech Recognition (ASR) | Direct hardware microphone dictation interfacing with the Android `RecognitionService` and iOS Speech frameworks. |
| **FlutterTTS** | Speech Synthesis (TTS) | Operating-system-level text-to-speech engine providing conversational audio playback. |
| **SiriWave** | Audio Visualization | Canvas-rendered iOS-style parametric wave visualizer animated to speech amplitude levels. |
| **ImageCropper & UCrop** | Image Processing | Native platform crop activity for precision cropping, rotation, and aspect ratio locking. |
| **Custom Pure-Dart PDF Engine** | Binary File Generation | Handcrafted PDF-1.4 binary generator with zero third-party dependencies, avoiding library version conflicts. |
| **Node.js, Express & SnapDeploy** | Backend Cloud Layer | Lightweight REST microservice managing metadata sync, cloud image storage, and Asgardeo admin token proxying. |
| **PostgreSQL (Neon Serverless)** | Relational Database | Scalable relational database storing user records, document metadata, and folder hierarchies. |
| **SharedPreferences & PathProvider** | Local Persistence | Local key-value and sandbox filesystem cache powering the offline-first architecture. |
| **OpenFilex** | OS Native Intent | Dispatches operating system view intents to open exported files in external PDF/Word readers. |

---

## 4. System Architecture: From Rough to Deep

### 4.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             FLUTTER MOBILE CLIENT                           │
│                                                                             │
│  UI Layer: Modern Material Design + Google Fonts (Poppins)                 │
│  State: Riverpod Providers (Auth, OCR, Gemini, Documents, Folders)         │
│  Sensors & Hardware: Camera, Microphone, NPU OCR, SiriWave, Image Cropper   │
│  Local Cache: SharedPreferences (Offline JSON Store) + Sandboxed Storage    │
└──────────────┬─────────────────────────┬──────────────────────────┬─────────┘
               │ (1) OIDC / PKCE / SCIM  │ (2) Multimodal Payloads  │ (3) REST Sync
               ▼                         ▼                          ▼
     ┌───────────────────┐    ┌────────────────────┐    ┌─────────────────────┐
     │   ASGARDEO CIAM   │    │  GOOGLE GEMINI AI  │    │   NODE.JS BACKEND   │
     │  (WSO2 Identity)  │    │  (Generative AI)   │    │  (SnapDeploy Cloud) │
     └─────────┬─────────┘    └────────────────────┘    └──────────┬──────────┘
               │ (M2M Admin Proxy)                                 │ (SQL)
               └───────────────────────────┬───────────────────────┘
                                           ▼
                                 ┌───────────────────┐
                                 │   POSTGRESQL DB   │
                                 │   (Cloud Neon)    │
                                 └───────────────────┘
```

---

### 4.2 Deep Dive: Communication Pipelines

#### Pipeline A: Authentication & Security Flow
```
User Credentials ──▶ Flutter App ──▶ Node.js Backend Proxy
                                           │
                                           ├─▶ [M2M Token Grant: Client Credentials]
                                           ▼
                                  Asgardeo SCIM 2.0 (/scim2/Users)
                                           │
                                           ▼ (User Provisioned)
                                  Asgardeo OIDC Token Endpoint
                                           │
                                           ▼
                                  Flutter Secure Session Store
```
1. **Interactive Manual Registration:** User enters credentials in the mobile app. The payload is sent to the Node.js backend.
2. **M2M Administrative Proxying:** The backend performs an OAuth 2.0 Client Credentials Grant to obtain an administrative bearer token from Asgardeo (`https://api.asgardeo.io/t/{ORG}/oauth2/token`).
3. **SCIM 2.0 Directory Creation:** The backend calls Asgardeo's SCIM 2.0 endpoint (`/scim2/Users`) to provision the user account securely.
4. **Social Federation:** For Google Login, `flutter_appauth` and `google_sign_in` exchange authorization codes with Asgardeo via PKCE, returning an ID token and access token stored in `UserSession`.

---

#### Pipeline B: Edge Scanning & Instant On-Device OCR
```
Physical Paper ──▶ Camera Viewfinder ──▶ ML Kit Edge Detection ──▶ Perspective Correction
                                                                          │
                                                                          ▼
                                                                Raw JPEG Scanned File
                                                                          │
                                                                          ▼
                                                                ML Kit Text Recognition
                                                                          │
                                                                          ▼
                                                                  Extracted Text String
                                                                (Zero Latency / Offline)
```
1. `google_mlkit_document_scanner` engages the phone camera. Native real-time computer vision shaders detect page corners.
2. Upon shutter click, projective transform algorithms correct distortion, remove glare, and output a clean JPEG.
3. The image is passed to `google_mlkit_text_recognition`. The on-device neural network detects text blocks, lines, and elements locally on the phone's hardware—operating with zero cloud cost and 100% offline capability.

---

#### Pipeline C: Multimodal AI Intelligence (Gemini)
```
Extracted Text + Image Bytes ──▶ Riverpod State Notifier (analyzeDocument)
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    ▼ (Has Text)                                        ▼ (Visual Only)
       [Concurrent Dual Queries]                            [_optimizeImageForVision]
        ├─▶ 1. Deep Structured Summary                                  │
        └─▶ 2. Title & Category Extraction                              ▼
                    │                                        [Multimodal Gemini Vision]
                    └─────────────────────────┬─────────────────────────┘
                                              ▼
                           [Multi-Model Fallback Waterfall]
                           gemini-2.5-flash ──▶ gemini-3.5-flash
                           gemini-flash-latest ──▶ gemini-3.5-flash-lite
                                              │
                                              ▼
                           [cleanSummaryText Post-Processing]
                           (Removes markdown hashes, asterisks & notes)
```
1. If text is extracted, `GeminiService` dispatches two concurrent queries:
   - **Structured Summary Prompt:** Enforces strict formatting rules: starts with `OVERVIEW:`, uses clean unicode bullets (`•`), and completely excludes markdown asterisks (`*`) and hash headers (`#`).
   - **Metadata Extraction Prompt:** Classifies the document into a standard category (*Receipts, Invoices, Medical, Legal, Academic, Personal, Work*) and generates a clean title.
2. If no text is detected (e.g., photo, diagram, sketch), `_optimizeImageForVision` resizes the image to 1200px and dispatches a multipart JPEG payload to Gemini Vision to analyze and explain the visual contents.
3. **Multi-Model Fallback Waterfall:** To guarantee 99.9% uptime, if a model times out or encounters rate limits, the client falls back through candidate models in milliseconds:
   `gemini-2.5-flash` $\rightarrow$ `gemini-3.5-flash` $\rightarrow$ `gemini-flash-latest` $\rightarrow$ `gemini-3.5-flash-lite`.

---

#### Pipeline D: Offline-First Dual-Layer Storage
```
Document Created ──▶ Assign Negative ID (e.g. -548496)
                           │
                           ├─▶ Write to SharedPreferences JSON Store (Instant Local Availability)
                           │
                           ▼ (Background Sync When Online)
                   Node.js Backend (/api/documents)
                           │
                           ▼
                   PostgreSQL Neon Database (Positive Remote ID Assigned)
```
1. Scanned documents are assigned a local negative timestamp ID (e.g., `-548496`) and stored in `SharedPreferences`.
2. When browsing the dashboard or searching, local documents are loaded instantly with zero network delay.
3. When connected to the internet, background sync uploads document metadata and images to the PostgreSQL cloud database.

---

#### Pipeline E: The DocuMate Voice AI Assistant
```
User Speaks ──▶ SpeechToText (ASR) ──▶ Stop-Word Tokenizer (extractSearchTokens)
                      │
                      ▼
         [Query Local & Remote Docs]
                      │
                      ▼
         [Compile Document Context] + [User Question]
                      │
                      ▼
              Gemini AI Engine
                      │
                      ├─▶ 1. Spoken Answer ──▶ FlutterTTS Readout + SiriWave Visualizer
                      │
                      └─▶ 2. Matched Documents ──▶ Interactive Clickable Cards
                                                              │
                                                              ▼
                                                   DocumentDetailScreen
```
1. User taps the microphone. `permission_handler` ensures microphone permission is active.
2. `SpeechToText` connects to Android's native `RecognitionService` (declared in `AndroidManifest.xml`). Real-time speech words update the screen while `SiriWave` animates in sync with audio amplitude.
3. When speech stops, `LocalDocumentService.extractSearchTokens` removes filler words (*"find"*, *"search"*, *"where is"*), isolating keywords (*"electricity"*, *"receipt"*).
4. Local and cloud documents are searched. The top matching documents are compiled as contextual grounding data and sent to Gemini with the user's question.
5. Gemini generates a conversational, natural response:
   - Read aloud via `FlutterTTS`.
   - Displays interactive document cards allowing the user to open any matching file with a single tap.

---

#### Pipeline F: Zero-Dependency Binary PDF & Word Exporter
```
Document Data (Title, Scanned JPEG Bytes, Formatted Text)
                           │
                           ▼
        [LocalExportService Pure-Dart Engine]
        ├─▶ Embed JPEG stream directly via /Filter /DCTDecode
        ├─▶ Construct /Type1 /Helvetica Font & WinAnsi character tables
        ├─▶ Calculate vector coordinates & 78-char word-wrapped text
        └─▶ Compute exact 20-byte xref table & trailer offsets
                           │
                           ▼
               Standard PDF-1.4 File (.pdf)
                           │
                           ▼
         OpenFilex (Native OS View Intent Launched)
```
1. **The Conflict Problem:** Traditional PDF packages (`pdf`) pull heavy dependencies (`image`, `archive`) that conflict with camera and image libraries (`ZLibDecoder.decodeLazy` error).
2. **The Pure-Dart Solution:** [LocalExportService](file:///f:/documate/lib/services/local_export_service.dart) builds standard PDF-1.4 binaries using Dart's core `Uint8List` and `BytesBuilder`:
   - Builds object trees: Catalog (`1 0 obj`), Page Tree (`2 0 obj`), Page Object (`3 0 obj`), Font Descriptor (`4 0 obj`), Image Stream (`5 0 obj`), Content Stream (`6 0 obj`).
   - Injects JPEG image bytes into the PDF stream using `/Filter /DCTDecode` without costly decoding or re-encoding.
   - Wraps text at 78 characters and sanitizes characters for WinAnsi encoding.
   - Computes exact 20-byte cross-reference (`xref`) offsets and appends `trailer` and `%%EOF`.
3. Opens the resulting file directly in the device's native PDF/Word reader via `OpenFilex`.

---

## 5. 5-Minute Live Demo Presentation Script

Use this script during live demonstrations to deliver a compelling presentation:

### Minute 1: The Problem & Vision
> *"Good morning/afternoon everyone. Today, physical documents still dominate our personal and professional lives—bills, medical records, receipts, and contracts. Most mobile scanners are simply digital photocopiers: they produce unsearchable pictures that get lost in folders.
> 
> We built **DocuMate**—an intelligent, offline-first personal knowledge digitizer. DocuMate doesn't just store documents; it understands them, answers questions about them, and lets you interact with them naturally through voice."*

### Minute 2: Enterprise Security & Seamless Scanning
*(Show Login screen and tap Scan)*
> *"Security is central to DocuMate. We integrated enterprise CIAM using **Asgardeo by WSO2**, supporting OAuth 2.0 PKCE, Google federated Single Sign-On, and automated account recovery.
> 
> Let's digitize a document. Notice how our scanner automatically identifies document borders, rectifies perspective distortion, and cleans up contrast. Instantly, on-device neural OCR extracts all text without sending a single byte to the cloud."*

### Minute 3: Multimodal Generative AI (Gemini)
*(Show the Result Screen with Summary)*
> *"Here is where Gemini AI takes over. DocuMate automatically generates a clean, structured summary with key takeaways and figures, categorizes the file, and predicts a title.
> 
> And what if a user scans a diagram, flowchart, or blueprint with no text? Our multimodal pipeline automatically switches to Gemini Vision to describe the visual structures and diagrams directly."*

### Minute 4: The Voice AI Assistant in Action
*(Go to Dashboard and tap the Microphone icon)*
> *"Let's test our interactive Voice Assistant. I'll tap the microphone and ask:
> **'How much was my recent electricity bill?'**
> 
> Notice what happened:
> 1. Speech was captured in real-time with our SiriWave visualizer.
> 2. The app stripped filler words, located matching documents, and fed them to Gemini.
> 3. The assistant answered concisely, spoke the answer aloud using Text-to-Speech, and gave me an interactive document card to open the bill directly."*

### Minute 5: Edit, Convert & Zero-Dependency Export
*(Tap the Convert icon on the dashboard and export to PDF)*
> *"Finally, look at our Quick Actions. Tapping **Edit** allows us to rotate and crop document borders or modify text inline. Tapping **Convert** exports our document to PDF or Word.
> 
> Because we engineered a custom, pure-Dart PDF-1.4 binary generator, export is instantaneous, 100% offline, and opens immediately in the phone's native viewer.
> 
> That is DocuMate: fast, secure, intelligent, and private. Thank you!"*

---

## 6. Evaluator Q&A Preparation (Tough Questions & Answers)

**Q1: Why did you choose Google ML Kit for OCR instead of doing OCR with Gemini or a cloud API?**
> **Answer:** *"Privacy and speed. ML Kit runs on the device's NPU/GPU with zero latency and zero data cost. It works completely offline, ensuring personal financial and medical documents are extracted securely on-device before any optional AI enrichment."*

**Q2: What happens if the phone is offline or in airplane mode?**
> **Answer:** *"DocuMate is built offline-first. Scanning, ML Kit OCR, local document storage (with negative ID timestamps), image editing, and pure-Dart PDF/Word export all work 100% offline. When internet is restored, documents sync to the PostgreSQL cloud database and Gemini enrichment becomes active."*

**Q3: How do you handle Gemini API rate limits or network hiccups?**
> **Answer:** *"We built an automatic multi-model waterfall architecture. If `gemini-2.5-flash` encounters a spike or rate limit, the client automatically falls back through `gemini-3.5-flash`, `gemini-flash-latest`, and `gemini-3.5-flash-lite` within milliseconds without failing the user's request."*

**Q4: Why did you build a custom PDF generator instead of using popular Flutter packages?**
> **Answer:** *"Popular Flutter PDF packages pull transitive dependencies like `archive` and `image` that frequently cause version conflicts with camera packages (such as the `ZLibDecoder.decodeLazy` error). By implementing standard PDF-1.4 binary primitives and `/Filter /DCTDecode` directly in pure Dart, we achieved zero external dependencies, smaller APK size, and lightning-fast local exports."*

**Q5: How does Asgardeo enhance the security of this application?**
> **Answer:** *"Asgardeo by WSO2 provides centralized, enterprise-grade Identity and Access Management. Rather than managing passwords in an unvetted local database, we use OAuth 2.0 with PKCE authorization code exchange, SCIM 2.0 user directory management, and Google SSO federation, complying with modern zero-trust standards."*
