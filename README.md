# Elecom Mobile - Secure Election Platform 🗳️

[![Flutter](https://img.shields.io/badge/Flutter-3.13.9-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-2.19.6-blue)](https://dart.dev)

A secure mobile application for conducting and managing student union elections, built with Flutter.

![Elecom Mobile Banner](assets/elecom_bg.png)

SMSCHEF_SIM_SLOT=1

## 📖 Table of Contents
- [Key Features](#-key-features)
- [Installation](#-installation)
- [Getting Started](#-getting-started)
- [Configuration](#-configuration)
- [Contributing](#-contributing)
- [License](#-license)
- [Contact](#-contact)

## 🌟 Key Features

- **Secure Authentication**  
  JWT-based login with session management
- **Election Transparency**  
  Real-time vote tracking and audit capabilities
- **Biometric Verification**  
  Face enrollment and live capture for voter validation
- **Cross-Platform**  
  iOS/Android support with responsive UI
- **Voter Dashboard**  
  - Candidate profiles
  - Election countdown
  - Omnibus code system
  - Results visualization

## 🛠️ Installation

1. **Clone Repository**
```shell
git clone https://github.com/your-org/elecom_mobile.git
cd elecom_mobile
```

2. **Install Dependencies**
```shell
flutter pub get
```

3. **Run the App**
```shell
flutter run
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.13.9+
- Dart 2.19.6+
- Android Studio/Xcode (for device emulation)

### Development Setup
1. Create `.env` file from template:
```shell
cp lib/backend/.env.example lib/backend/.env
```

2. Configure API endpoints and secrets in:
```
lib/core/config/api_config.dart
lib/backend/.env
```

## ⚙️ Configuration

| Environment Variable | Description                  |
|----------------------|------------------------------|
| `API_BASE_URL`       | Backend service endpoint     |
| `ENCRYPTION_KEY`     | Vote payload encryption key  |
| `FACE_API_KEY`       | Facial recognition service   |

## 🤝 Contributing

We welcome contributions! Please follow these steps:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 📧 Contact

Election Committee - it@university.edu  
Project Repository: [github.com/your-org/elecom_mobile](https://github.com/your-org/elecom_mobile)
