# Smart Surveillance & IoV (Internet of Vehicles)

A comprehensive Flutter-based mobile application for intelligent vehicle monitoring, emergency response coordination, and real-time surveillance system. This project integrates Firebase services, GPS tracking, and multimedia capabilities to create a robust IoV ecosystem.

## 🚀 Features

### Core Functionality
- **Real-time Vehicle Tracking**: Live GPS monitoring with map integration
- **Emergency Alert System**: Instant notifications for accidents and emergencies
- **Multi-role Authentication**: Separate dashboards for users and ambulance drivers
- **Video Surveillance**: Live video streaming and playback capabilities
- **Audio Alerts**: Emergency sound notifications with customizable audio files

### Key Modules
- **Authentication System**: Secure login/signup with email verification
- **Dashboard**: Centralized control panel with navigation
- **Live Maps**: Real-time vehicle positioning using Flutter Map and Google Maps
- **Alert Management**: Comprehensive emergency alert handling with video evidence
- **Profile Management**: User profile customization and settings
- **Ambulance Coordination**: Specialized interface for emergency vehicle drivers

## 🛠 Tech Stack

### Frontend Framework
- **Flutter 3.0+**: Cross-platform mobile development
- **Dart**: Programming language

### Firebase Services
- **Firebase Auth**: User authentication and authorization
- **Cloud Firestore**: NoSQL database for real-time data
- **Firebase Realtime Database**: Live data synchronization
- **Firebase Core**: Core Firebase functionality

### Key Dependencies
- **Maps & Location**:
  - `google_maps_flutter`: Interactive Google Maps
  - `flutter_map`: OpenStreetMap integration
  - `geolocator`: GPS location services
  - `latlong2`: Geographic coordinate utilities
  - `permission_handler`: Runtime permissions

- **Multimedia**:
  - `video_player`: Video playback functionality
  - `chewie`: Enhanced video player with controls
  - `audioplayers`: Audio playback for alerts

- **UI & Utilities**:
  - `cupertino_icons`: iOS-style icons
  - `url_launcher`: External link handling
  - `shared_preferences`: Local data persistence
  - `http`: HTTP requests for API integration

## 📱 App Architecture

### Project Structure
```
lib/
├── main.dart              # App entry point and Firebase initialization
├── login.dart             # Authentication screen
├── signup.dart            # User registration
├── dash.dart              # Main dashboard for regular users
├── ambul.dart             # Ambulance driver dashboard
├── map.dart               # Real-time map view
├── alert.dart             # Emergency alert details
├── alert2.dart            # Alternative alert interface
├── live.dart              # Live streaming functionality
├── profile.dart           # User profile management
└── firebase_options.dart # Firebase configuration
```

### User Roles
1. **Regular Users**: Access to dashboard, alerts, and profile management
2. **Ambulance Drivers**: Specialized interface for emergency response coordination

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Firebase project setup

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd "Iov System"
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password)
   - Set up Cloud Firestore and Realtime Database
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place configuration files in respective platform directories

4. **Run the application**
   ```bash
   flutter run
   ```

## 🔧 Configuration

### Firebase Setup
1. Enable Email/Password authentication in Firebase Console
2. Configure Firestore security rules
3. Set up Realtime Database for live data
4. Configure Firebase Storage for media files

### Environment Variables
Update `firebase_options.dart` with your Firebase project configuration.

### Assets
The app includes the following assets in the `assets/` directory:
- `pic.png`: App splash screen image
- `iov.png`, `iovv.png`, `log.png`: Application logos and icons
- `alert.mp3`, `amb.mp3`: Emergency alert sounds
- `video.mp4`: Sample surveillance video

## 📱 Platform Support

- **Android**: Fully supported with Material Design
- **iOS**: Supported with Cupertino design elements
- **Web**: Basic support available
- **Windows**: Desktop support enabled
- **Linux**: Desktop support enabled
- **macOS**: Desktop support enabled

## 🌟 Key Features Explained

### Real-time Tracking
- Continuous GPS location updates
- Live map visualization with vehicle markers
- Location history and route tracking

### Emergency Response
- Instant alert generation with video evidence
- Audio notifications for critical events
- Ambulance dispatch coordination
- Real-time status updates

### User Management
- Secure authentication with email verification
- Role-based access control
- Profile customization
- Remember me functionality

## 🔒 Security Features

- Firebase Authentication with email verification
- Secure data transmission using HTTPS
- Role-based access control
- Local data encryption for sensitive information

## 📊 Data Flow

1. **Authentication**: User login → Firebase Auth verification
2. **Location Tracking**: GPS → Firebase Realtime Database → Map visualization
3. **Alert System**: Emergency detection → Video capture → Alert storage → Notification dispatch
4. **Coordination**: Alert assignment → Ambulance notification → Status updates

## 🐛 Troubleshooting

### Common Issues
- **Firebase Initialization**: Ensure proper configuration files are placed
- **Location Permissions**: Grant location access for tracking features
- **Video Playback**: Check network connectivity for streaming
- **Audio Alerts**: Ensure device volume is enabled

### Debug Mode
Enable debug logging by setting `debugShowCheckedModeBanner: true` in `MaterialApp`.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For support and queries:
- Create an issue in the repository
- Contact the development team

---

**Note**: This is a Final Year Project (FYP) demonstrating the integration of IoT concepts with mobile application development for intelligent transportation systems.
