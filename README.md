# DocuMate 📄

DocuMate is a full-stack document scanning and management mobile application. It allows users to scan physical documents, extract text using ML Kit (OCR), and save the images and metadata securely.

## 🏗️ Tech Stack
* **Frontend:** Flutter & Dart
* **Backend:** Node.js & Express
* **Database:** PostgreSQL (Containerized via Docker)
* **Authentication:** Firebase Auth
* **ML/AI:** Google ML Kit (Text Recognition)

---

## 🚀 Getting Started for Developers

Because this is a full-stack app, you need to run **both** the backend server and the Flutter frontend for the app to work locally. Follow these steps exactly.

### Prerequisites
Before you begin, ensure you have the following installed on your machine:
1. [Flutter SDK](https://docs.flutter.dev/get-started/install)
2. [Node.js](https://nodejs.org/) (v16 or higher)
3. [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Recommended to run the database easily without local installation)

---

### Step 1: Start the Database (Docker)
Instead of manually installing PostgreSQL, we use Docker to spin up a pre-configured database instantly. 

1. Open Docker Desktop and make sure the engine is running.
2. Open a terminal and navigate to the backend folder:
   ```bash
   cd backend