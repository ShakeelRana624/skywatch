# FYP IoV Alert System - Smart Surveillance & Violence Detection

A comprehensive web-based surveillance system designed for real-time violence detection and alert management in Internet of Vehicles (IoV) environments.

## 🚀 Project Overview

This project implements an intelligent surveillance system that monitors multiple camera feeds, detects potential threats (weapons, violence, suspicious activities), and provides real-time alerts to security personnel. The system is built with Flask and includes a modern, responsive web interface for monitoring and management.

## ✨ Key Features

### 🎥 **Live Camera Monitoring**
- **Real-time multi-camera feed streaming** - Monitor up to 8+ camera feeds simultaneously
- **Simulated camera feeds for demonstration** - Test system functionality without hardware
- **Visual threat detection indicators** - Color-coded alerts for immediate threat identification
- **Timestamp overlay on video streams** - Precise time tracking for all surveillance footage
- **Camera health monitoring** - Real-time status checks for all connected cameras
- **Grid and fullscreen viewing modes** - Flexible display options for different monitoring needs

### 🚨 **Smart Alert System**
- **Real-time threat detection alerts** - Instant notifications when threats are detected
- **Multiple threat categories**: KNIFE, GUN, FIGHT, SUSPICIOUS activities
- **Confidence scoring for detections** - AI-powered confidence levels (70-95% accuracy)
- **Location-based alert management** - Geographic filtering and regional alert routing
- **Audio alert notifications** - Cross-platform beep system (Windows/Linux/Mac compatible)
- **Alert prioritization** - Critical, High, Medium, Low severity levels
- **Escalation protocols** - Automatic escalation for unacknowledged critical alerts
- **Alert history and analytics** - Complete audit trail of all security events

### 📊 **Analytics & Dashboard**
- **Comprehensive monitoring dashboard** - Centralized command center interface
- **System statistics and metrics** - Real-time performance indicators
- **Alert history and trends** - Historical data analysis and pattern recognition
- **Interactive data visualization** - Dynamic charts and graphs using Chart.js
- **Geographic mapping of incidents** - Spatial analysis of threat distribution
- **Performance monitoring** - System health and resource utilization tracking
- **Custom report generation** - Exportable reports for management review
- **Predictive analytics** - Threat prediction based on historical patterns

### 🔐 **User Management**
- **Secure login system** - Session-based authentication with encryption
- **User profile management** - Personalized settings and preferences
- **Role-based access control** - Admin, Operator, Viewer permission levels
- **Activity logging** - Complete audit trail of user actions
- **Multi-factor authentication support** - Enhanced security options
- **Password policy enforcement** - Strong password requirements
- **Session timeout management** - Automatic logout for inactive sessions

### 📱 **Modern UI/UX**
- **Responsive web design** - Optimized for desktop, tablet, and mobile devices
- **Dark theme interface** - Eye-friendly design for extended monitoring sessions
- **Real-time data updates** - WebSocket-based live data streaming
- **Mobile-friendly layout** - Touch-optimized interface for field operations
- **Interactive maps and charts** - Drag, zoom, and filter capabilities
- **Customizable dashboard widgets** - Personalized layout arrangements
- **Accessibility features** - WCAG compliant design for inclusive usage
- **Multi-language support** - Internationalization capabilities

### � **IoV Integration Features**
- **Vehicle-to-Infrastructure (V2I) Communication** - Real-time data exchange between vehicles and monitoring systems
- **GPS-based tracking** - Precise location monitoring for mobile surveillance units
- **Mobile alert routing** - Dynamic alert distribution to connected vehicles
- **Telemetry data integration** - Vehicle sensor data for enhanced situational awareness
- **Emergency response coordination** - Automated notification to emergency services
- **Traffic impact analysis** - Real-time traffic disruption assessment during incidents

### 🌐 **Connectivity & Communication**
- **MQTT Protocol Support** - Lightweight messaging for IoT devices
- **WebSocket Integration** - Real-time bidirectional communication
- **RESTful API Design** - Standardized interface for third-party integrations
- **Firebase Cloud Messaging** - Push notifications for mobile devices
- **Offline Mode Support** - Local data storage during network interruptions
- **Data Synchronization** - Automatic sync when connectivity restored

## 🛠️ Technology Stack

### **Backend Technologies**
- **Flask 3.0.0** - Lightweight Python web framework for rapid development
- **OpenCV 4.8.1** - Computer vision library for real-time image processing and analysis
- **NumPy 1.24.3** - High-performance numerical computing for ML operations
- **Firebase Admin 6.2.0** - Cloud database and authentication services
- **Gunicorn 21.2.0** - Production-grade WSGI HTTP server with multi-threading
- **Pillow 10.1.0** - Advanced image processing and manipulation library
- **Threading Module** - Concurrent processing for multiple camera feeds
- **JSON/CSV Processing** - Data serialization and export capabilities

### **Frontend Technologies**
- **HTML5/CSS3** - Modern semantic markup with responsive design
- **JavaScript ES6+** - Dynamic client-side functionality with async/await
- **Bootstrap 5** - Mobile-first responsive UI framework
- **Chart.js** - Interactive data visualization with real-time updates
- **Leaflet.js** - Open-source interactive maps with custom markers and clustering
- **WebSocket API** - Persistent bidirectional communication for live updates
- **AJAX/Fetch API** - Asynchronous data loading and RESTful API consumption
- **Local Storage** - Client-side data persistence for offline functionality

### **Real-time Communication**
- **MQTT Protocol** - Lightweight messaging for IoT device communication
- **WebSocket Connections** - Persistent connections for live camera feeds
- **Server-Sent Events (SSE)** - One-way real-time data streaming
- **Firebase Realtime Database** - Cloud-based real-time data synchronization

### **Deployment & DevOps**
- **Heroku/Render** - Cloud platform-as-a-service with auto-scaling
- **Netlify** - Static site hosting with continuous deployment
- **Docker Containerization** - Portable application deployment with orchestration
- **Git Version Control** - Source code management and collaborative development
- **CI/CD Pipeline** - Automated testing, building, and deployment workflows

## 📁 Project Structure

```
fyp-web/
├── main.py                 # Main Flask application
├── requirements.txt        # Python dependencies
├── Procfile              # Heroku deployment config
├── netlify.toml          # Netlify deployment config
├── fypiov-firebase-adminsdk-fbsvc-fee1cba230.json  # Firebase credentials
├── templates/            # HTML templates
│   ├── 1st.html          # Landing page
│   ├── login.html        # Login page
│   ├── dash.html         # Main dashboard
│   ├── alerts.html       # Alerts management
│   ├── analytics.html    # Analytics page
│   ├── map.html          # Geographic view
│   ├── iov.html          # IoV management
│   ├── logs.html         # System logs
│   └── profile.html      # User profile
├── static/               # Static assets (CSS, JS, images)
├── Model/                # ML models directory
└── Lib/                  # Additional libraries
```

## 🚀 Quick Start

### **Prerequisites**
- Python 3.8+
- pip package manager
- Git

### **Installation**

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd fyp-web
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   # Windows
   venv\Scripts\activate
   # Linux/Mac
   source venv/bin/activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up Firebase (optional)**
   - Place your Firebase admin SDK JSON file in the root directory
   - Update the filename in `main.py` if needed

5. **Run the application**
   ```bash
   python main.py
   ```

6. **Access the application**
   - Open your browser and go to `http://localhost:5000`
   - Login with any username and password (demo mode)

## 🔧 Configuration

### **Environment Variables**
- `PORT` - Application port (default: 5000)
- `FLASK_ENV` - Environment mode (development/production)

### **MQTT Configuration**
Update these variables in `main.py` for real-time integration:
```python
BROKER_ADDRESS = "localhost"  # Your MQTT broker
TOPIC_ALERT = "swarm/alert/violence"  # Alert topic
```

### **Firebase Configuration**
Replace the Firebase credentials file with your own:
- Download from Firebase Console → Project Settings → Service Accounts
- Rename to `fypiov-firebase-adminsdk-fbsvc-fee1cba230.json`

## 📱 Application Pages

### **1. Landing Page (`/`)**
- **System Introduction**: Comprehensive overview of capabilities and features
- **Live Demo Showcase**: Interactive demonstration of key functionalities
- **Key Features Overview**: Visual presentation of system strengths
- **Technology Stack Display**: Technical architecture summary
- **Security Compliance Information**: Certifications and standards compliance
- **Contact & Support Information**: Help desk and technical support details

### **2. Dashboard (`/dash`)**
- **Real-time System Status**: Live health monitoring with color-coded indicators
- **Multi-Camera Grid View**: Simultaneous display of up to 8 camera feeds
- **Recent Alerts Feed**: Chronological list of latest security events
- **Quick Statistics Panel**: Key metrics at a glance (alerts today, cameras online, system uptime)
- **Threat Level Overview**: Current threat assessment with severity distribution
- **System Performance Metrics**: CPU, memory, and network usage monitoring
- **Weather Integration**: Environmental conditions affecting surveillance
- **Quick Action Buttons**: One-click access to critical functions

### **3. Alerts Management (`/alerts`)**
- **Comprehensive Alert List**: Detailed view of all security events
- **Advanced Filtering System**: Filter by threat type, location, time range, severity
- **Alert Details Modal**: In-depth information for each security event
- **Threat Level Indicators**: Visual severity coding (Critical, High, Medium, Low)
- **Location Intelligence**: GPS coordinates and address mapping
- **Alert Acknowledgment System**: Mark alerts as reviewed or resolved
- **Escalation Management**: Automatic and manual alert escalation workflows
- **Bulk Operations**: Mass acknowledgment, archiving, and export functions

### **4. Analytics (`/analytics`)**
- **Threat Detection Trends**: Time-series analysis of security incidents
- **System Performance Metrics**: Detailed performance analytics and benchmarks
- **Statistical Charts & Graphs**: Interactive visualizations with drill-down capabilities
- **Historical Data Analysis**: Long-term pattern recognition and insights
- **Predictive Analytics**: AI-powered threat prediction models
- **Custom Report Builder**: Create and schedule automated reports
- **Comparative Analysis**: Period-over-period and year-over-year comparisons
- **Export Capabilities**: PDF, Excel, and CSV report generation

### **5. Geographic View (`/map`)**
- **Interactive Map Interface**: Full-screen map with zoom and pan capabilities
- **Real-time Alert Mapping**: Live threat locations on geographic map
- **Camera Positioning**: Visual representation of surveillance camera coverage
- **Regional Statistics**: Location-based analytics and hot-spot identification
- **Heat Map Visualization**: Density mapping of security incidents
- **Geofencing Support**: Virtual boundaries for automated alerting
- **Route Planning**: Optimal response route calculation for emergencies
- **Satellite/Hybrid Views**: Multiple map layers for enhanced situational awareness

### **6. IoV Management (`/iov`)**
- **Vehicle Monitoring Dashboard**: Real-time status of connected vehicles
- **Connected Device Status**: Health monitoring of all IoV endpoints
- **Network Topology Visualization**: Interactive network diagram
- **Device Configuration Management**: Remote configuration and updates
- **Telemetry Data Display**: Vehicle sensor readings and diagnostics
- **Communication Logs**: V2I and V2V message history
- **Firmware Management**: Over-the-air updates and version control
- **Performance Analytics**: Vehicle and network performance metrics

### **7. System Logs (`/logs`)**
- **Comprehensive System Logs**: Detailed logging of all system activities
- **Error Tracking & Analysis**: Automated error detection and categorization
- **Performance Monitoring**: Real-time system resource utilization
- **Audit Trail**: Complete record of user actions and system changes
- **Log Filtering & Search**: Advanced search with multiple criteria
- **Export Functionality**: Download logs for compliance and analysis
- **Alert Correlation**: Link logs to specific security events
- **Retention Management**: Automated log archival and cleanup policies

### **8. User Profile (`/profile`)**
- **User Settings Management**: Personalized system preferences
- **Notification Preferences**: Configure alert delivery methods
- **Account Information**: Personal details and contact information
- **Security Settings**: Password management and two-factor authentication
- **Session Management**: View and manage active sessions
- **Permission Overview**: Display current access rights and roles
- **Activity History**: Personal audit trail of system usage
- **Theme Customization**: Interface appearance and accessibility options

## 🎯 Demo Features

The current implementation includes **demo mode** with:

- **Simulated Camera Feeds**: Generated video feeds with camera IDs and timestamps
- **Mock Detection System**: Random threat generation for testing
- **Sample Data**: Pre-populated alerts and statistics
- **Audio Alerts**: Cross-platform beep notifications

## 🔌 API Endpoints

### **Authentication**
- `POST /login` - User authentication
- `GET /logout` - Session termination

### **Data APIs**
- `GET /api/alerts` - Retrieve alert data
- `GET /api/stats` - System statistics
- `GET /video_feed/<camera_id>` - Live camera stream

## 🚀 Deployment

### **Heroku/Render**
1. Connect your repository
2. Set build command: `pip install -r requirements.txt`
3. Set start command: `gunicorn main:app`
4. Deploy!

### **Netlify (Static Assets)**
1. Connect repository
2. Build command: `pip install -r requirements.txt`
3. Publish directory: `.`
4. Deploy!

### **Docker**
```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["gunicorn", "main:app"]
```

## 🔒 Security Considerations

- Session-based authentication
- Input validation and sanitization
- CORS configuration for production
- Environment variable management
- Firebase security rules

## 🛠️ Development

### **Adding New Features**
1. Create route in `main.py`
2. Add corresponding HTML template in `templates/`
3. Update navigation in existing templates
4. Add API endpoints if needed

### **Customizing Detection**
- Replace `mock_detection()` with actual ML model
- Integrate real camera feeds
- Configure MQTT for real-time data
- Add custom threat categories

## 📈 Future Enhancements

- **Real ML Integration**: YOLO/ResNet models for actual detection
- **Real Camera Feeds**: IP camera integration
- **Mobile App**: React Native companion app
- **Advanced Analytics**: Machine learning for pattern recognition
- **Multi-tenant Support**: Multiple organizations
- **Cloud Integration**: AWS/Azure deployment options

## 🐛 Troubleshooting

### **Common Issues**

1. **Port Already in Use**
   ```bash
   # Find and kill process on port 5000
   netstat -ano | findstr :5000
   taskkill /PID <PID> /F
   ```

2. **Dependencies Not Found**
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt --force-reinstall
   ```

3. **Firebase Connection Issues**
   - Check JSON file permissions
   - Verify Firebase project settings
   - Ensure network connectivity

## 📞 Support

For issues and questions:
- Check the troubleshooting section
- Review the code comments
- Create an issue in the repository
- Contact the development team

## 📄 License

This project is part of a Final Year Project (FYP) for educational purposes. Please contact the authors for usage permissions.

## 👥 Contributors

- **Project Lead**: FYP Student
- **Advisor**: Faculty Supervisor
- **Department**: Computer Science/Engineering

---

**Note**: This is a demonstration version with simulated data. For production use, integrate real detection models and camera feeds.
