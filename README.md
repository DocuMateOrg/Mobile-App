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
3. Start the database container:
  docker-compose up -d
  (Note: This database runs on port 5432 with the password password123. If you already have PostgreSQL installed on Windows running on 5432, you will need to stop that Windows service first, or update the ports).

### Step 2: Start the Node.js Backend
Keep your terminal in the backend folder.

1. Install the required dependencies (you only need to do this the first time):
  npm install
2. Start the Express server:
  node server.js

✅ Success Check: You should see 🚀 DocuMate Backend running at http://0.0.0.0:3000 and ✅ Database table ready. Leave this terminal running!

### Step 3: Configure the Flutter App's IP Address (Crucial)
Because the app runs on a physical phone or emulator, it needs to know your computer's exact Wi-Fi IP address to talk to the Node server.

1. Find your computer's IPv4 address:

  - Windows: Open Command Prompt and type ipconfig
  - Mac: Open Terminal and type ifconfig | grep inet
2. Open the Flutter project in VS Code and go to: lib/features/scanner/api_service.dart.
3. Update the baseUrl variable to match your exact IP address:
  final String baseUrl = "[http://192.168.1.100:3000/api](http://192.168.1.100:3000/api)";

### Step 4: Run the Flutter App
Open a new terminal at the root of the Flutter project (do not close the backend terminal).

1. Get the Flutter packages:
  flutter pub get
2. Run the app on your connected device or emulator:
  flutter run