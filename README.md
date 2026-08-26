# CarbonEye: Real-Time Deforestation Monitoring Platform

**Eyes on the forest. Always.**

CarbonEye is a powerful tool designed to provide real-time intelligence on deforestation activities across the globe

The platform consists of three main parts:

* **A powerful backend** built with Python and FastAPI, responsible for the heavy lifting of fetching and analyzing satellite data.
* **A cross-platform frontend application** built with Flutter, providing a rich, interactive user experience for analysis on mobile (iOS/Android) and the web.

## Full-Stack Architecture

The CarbonEye platform is built on a modern, decoupled architecture. The clients communicate with the backend via a REST API, allowing for independent development, deployment, and scaling of each component.

```mermaid
flowchart TB
    %% === Define Styles ===
    classDef user fill:#08427b,stroke:#002a52,stroke-width:2px,color:white
    classDef service fill:#1168bd,stroke:#0b4884,stroke-width:2px,color:white
    classDef core fill:#4f46e5,stroke:#3730a3,stroke-width:2px,color:white
    classDef external fill:#6b7280,stroke:#4b5563,stroke-width:2px,color:white

    %% === User App ===
    FlutterApp["Flutter App (iOS / Android)"]
    class FlutterApp user

    %% === CarbonEye Backend ===
    subgraph BE["CarbonEye Backend"]
        direction TB

        APIGateway["API Gateway (Flask)<br><sub>Handles all incoming requests</sub>"]
        AnalysisService["Analysis Service<br><sub>Orchestrates deforestation analysis</sub>"]
        ImageProcessor["Image Processing<br><sub>NDVI, change detection, severity</sub>"]
        SatelliteProvider["Satellite Provider<br><sub>e.g., Sentinel Hub</sub>"]

        class APIGateway,AnalysisService service
        class ImageProcessor core
        class SatelliteProvider external
    end

    %% === User ↔ Backend ===
    FlutterApp -->|API Request| APIGateway
    APIGateway -->|Deliver Response| FlutterApp

    %% === Backend Flow ===
    APIGateway -->|Forward to Analysis| AnalysisService
    AnalysisService -->|Send to Gateway| APIGateway

    AnalysisService -->|Request Imagery| SatelliteProvider
    SatelliteProvider -->|Return Imagery| AnalysisService

    AnalysisService -->|Send for Processing| ImageProcessor
    ImageProcessor -->|Return Results| AnalysisService
```

## Features

* **Cross-Platform Client:** A Flutter application for Android, iOS, and Web for in-depth analysis.
* **Real-time Analysis:** On-demand deforestation analysis of user-selected regions.
* **Interactive Map Interface:** Users can pan, zoom, and select a bounding box to define an area for analysis.
* **Data Visualization:** Displays true-color and NDVI satellite imagery for "before" and "after" comparison.

## Backend API Endpoints

### `/analyze-deforestation`

* **Method**: `POST`
* **Description**: Analyzes a specified region for deforestation.
* **Request Body**:
    ```json
    {
      "bbox": [ -62.41, -3.66, -62.01, -3.26 ]
    }
    ```
* **Success Response (200 OK)**: Returns a JSON object with true-color images, NDVI maps, alerts, and analysis summary.
* **Error Responses**: Returns `400` for invalid input or `500` for server errors.


