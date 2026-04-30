# Overview

**Go4** is a comprehensive, multimodal retail guide mobile application designed to enhance the shopping experience through artificial intelligence[cite: 1]. The system utilizes advanced AI models and a robust full-stack architecture to provide users with intelligent product searching, personalized recommendations, and real-time mapping capabilities[cite: 1].

The application is split into a scalable, containerized backend and a cross-platform mobile frontend, ensuring a seamless and responsive user experience across both Android and iOS devices[cite: 1].

## Architecture & Infrastructure

The project follows a decoupled client-server architecture, prioritizing modularity and scalable deployment[cite: 1]:

* **Backend API:** A Node.js application responsible for handling core business logic, user authentication, and third-party API integrations[cite: 1].
* **Cross-Platform Client:** A Flutter-based mobile application that consumes the backend services and handles complex UI states across various feature modules[cite: 1].
* **Containerization:** The entire backend ecosystem is orchestrated using Docker, with both standard (`docker-compose.yml`) and production-ready (`docker-compose.prod.yml`) configurations ensuring consistent deployment environments[cite: 1].
* **CI/CD Pipeline:** Automated workflows for deployment and APK release generation are managed via GitHub Actions (`deploy.yml`, `release-apk.yml`)[cite: 1].

## Tech Stack


| Layer                    | Technology                                         |
| :----------------------- | :------------------------------------------------- |
| **Frontend**             | Flutter (Dart), targeting Android and iOS[cite: 1] |
| **Backend**              | Node.js (REST API architecture)[cite: 1]           |
| **AI & Search Services** | Gemini API, Serper API[cite: 1]                    |
| **DevOps**               | Docker, GitHub Actions[cite: 1]                    |

## Core Features

Based on the application's underlying architecture, Go4 delivers several key functionalities:

* **Multimodal AI Integration:** The backend features dedicated services for Gemini API integration (`geminiService.js`, `geminiEnrichService.js`, `geminiFilterService.js`) to process complex user queries and intelligently filter results[cite: 1]. Additionally, a `transcriptionService.js` indicates support for voice-based or audio-driven input[cite: 1].
* **Intelligent Search & Discovery:** The application leverages the Serper API (`serperService.js`) alongside custom search routes (`search.js`) and product endpoints (`product.js`) to locate items efficiently[cite: 1].
* **Personalization Engine:** A dedicated `preferenceLearningService.js` on the backend works in tandem with user preference models to deliver tailored content via the recommendations route (`recommendations.js`) and frontend screens (`recommendations_screen.dart`)[cite: 1].
* **Location & Mapping:** Users can visualize places and retail locations through the backend `places.js` route, rendered on the frontend via an interactive Map module (`map_screen.dart`)[cite: 1].
* **User Management & State:** The frontend utilizes comprehensive provider patterns (`auth_provider.dart`, `search_provider.dart`, `wishlist_provider.dart`) to manage user profiles, authentication, search histories, and personal wishlists seamlessly[cite: 1].

## File Structure Highlights

The repository maintains a clean separation of concerns, heavily utilizing modular structures for both the frontend and backend[cite: 1]:

```text
Go4-Group-Project/
├── backend/                    ← Node.js API Service
│   ├── Dockerfile              ← Backend container definition
│   ├── middleware/             ← Request interceptors (e.g., auth.js)
│   ├── models/                 ← Data schemas (User, SearchHistory, UserPreferences)
│   ├── routes/                 ← API endpoints (auth, analyze, product, places)
│   └── services/               ← Core AI logic (Gemini, Serper, Transcription)
│
├── frontend/                   ← Flutter Mobile App
│   ├── android/ & ios/         ← Native platform configurations
│   ├── lib/
│   │   ├── core/               ← API clients, routing, and theme utilities
│   │   ├── features/           ← UI Modules (home, map, profile, wishlist, results)
│   │   ├── models/             ← Dart data classes (product, search_tag, history_item)
│   │   └── providers/          ← Application state management
│   └── pubspec.yaml            ← Flutter dependencies
│
├── docker-compose.yml          ← Development orchestration
└── .github/workflows/          ← CI/CD automation pipelines
```
