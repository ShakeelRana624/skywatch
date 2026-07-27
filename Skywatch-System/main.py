"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   🎯 INTELLIGENT WEAPON DETECTION SYSTEM - COMPLETE INTEGRATED VERSION      ║
║                                                                              ║
║   Features:                                                                  ║
║   ✅ YOLO-based weapon detection (Gun, Knife, Explosion)                   ║
║   ✅ Multi-camera support with location-based setup                         ║
║   ✅ 3km IOV radius filtering per camera                                    ║
║   ✅ Firebase Realtime Database integration                                 ║
║   ✅ Cloudinary video upload with slow-motion                               ║
║   ✅ Agent-based decision engine                                            ║
║   ✅ 4-section professional UI                                              ║
║   ✅ Violence detection                                                     ║
║   ✅ Fire & Smoke detection                                                 ║
║   ✅ Pose detection (Hands-up, Aiming)                                      ║
║   ✅ Evidence recording system                                              ║
║   ✅ External callback system                                               ║
║                                                                              ║
║   Author: FYP Team                                                          ║
║   Version: 9.0 - ULTIMATE COMBINED VERSION                                  ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import sys
import os
from pathlib import Path
import time
from datetime import datetime
import cv2
import tempfile
import numpy as np
import threading
import json
import queue
import math
import sqlite3
import platform
from collections import defaultdict
from typing import Dict, List, Any, Optional, Tuple
from enum import Enum

# Add project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# ═══════════════════════════════════════════════════════════════════════════════
# IMPORTS - Third Party Libraries
# ═══════════════════════════════════════════════════════════════════════════════

# YOLO / Ultralytics
try:
    from ultralytics import YOLO
    YOLO_AVAILABLE = True
    print("✅ YOLO (Ultralytics) loaded successfully")
except ImportError:
    print("❌ YOLO not installed. Run: pip install ultralytics")
    YOLO_AVAILABLE = False

# Firebase imports
try:
    import firebase_admin
    from firebase_admin import credentials, db
    FIREBASE_AVAILABLE = True
    print("✅ Firebase Admin SDK loaded successfully")
except ImportError:
    print("⚠️ Firebase not installed. Run: pip install firebase-admin")
    FIREBASE_AVAILABLE = False

# Cloudinary imports
try:
    import cloudinary
    import cloudinary.uploader
    import cloudinary.api
    CLOUDINARY_AVAILABLE = True
    print("✅ Cloudinary SDK loaded successfully")
except ImportError:
    print("⚠️ Cloudinary not installed. Run: pip install cloudinary")
    CLOUDINARY_AVAILABLE = False

# SciPy for heatmap (optional)
try:
    from scipy.ndimage import gaussian_filter
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False

# psutil for system monitoring (optional)
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

# ═══════════════════════════════════════════════════════════════════════════════
# IMPORTS - Project Modules (with fallbacks)
# ═══════════════════════════════════════════════════════════════════════════════

# Human Tracker
try:
    from detection.human_tracker import HumanTracker
    HUMAN_TRACKER_AVAILABLE = True
    print("✅ Human Tracker module loaded")
except ImportError:
    HUMAN_TRACKER_AVAILABLE = False
    print("⚠️ Human Tracker not available - using basic tracker")

# Pose Detector
try:
    from pose_detection import PoseDetector
    POSE_DETECTOR_AVAILABLE = True
    print("✅ Pose Detector module loaded")
except ImportError:
    POSE_DETECTOR_AVAILABLE = False
    print("⚠️ Pose Detector not available")

# Violence Detector
try:
    from fight_detection.fight_detector import ViolenceDetector
    VIOLENCE_DETECTOR_AVAILABLE = True
    print("✅ Violence Detector module loaded")
except ImportError:
    VIOLENCE_DETECTOR_AVAILABLE = False
    print("⚠️ Violence Detector module not available")

# Fire Smoke Detector
try:
    from explosion.fire_smoke_detection import FireSmokeDetector
    FIRE_SMOKE_DETECTOR_AVAILABLE = True
    print("✅ Fire/Smoke Detector module loaded")
except ImportError:
    FIRE_SMOKE_DETECTOR_AVAILABLE = False
    print("⚠️ Fire/Smoke Detector not available")

# Agent-based Decision Engine
try:
    from agents.agent_based_decision_engine import AgentBasedDecisionEngine, AgentState
    AGENT_ENGINE_AVAILABLE = True
    print("✅ Agent Decision Engine loaded")
except ImportError:
    AGENT_ENGINE_AVAILABLE = False
    print("⚠️ Agent Decision Engine not available - using basic engine")

# Alert System
try:
    from utils.alert_system import AlertSystem
    ALERT_SYSTEM_AVAILABLE = True
    print("✅ Alert System loaded")
except ImportError:
    ALERT_SYSTEM_AVAILABLE = False
    print("⚠️ Alert System not available")

# Firebase Alert Storage
try:
    from utils.firebase_alert_storage import FirebaseAlertStorage
    FIREBASE_STORAGE_AVAILABLE = True
    print("✅ Firebase Alert Storage loaded")
except ImportError:
    FIREBASE_STORAGE_AVAILABLE = False
    print("⚠️ Firebase Alert Storage not available")


# ═══════════════════════════════════════════════════════════════════════════════
# ENUMS AND CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

class SystemState(Enum):
    """System state enumeration"""
    NORMAL = "NORMAL"
    SUSPICIOUS = "SUSPICIOUS"
    THREAT_DETECTION = "THREAT_DETECTION"
    EMERGENCY = "EMERGENCY"
    VIOLENT = "VIOLENT"
    ARMED = "ARMED"
    CRITICAL = "CRITICAL"


class ThreatLevel(Enum):
    """Threat level enumeration"""
    MINIMAL = "MINIMAL"
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


# Color constants for UI
COLORS = {
    'GREEN': (0, 255, 0),
    'RED': (0, 0, 255),
    'YELLOW': (0, 255, 255),
    'ORANGE': (0, 165, 255),
    'BLUE': (255, 0, 0),
    'PURPLE': (255, 0, 255),
    'CYAN': (255, 255, 0),
    'WHITE': (255, 255, 255),
    'BLACK': (0, 0, 0),
    'DARK_GRAY': (30, 30, 30),
    'LIGHT_GRAY': (200, 200, 200),
}

# Weapon classes to detect - EXPANDED for better detection
WEAPON_CLASSES = ['gun', 'pistol', 'rifle', 'shotgun', 'knife', 'blade', 'weapon', 'handgun', 'revolver', 'potential_weapon']
EXPLOSIVE_CLASSES = ['explosion', 'explosive', 'bomb', 'blast']
IGNORE_CLASSES = ['person', 'cat', 'couch', 'chair', 'table', 'bottle', 'cup']  # Fire/Smoke removed - we want those alerts!


# ═══════════════════════════════════════════════════════════════════════════════
# FALLBACK CLASSES (When modules not available)
# ═══════════════════════════════════════════════════════════════════════════════

class BasicHumanTracker:
    """Fallback human tracker when module not available"""
    
    def __init__(self):
        self.tracks = {}
        self.next_id = 1
        self.colors = {}
    
    def detect_humans(self, frame):
        """Basic human detection placeholder"""
        return []
    
    def get_id_color(self, person_id):
        """Get color for person ID"""
        if person_id not in self.colors:
            np.random.seed(person_id)
            self.colors[person_id] = tuple(np.random.randint(100, 255, 3).tolist())
        return self.colors[person_id]


class BasicPoseDetector:
    """Fallback pose detector when module not available"""
    
    def __init__(self):
        self.detected_poses = {}
        self.hands_up_count = 0
        self.hands_up_ids = []
    
    def detect_poses_in_frame(self, frame, detections):
        return {}
    
    def get_hands_up_count(self):
        return self.hands_up_count
    
    def get_hands_up_person_ids(self):
        return self.hands_up_ids
    
    def clear_poses(self):
        self.detected_poses = {}
        self.hands_up_count = 0
        self.hands_up_ids = []
    
    def draw_pose_on_frame(self, frame, pose_info, color):
        return frame


class BasicViolenceDetector:
    """Fallback violence detector when module not available"""
    
    def __init__(self):
        self.detected_violence = {}
        self.violence_count = 0
        self.violent_ids = []
        self.violence_confidence = 0.0
        self.fight_confidence = 0.0
        self.non_fight_confidence = 1.0
    
    def detect_violence_in_frame(self, frame, detections=None):
        """Fallback violence detection - always returns no violence"""
        return {
            'violence_detected': False,
            'violence_confidence': 0.0,
            'fight_confidence': 0.0,
            'non_fight_confidence': 1.0,
            'error': 'Basic detector - no real detection'
        }
    
    def get_violence_count(self):
        return self.violence_count
    
    def get_violent_person_ids(self):
        return self.violent_ids
    
    def get_violence_info(self, person_id):
        return self.detected_violence.get(person_id, {})
    
    def clear_fights(self):
        self.detected_violence = {}
        self.violence_count = 0
        self.violent_ids = []
    
    def draw_violence_on_frame(self, frame, violence_info):
        return frame


class BasicFireSmokeDetector:
    """Fallback fire/smoke detector when module not available"""
    
    def __init__(self):
        pass
    
    def detect_fire_smoke_in_frame(self, frame):
        return {
            'fire_detected': False,
            'smoke_detected': False,
            'fire_count': 0,
            'smoke_count': 0,
            'fire_confidence': 0.0,
            'smoke_confidence': 0.0
        }
    
    def draw_fire_smoke_on_frame(self, frame, result):
        return frame


class BasicDecisionEngine:
    """Fallback decision engine when module not available"""
    
    def __init__(self):
        self.current_state = SystemState.NORMAL
    
    def process(self, detection):
        """Basic threat processing"""
        threat_score = 0.0
        state = "NORMAL"
        action = "MONITOR"
        
        gun_conf = detection.get('gun_conf', 0)
        knife_conf = detection.get('knife_conf', 0)
        explosion_conf = detection.get('explosion_conf', 0)
        violence = detection.get('violence_detected', False)
        
        if gun_conf > 0.5 or knife_conf > 0.5:
            threat_score = 7.0
            state = "ARMED"
            action = "SAVE_EVIDENCE,LOCAL_ALARM"
        elif explosion_conf > 0.5:
            threat_score = 9.0
            state = "CRITICAL"
            action = "SAVE_EVIDENCE,LOCAL_ALARM,EMERGENCY_RESPONSE"
        elif violence:
            threat_score = 5.0
            state = "VIOLENT"
            action = "SAVE_EVIDENCE,LOCAL_ALARM"
        elif gun_conf > 0.3 or knife_conf > 0.3:
            threat_score = 4.0
            state = "SUSPICIOUS"
            action = "SAVE_EVIDENCE"
        
        return {
            'threat_score': threat_score,
            'state': state,
            'action': action,
            'state_changed': False,
            'system_state': state,
            'emergency_response': None
        }


class BasicEvidenceAgent:
    """Fallback evidence agent"""
    
    def __init__(self):
        self.frame_buffer = []
        self.max_buffer = 600
        self.recording = False
        self.current_file = None
    
    def add_frame_to_buffer(self, frame, timestamp):
        self.frame_buffer.append({'frame': frame.copy(), 'timestamp': timestamp})
        if len(self.frame_buffer) > self.max_buffer:
            self.frame_buffer.pop(0)
    
    def start_recording(self, filename):
        self.recording = True
        self.current_file = filename
    
    def force_stop_recording(self):
        self.recording = False
    
    def reset_session(self):
        self.frame_buffer = []
        self.recording = False
    
    def get_status(self):
        return {
            'buffered_frames': len(self.frame_buffer),
            'current_file': self.current_file
        }


class BasicAlertSystem:
    """Fallback alert system"""
    
    def __init__(self, camera_id="CAM_001", camera_location="Main Camera"):
        self.camera_id = camera_id
        self.camera_location = camera_location
        self.alert_count = 0
    
    def create_weapon_alert(self, detection, frame_count):
        self.alert_count += 1
        return type('Alert', (), {
            'alert_id': f"alert_{self.alert_count}",
            'detection_type': 'WEAPON',
            'timestamp': datetime.now().isoformat()
        })()
    
    def create_violence_alert(self, detection, frame_count):
        return self.create_weapon_alert(detection, frame_count)
    
    def create_fire_alert(self, result, frame_count):
        return [self.create_weapon_alert({}, frame_count)]
    
    def create_smoke_alert(self, result, frame_count):
        return [self.create_weapon_alert({}, frame_count)]
    
    def create_pose_alert(self, detection, frame_count, pose_type):
        return self.create_weapon_alert(detection, frame_count)
    
    def print_alert_json(self, alert, message):
        print(f"🚨 {message}")
    
    def print_summary_json(self, alerts):
        print(f"📊 Total alerts: {len(alerts)}")
    
    def alert_to_json(self, alert):
        return json.dumps({'alert_id': alert.alert_id})
    
    def create_alert_summary(self, alerts):
        return {'total': len(alerts)}


# ═══════════════════════════════════════════════════════════════════════════════
# FIREBASE REALTIME DATABASE CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class FirebaseRealtimeDB:
    """Firebase Realtime Database handler with Cloudinary video upload and IOV filtering"""
    
    # ═══════════════════════════════════════════════════════════════════════════
    # CAMERA CONFIGURATIONS - Different cameras with different locations
    # ═══════════════════════════════════════════════════════════════════════════
    
    # 📍 Wazirabad Camera (Laptop)
    CAMERA_CANTT = {
        'id': 'CAM_CANTT_001',
        'name': 'Cantt gate Security Camera',
        'address': 'Rahwali, Gujranwala',
        'city': 'Gujranwala',
        'lat': 32.244870,
        'lng': 74.163715,
        'type': 'Laptop Camera'
    }
    
    # 📍 Gujranwala Camera (Mobile)
    CAMERA_GUJRANWALA = {
        'id': 'CAM_GRW_001',
        'name': 'Shahenabad Security Camera',
        'address': 'Shahenabad, Gujranwala',
        'city': 'Gujranwala',
        'lat': 32.191461,
        'lng': 74.179374,
        'type': 'Mobile Camera'
    }

    def __init__(self):
        """Initialize Firebase Realtime Database"""
        self.initialized = False
        self.app = None
        self.database_url = 'https://fypiov-default-rtdb.firebaseio.com/'
        self.alert_count = 0
        
        # Cloudinary video buffer configuration
        self.cloudinary_initialized = False
        
        # Per-camera buffers
        self.camera_buffers = {}
        self.buffer_max_frames = 300  # 10 seconds at 30fps per camera
        self.buffer_lock = threading.Lock()
        
        # Post-detection recording
        self.post_detection_frames = {}
        self.post_detection_threshold = 300  # 10 seconds at 30fps
        self.detection_active = {}
        
        # Cooldowns
        self.last_alert_time = 0
        self.video_cooldown = 5  # Seconds between uploads
        self.videos_uploaded = 0
        
        # Camera lookup
        self.cameras_by_id = {
            'CAM_CANTT_001': self.CAMERA_CANTT,
            'CAM_GRW_001': self.CAMERA_GUJRANWALA
        }
        
        # Initialize Firebase and Cloudinary
        self._init_firebase()
        self._init_cloudinary()

    def _init_firebase(self):
        """Initialize Firebase Realtime Database"""
        print("\n" + "=" * 70)
        print("🔥 FIREBASE REALTIME DATABASE INITIALIZATION")
        print("=" * 70)

        if not FIREBASE_AVAILABLE:
            print("❌ Firebase SDK not available")
            return

        try:
            # Find config file
            config_file = None
            config_paths = [
                "serviceAccountKey.json",
                "config/firebase_config.json",
                "firebase_config.json",
                "config/serviceAccountKey.json"
            ]
            
            for path in config_paths:
                if os.path.exists(path):
                    config_file = path
                    print(f"✅ Firebase config found: {path}")
                    break

            if not config_file:
                print("❌ No Firebase config file found")
                print("   Expected locations:", config_paths)
                return

            # Clean existing apps
            app_name = 'weapon_detection_system'
            if firebase_admin._apps:
                print("🔄 Cleaning existing Firebase apps...")
                for app in list(firebase_admin._apps.values()):
                    try:
                        firebase_admin.delete_app(app)
                    except:
                        pass

            # Initialize Firebase
            cred = credentials.Certificate(config_file)
            self.app = firebase_admin.initialize_app(cred, {
                'databaseURL': self.database_url
            }, name=app_name)

            # Create database references
            self.alerts_ref = db.reference('alerts', app=self.app)
            self.latest_ref = db.reference('latest_alert', app=self.app)
            self.stats_ref = db.reference('system_stats', app=self.app)
            self.cameras_ref = db.reference('cameras', app=self.app)
            self.iovs_ref = db.reference('iovs', app=self.app)

            # Save camera configurations
            cameras_info = {}
            for cam_id, cam_data in self.cameras_by_id.items():
                cameras_info[cam_id] = {
                    'camera_id': cam_data['id'],
                    'name': cam_data['name'],
                    'address': cam_data['address'],
                    'city': cam_data['city'],
                    'latitude': cam_data['lat'],
                    'longitude': cam_data['lng'],
                    'type': cam_data['type'],
                    'location': {
                        'lat': cam_data['lat'],
                        'lng': cam_data['lng']
                    },
                    'installed_at': datetime.now().strftime('%Y-%m-%d'),
                    'status': 'active'
                }
            
            self.cameras_ref.set(cameras_info)
            print(f"✅ {len(cameras_info)} cameras saved to Firebase")

            # Test connection
            db.reference('system_test', app=self.app).set({
                'connected': True,
                'timestamp': int(time.time() * 1000),
                'message': 'Weapon Detection System Connected',
                'version': '9.0'
            })

            self.initialized = True
            
            print("\n✅ FIREBASE REALTIME DATABASE READY!")
            print(f"📡 Database URL: {self.database_url}")
            print("\n📍 REGISTERED CAMERAS:")
            for cam_id, cam_data in self.cameras_by_id.items():
                print(f"   • {cam_data['name']} ({cam_id})")
                print(f"     📍 {cam_data['city']}: {cam_data['lat']}, {cam_data['lng']}")
            print("=" * 70)

        except Exception as e:
            print(f"❌ Firebase initialization error: {e}")
            import traceback
            traceback.print_exc()

    def _init_cloudinary(self):
        """Initialize Cloudinary for video uploads"""
        print("\n" + "=" * 70)
        print("☁️ CLOUDINARY INITIALIZATION")
        print("=" * 70)
        
        if not CLOUDINARY_AVAILABLE:
            print("❌ Cloudinary SDK not available")
            return
            
        try:
            # Configure Cloudinary - REPLACE WITH YOUR CREDENTIALS
            cloudinary.config(
                cloud_name="dsnpjwaly",
                api_key="822554518314666",
                api_secret="5Mx7QjuEoe9so37yJLXM3LbJOL0",
                secure=True
            )
            
            # Test connection
            cloudinary.api.ping()
            self.cloudinary_initialized = True
            
            print("✅ CLOUDINARY READY!")
            print(f"☁️ Cloud Name: {cloudinary.config().cloud_name}")
            print("=" * 70)
            
        except Exception as e:
            print(f"❌ Cloudinary initialization error: {e}")
            self.cloudinary_initialized = False

    # ═══════════════════════════════════════════════════════════════════════════
    # BUFFER MANAGEMENT
    # ═══════════════════════════════════════════════════════════════════════════

    def add_frame_to_buffer(self, frame, camera_id=None):
        """Add frame to the buffer of the specified camera"""
        if frame is None or camera_id is None:
            return False
            
        try:
            if not isinstance(frame, np.ndarray) or len(frame.shape) != 3:
                return False
            
            with self.buffer_lock:
                # Create buffer for this camera if not exists
                if camera_id not in self.camera_buffers:
                    self.camera_buffers[camera_id] = []
                
                frame_copy = frame.copy()
                self.camera_buffers[camera_id].append({
                    'frame': frame_copy,
                    'timestamp': time.time()
                })
                
                # Limit buffer size
                if len(self.camera_buffers[camera_id]) > self.buffer_max_frames:
                    self.camera_buffers[camera_id].pop(0)
            
            return True
                
        except Exception as e:
            print(f"❌ Error adding frame to buffer: {e}")
            return False

    def start_post_detection_recording(self, camera_id):
        """Start post-detection recording for a camera"""
        with self.buffer_lock:
            self.detection_active[camera_id] = True
            self.post_detection_frames[camera_id] = 0
            print(f"📹 Post-detection recording started for camera {camera_id}")

    def add_post_detection_frame(self, camera_id, frame):
        """Add frame to post-detection buffer"""
        with self.buffer_lock:
            if not self.detection_active.get(camera_id, False):
                return False
            
            # Add to camera buffer
            if camera_id not in self.camera_buffers:
                self.camera_buffers[camera_id] = []
            
            self.camera_buffers[camera_id].append({
                'frame': frame.copy(),
                'timestamp': time.time()
            })
            
            # Limit buffer size
            if len(self.camera_buffers[camera_id]) > self.buffer_max_frames:
                self.camera_buffers[camera_id].pop(0)
            
            # Increment post-detection counter
            self.post_detection_frames[camera_id] += 1
            
            # Check if post-detection complete
            if self.post_detection_frames[camera_id] >= self.post_detection_threshold:
                self.detection_active[camera_id] = False
                print(f"✅ Post-detection recording complete for {camera_id}")
                return True
            
            return False

    def get_buffer_size(self, camera_id=None):
        """Get current buffer size for a camera"""
        with self.buffer_lock:
            if camera_id:
                return len(self.camera_buffers.get(camera_id, []))
            else:
                return sum(len(buf) for buf in self.camera_buffers.values())

    # ═══════════════════════════════════════════════════════════════════════════
    # VIDEO CREATION AND UPLOAD
    # ═══════════════════════════════════════════════════════════════════════════

    def create_video_from_buffer(self, alert_id, camera_id):
        """Create slow-motion video from camera buffer and upload to Cloudinary"""
        if camera_id is None:
            print("❌ create_video_from_buffer: camera_id is required")
            return None
        
        with self.buffer_lock:
            if camera_id not in self.camera_buffers:
                print(f"❌ No buffer for camera {camera_id}")
                return None
            
            frames_list = self.camera_buffers[camera_id]
            buffer_size = len(frames_list)
            
            if buffer_size < 30:
                print(f"⚠️ Not enough frames for camera {camera_id}: {buffer_size} < 30")
                return None
            
            buffer_copy = [item['frame'].copy() for item in frames_list]
        
        print(f"\n{'🎥' * 20}")
        print(f"🎥 CREATING VIDEO FROM {len(buffer_copy)} FRAMES")
        print(f"📹 Camera: {camera_id}")
        print(f"{'🎥' * 20}\n")
        
        if not self.cloudinary_initialized:
            print("⚠️ Cloudinary not initialized - skipping video upload")
            return None
            
        temp_video_path = None
        try:
            # Create temporary video file
            with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as tmpfile:
                temp_video_path = tmpfile.name
            
            height, width = buffer_copy[0].shape[:2]
            
            # Normal speed: 30 FPS
            fps = 30.0
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            out = cv2.VideoWriter(temp_video_path, fourcc, fps, (width, height))
            
            if not out.isOpened():
                print(f"❌ VideoWriter failed to open")
                return None
            
            # Write frames with normal speed
            frames_written = 0
            for i, frame in enumerate(buffer_copy):
                out.write(frame)
                frames_written += 1
            
            out.release()
            
            # Calculate video properties
            original_duration = buffer_size / 30.0
            video_duration = frames_written / fps
            slow_factor = video_duration / original_duration if original_duration > 0 else 1.0
            
            if not os.path.exists(temp_video_path):
                print("❌ Video file not created")
                return None
                
            file_size = os.path.getsize(temp_video_path)
            if file_size == 0:
                print("❌ Video file is empty")
                return None
            
            print(f"📹 Video created: {frames_written} frames, {video_duration:.1f}s duration")
            
            # Upload to Cloudinary
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            public_id = f"alert_{self.alert_count}_{timestamp}_{camera_id}"
            
            print(f"☁️ Uploading to Cloudinary...")
            
            upload_result = cloudinary.uploader.upload(
                temp_video_path,
                resource_type="video",
                folder="iov_alerts",
                public_id=public_id,
                tags=["iov", f"alert_{alert_id}", "weapon_detection", f"cam_{camera_id}"],
                eager=[{"width": 640, "height": 360, "crop": "scale"}],
                eager_async=False,
                overwrite=True,
                timeout=60
            )
            
            # Get URLs
            video_url = upload_result['secure_url']
            thumbnail_url = None
            
            if 'eager' in upload_result and len(upload_result['eager']) > 0:
                video_url = upload_result['eager'][0]['secure_url']
                thumbnail_url = upload_result['eager'][0]['secure_url'].replace('.mp4', '.jpg')
            
            self.videos_uploaded += 1
            
            print(f"✅ Video uploaded successfully!")
            print(f"📹 URL: {video_url}")
            
            return {
                'video_url': video_url,
                'thumbnail_url': thumbnail_url,
                'public_id': upload_result['public_id'],
                'duration': upload_result.get('duration', video_duration),
                'format': upload_result.get('format', 'mp4'),
                'bytes': upload_result.get('bytes', file_size),
                'width': upload_result.get('width', width),
                'height': upload_result.get('height', height),
                'fps': fps,
                'slow_factor': slow_factor,
                'speed': 'NORMAL SPEED'
            }
            
        except Exception as e:
            print(f"\n{'❌' * 20}")
            print(f"❌ VIDEO UPLOAD ERROR: {e}")
            print(f"{'❌' * 20}\n")
            import traceback
            traceback.print_exc()
            return None
            
        finally:
            if temp_video_path and os.path.exists(temp_video_path):
                try:
                    os.unlink(temp_video_path)
                except:
                    pass

    # ═══════════════════════════════════════════════════════════════════════════
    # IOV LOCATION-BASED FILTERING
    # ═══════════════════════════════════════════════════════════════════════════

    def calculate_distance(self, lat1, lon1, lat2, lon2):
        """Calculate distance in km between two coordinates using Haversine formula"""
        R = 6371  # Earth's radius in km
        
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        distance = R * c
        
        return distance

    def get_nearby_iovs(self, camera_lat, camera_lng, max_distance_km=3.0):
        """Get all active IOVs within specified radius (default 3km)"""
        if not self.initialized:
            print("❌ Firebase not initialized")
            return []
        
        try:
            # Get all IOVs from database
            all_iovs = self.iovs_ref.get()
            
            if not all_iovs:
                print("📡 No IOVs found in database")
                return []
            
            nearby_iovs = []
            current_time_ms = int(time.time() * 1000)
            
            for iov_id, iov_data in all_iovs.items():
                # Check if IOV is active (status = 'online')
                status = iov_data.get('status')
                if status != 'online':
                    continue
                
                # Check last update - within last 60 seconds
                last_update = iov_data.get('lastUpdate', 0)
                if current_time_ms - last_update > 60000:  # 60 seconds timeout
                    continue
                
                # Get IOV location
                iov_lat = iov_data.get('lat')
                iov_lng = iov_data.get('lng')
                
                if iov_lat is None or iov_lng is None:
                    continue
                
                # Calculate distance
                distance = self.calculate_distance(camera_lat, camera_lng, iov_lat, iov_lng)
                
                # Check if within range
                if distance <= max_distance_km:
                    nearby_iovs.append({
                        'iov_id': iov_id,
                        'distance': round(distance, 2),
                        'lat': iov_lat,
                        'lng': iov_lng,
                        'last_update': last_update,
                        'username': iov_data.get('username', 'Unknown'),
                        'carNumber': iov_data.get('carNumber', 'Unknown'),
                        'role': iov_data.get('role', 'Unknown'),
                        'accuracy': iov_data.get('accuracy', 0),
                        'speed': iov_data.get('speed', 0),
                        'userId': iov_data.get('userId', iov_id),
                        'deviceInfo': iov_data.get('deviceInfo', {})
                    })
            
            # Sort by distance (nearest first)
            nearby_iovs.sort(key=lambda x: x['distance'])
            
            print(f"📡 Found {len(nearby_iovs)} IOVs within {max_distance_km}km")
            for iov in nearby_iovs:
                print(f"   🚗 {iov['carNumber']} - {iov['username']} - {iov['distance']}km away")
            
            return nearby_iovs
            
        except Exception as e:
            print(f"❌ Error getting nearby IOVs: {e}")
            return []

    def send_alert_to_iov(self, iov_id, alert_data, camera_info):
        """Send alert to a specific IOV"""
        if not self.initialized:
            return False
        
        try:
            # Create IOV-specific alert reference
            iov_alerts_ref = db.reference(f'iov_alerts/{iov_id}', app=self.app)
            
            # Prepare alert for this IOV
            iov_alert = {
                'alert_id': alert_data.get('id'),
                'type': alert_data.get('type'),
                'weapon_class': alert_data.get('weapon_class'),
                'confidence': alert_data.get('confidence'),
                'timestamp': alert_data.get('timestamp'),
                'time': alert_data.get('time'),
                'date': alert_data.get('date'),
                'camera_id': alert_data.get('camera_id'),
                'camera_name': alert_data.get('camera_name'),
                'location': alert_data.get('location'),
                'city': alert_data.get('city'),
                'full_address': alert_data.get('full_address'),
                'video_url': alert_data.get('video_url'),
                'video_thumbnail': alert_data.get('video_thumbnail'),
                'distance': alert_data.get('distance_to_iov', 0),
                'status': 'new',
                'read': False,
                'delivered_at': int(time.time() * 1000)
            }
            
            # Send to IOV's inbox
            iov_alerts_ref.push().set(iov_alert)
            
            # Update IOV's latest alert
            iov_latest_ref = db.reference(f'iovs/{iov_id}/latest_alert', app=self.app)
            iov_latest_ref.set({
                'alert_id': alert_data.get('id'),
                'timestamp': alert_data.get('timestamp'),
                'type': alert_data.get('type'),
                'distance': alert_data.get('distance_to_iov', 0),
                'video_url': alert_data.get('video_url')
            })
            
            return True
            
        except Exception as e:
            print(f"❌ Error sending alert to IOV {iov_id}: {e}")
            return False

    # ═══════════════════════════════════════════════════════════════════════════
    # MAIN ALERT SENDING
    # ═══════════════════════════════════════════════════════════════════════════

    def send_alert(self, detection_data: dict, frame=None, camera_info=None) -> bool:
        """Send alert ONLY to IOVs within 3km radius of the detecting camera"""
        if not self.initialized:
            print("❌ Firebase not initialized")
            return False

        if camera_info is None:
            print("❌ CRITICAL ERROR: camera_info is None!")
            return False

        try:
            timestamp_ms = int(time.time() * 1000)
            alert_id = f"alert_{self.alert_count}_{timestamp_ms}"
            alert_number = self.alert_count

            weapon_type = detection_data.get('class', 'WEAPON')
            confidence = detection_data.get('confidence', 0.0)
            bbox = detection_data.get('bbox', None)
            
            # Get camera info
            camera_id = camera_info['id']
            camera_name = camera_info['name']
            camera_address = camera_info['address']
            camera_city = camera_info.get('city', camera_address.split(',')[0])
            camera_lat = camera_info['lat']
            camera_lng = camera_info['lng']
            camera_type = camera_info['type']
            
            # Force correct coordinates based on camera ID
            if camera_id == 'CAM_CANTT_001':
                camera_lat = 32.244870
                camera_lng = 74.163715
                camera_city = 'Gujranwala'
            elif camera_id == 'CAM_GRW_001':
                camera_lat = 32.191461
                camera_lng = 74.179374
                camera_city = 'Gujranwala'
            
            print(f"\n📹 Alert from: {camera_name} ({camera_city})")
            print(f"📍 Coordinates: {camera_lat}, {camera_lng}")
            
            # Add frame to buffer and start post-detection recording
            if frame is not None:
                self.add_frame_to_buffer(frame, camera_id)
                self.start_post_detection_recording(camera_id)
                self.add_post_detection_frame(camera_id, frame)
            
            # Build alert data
            alert = {
                'id': alert_id,
                'type': str(weapon_type).upper(),
                'weapon_class': str(weapon_type),
                'class': str(weapon_type),
                'confidence': round(float(confidence), 4),
                'timestamp': timestamp_ms,
                'time': datetime.now().strftime('%H:%M:%S'),
                'date': datetime.now().strftime('%Y-%m-%d'),
                'datetime': datetime.now().isoformat(),
                'status': 'active',
                'priority': detection_data.get('threat_level', 'HIGH'),
                'threat_level': detection_data.get('threat_level', 'HIGH'),
                'camera_id': camera_id,
                'camera_name': camera_name,
                'camera_type': camera_type,
                'Area': camera_address,
                'city': camera_city,
                'location': {
                    'lat': camera_lat,
                    'lng': camera_lng,
                },
                'location_name': camera_address.split(',')[0],
                'full_address': camera_address,
                'frame_count': detection_data.get('frame_count', 0),
                'description': f"{weapon_type} detected at {camera_address}",
                'acknowledged': False
            }

            # Create video from buffer
            buffer_size = self.get_buffer_size(camera_id)
            
            if self.cloudinary_initialized and buffer_size >= 30:
                print(f"📹 Creating video evidence...")
                video_data = self.create_video_from_buffer(alert_number, camera_id)
                
                if video_data and video_data.get('video_url'):
                    alert['video'] = {
                        'url': video_data['video_url'],
                        'thumbnail': video_data.get('thumbnail_url'),
                        'public_id': video_data['public_id'],
                        'duration': video_data.get('duration', 0),
                        'format': video_data.get('format', 'mp4'),
                        'size': video_data.get('bytes', 0),
                        'width': video_data.get('width', 0),
                        'height': video_data.get('height', 0),
                        'fps': video_data.get('fps', 15),
                        'slow_factor': video_data.get('slow_factor', 2.0),
                        'speed': 'NORMAL SPEED',
                        'uploaded_at': datetime.now().isoformat()
                    }
                    alert['video_url'] = video_data['video_url']
                    alert['video_thumbnail'] = video_data.get('thumbnail_url')
                    alert['video_public_id'] = video_data['public_id']
                    alert['has_video'] = True
                    
                    # Clear old frames
                    with self.buffer_lock:
                        if camera_id in self.camera_buffers:
                            recent = [item for item in self.camera_buffers[camera_id] 
                                      if time.time() - item['timestamp'] < 2.0]
                            self.camera_buffers[camera_id] = recent[-30:]
                else:
                    alert['has_video'] = False
            else:
                alert['has_video'] = False

            if bbox and len(bbox) >= 4:
                alert['bbox'] = {
                    'x': int(bbox[0]),
                    'y': int(bbox[1]),
                    'width': int(bbox[2]),
                    'height': int(bbox[3])
                }

            # Get nearby IOVs (3km radius)
            print(f"\n📍 Searching for IOVs within 3km of {camera_city}...")
            nearby_iovs = self.get_nearby_iovs(camera_lat, camera_lng, 3.0)
            
            if nearby_iovs:
                print(f"🚨 Found {len(nearby_iovs)} IOVs to notify!")
                
                alerts_sent = 0
                for iov in nearby_iovs:
                    alert['distance_to_iov'] = iov['distance']
                    
                    if self.send_alert_to_iov(iov['iov_id'], alert, camera_info):
                        alerts_sent += 1
                        print(f"   ✅ Alert sent to {iov['carNumber']} ({iov['distance']}km)")
                
                # Add targeted IOVs to alert
                targeted_iovs = {}
                for i, iov in enumerate(nearby_iovs):
                    targeted_iovs[str(i)] = {
                        'iov_id': iov['iov_id'],
                        'carNumber': iov['carNumber'],
                        'username': iov['username'],
                        'distance': iov['distance']
                    }
                alert['targeted_iovs'] = targeted_iovs
                alert['total_iovs_notified'] = alerts_sent
            else:
                print(f"⏸️ No IOVs within 3km of {camera_city}")
                alert['total_iovs_notified'] = 0
                alert['targeted_iovs'] = {}

            # Save main alert to Firebase
            self.alerts_ref.child(alert_id).set(alert)
            self.latest_ref.set(alert)

            self.alert_count += 1
            
            # Update system stats
            self.stats_ref.update({
                'last_alert_time': timestamp_ms,
                'last_weapon': str(weapon_type).upper(),
                'last_confidence': round(float(confidence), 4),
                'last_camera': camera_name,
                'last_camera_id': camera_id,
                'last_city': camera_city,
                'last_location': {
                    'lat': camera_lat,
                    'lng': camera_lng,
                    'name': camera_address
                },
                'system_status': 'EMERGENCY',
                'total_alerts': self.alert_count,
                'videos_uploaded': self.videos_uploaded,
                'cloudinary_enabled': self.cloudinary_initialized,
                'video_speed': 'SLOW MOTION (15 FPS)',
                'total_iovs_notified': alert.get('total_iovs_notified', 0),
                'iov_range_km': 3,
                'updated_at': datetime.now().isoformat()
            })

            print(f"\n{'🔥' * 20}")
            print(f"🔥 ALERT #{alert_number} SENT TO FIREBASE!")
            print(f"🔥 Type: {weapon_type} | Confidence: {confidence:.2f}")
            print(f"📹 Camera: {camera_name} ({camera_city})")
            print(f"🚗 IOVs Notified: {alert.get('total_iovs_notified', 0)}")
            print(f"📹 Video: {'✅' if alert.get('has_video') else '❌'}")
            print(f"{'🔥' * 20}\n")

            return True

        except Exception as e:
            print(f"❌ Error sending alert: {e}")
            import traceback
            traceback.print_exc()
            return False


# ═══════════════════════════════════════════════════════════════════════════════
# CAMERA HANDLER CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class CameraHandler:
    """Multi-threaded camera handler for multiple camera sources"""
    
    def __init__(self):
        self.cameras = []
        self.active_cameras = 0
        self.frame_queues = {}
        self.threads = []
        self.running = False
        self.working_cameras = []
        
    def add_camera(self, source, camera_info, fps_limit=30):
        """Add new camera - only if it works"""
        try:
            print(f"📹 Testing camera: {camera_info['name']}...")
            
            # Try to open camera
            if isinstance(source, int) or (isinstance(source, str) and source.startswith('http')):
                cap = cv2.VideoCapture(source)
                
                if isinstance(source, str) and 'http' in source:
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)
                    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
                
                if cap.isOpened():
                    ret, test_frame = cap.read()
                    if ret and test_frame is not None:
                        camera_data = {
                            'source': source,
                            'cap': cap,
                            'info': camera_info,
                            'name': camera_info['name'],
                            'camera_id': camera_info['id'],
                            'city': camera_info['city'],
                            'fps_limit': fps_limit,
                            'last_frame': None,
                            'frame_count': 0,
                            'fps': 0,
                            'last_time': time.time()
                        }
                        self.cameras.append(camera_data)
                        self.working_cameras.append(camera_data)
                        self.frame_queues[camera_info['id']] = queue.Queue(maxsize=2)
                        self.active_cameras += 1
                        print(f"✅ Camera WORKING: {camera_info['name']}")
                        return True
                    else:
                        print(f"❌ Camera NOT WORKING: {camera_info['name']} - Cannot read")
                        cap.release()
                        return False
                else:
                    print(f"❌ Camera NOT WORKING: {camera_info['name']} - Cannot open")
                    return False
        except Exception as e:
            print(f"❌ Error testing camera {camera_info['name']}: {e}")
            return False
    
    def camera_reader_thread(self, camera):
        """Separate thread for each camera"""
        name = camera['name']
        camera_id = camera['camera_id']
        cap = camera['cap']
        
        while self.running:
            try:
                ret, frame = cap.read()
                if ret and frame is not None:
                    # Resize if too large
                    if frame.shape[1] > 480:
                        scale = 480 / frame.shape[1]
                        new_width = 480
                        new_height = int(frame.shape[0] * scale)
                        frame = cv2.resize(frame, (new_width, new_height))
                    
                    # Clear queue if full
                    if self.frame_queues[camera_id].full():
                        try:
                            self.frame_queues[camera_id].get_nowait()
                        except:
                            pass
                    
                    # Store frame with camera info
                    self.frame_queues[camera_id].put({
                        'frame': frame,
                        'camera_id': camera_id,
                        'camera_info': camera['info'],
                        'timestamp': time.time()
                    })
                    
                    # Update FPS counter
                    camera['frame_count'] += 1
                    current_time = time.time()
                    if current_time - camera['last_time'] >= 1.0:
                        camera['fps'] = camera['frame_count']
                        camera['frame_count'] = 0
                        camera['last_time'] = current_time
                    
                    time.sleep(1.0 / camera['fps_limit'])
                else:
                    print(f"⚠️ Camera {name} lost connection, reconnecting...")
                    cap.release()
                    time.sleep(2)
                    cap.open(camera['source'])
                    time.sleep(0.1)
            except Exception as e:
                print(f"⚠️ Error in {name} thread: {e}")
                time.sleep(0.1)
    
    def start_all(self):
        """Start all camera threads"""
        self.running = True
        for camera in self.cameras:
            thread = threading.Thread(
                target=self.camera_reader_thread,
                args=(camera,),
                daemon=True
            )
            thread.start()
            self.threads.append(thread)
            print(f"🚀 Started thread for {camera['name']}")
    
    def get_frames(self):
        """Get latest frames from all cameras"""
        frames = []
        for camera in self.cameras:
            camera_id = camera['camera_id']
            try:
                if camera_id in self.frame_queues:
                    frame_data = self.frame_queues[camera_id].get_nowait()
                    frame_data['fps'] = camera['fps']
                    frames.append(frame_data)
            except queue.Empty:
                pass
        return frames
    
    def release_all(self):
        """Release all cameras"""
        self.running = False
        time.sleep(0.5)
        
        for camera in self.cameras:
            try:
                camera['cap'].release()
                print(f"✅ Released camera: {camera['name']}")
            except:
                pass


# ═══════════════════════════════════════════════════════════════════════════════
# INTEGRATED GUN DETECTION SYSTEM CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class IntegratedGunDetectionSystem:
    """Complete integrated system with YOLO detection and agent-based decision making"""

    def __init__(self, model_path: str = "gun.pt", camera_index: int = 0):
        """Initialize the complete weapon detection system"""
        
        print("\n" + "=" * 70)
        print("🎯 INITIALIZING INTEGRATED GUN DETECTION SYSTEM")
        print("=" * 70)
        
        # ═══════════════════════════════════════════════════════════════════
        # INITIALIZE YOLO MODEL
        # ═══════════════════════════════════════════════════════════════════
        
        if YOLO_AVAILABLE:
            self.model = YOLO(model_path)
            print(f"✅ YOLO Model loaded: {model_path}")
        else:
            self.model = None
            print("❌ YOLO not available")

        # ═══════════════════════════════════════════════════════════════════
        # INITIALIZE DETECTION MODULES
        # ═══════════════════════════════════════════════════════════════════
        
        # Human Tracker
        if HUMAN_TRACKER_AVAILABLE:
            self.human_tracker = HumanTracker()
            print("✅ Human Tracker initialized")
        else:
            self.human_tracker = BasicHumanTracker()
            print("⚠️ Using Basic Human Tracker")

        # Pose Detector
        if POSE_DETECTOR_AVAILABLE:
            self.pose_detector = PoseDetector()
            print("✅ Pose Detector initialized")
        else:
            self.pose_detector = BasicPoseDetector()
            print("⚠️ Using Basic Pose Detector")

        # Violence Detector
        if VIOLENCE_DETECTOR_AVAILABLE:
            self.violence_detector = ViolenceDetector()
            self.violence_detector.warmup(8)  # Warm up for faster detection
            print("✅ Violence Detector initialized")
        else:
            self.violence_detector = BasicViolenceDetector()
            print("⚠️ Using Basic Violence Detector")

        # Fire/Smoke Detector
        if FIRE_SMOKE_DETECTOR_AVAILABLE:
            self.fire_smoke_detector = FireSmokeDetector()
            print("✅ Fire/Smoke Detector initialized")
        else:
            self.fire_smoke_detector = BasicFireSmokeDetector()
            print("⚠️ Using Basic Fire/Smoke Detector")

        # ═══════════════════════════════════════════════════════════════════
        # INITIALIZE DECISION ENGINE
        # ═══════════════════════════════════════════════════════════════════
        
        if AGENT_ENGINE_AVAILABLE:
            self.decision_engine = AgentBasedDecisionEngine()
            print("✅ Agent Decision Engine initialized")
            
            # Get evidence agent reference
            if hasattr(self.decision_engine, 'evidence_agent'):
                self.evidence_agent = self.decision_engine.evidence_agent
            else:
                self.evidence_agent = BasicEvidenceAgent()
        else:
            self.decision_engine = BasicDecisionEngine()
            self.evidence_agent = BasicEvidenceAgent()
            print("⚠️ Using Basic Decision Engine")

        # ═══════════════════════════════════════════════════════════════════
        # INITIALIZE ALERT SYSTEM
        # ═══════════════════════════════════════════════════════════════════
        
        if ALERT_SYSTEM_AVAILABLE:
            self.alert_system = AlertSystem(
                camera_id="CAM_001",
                camera_location="Main Security Camera"
            )
            print("✅ Alert System initialized")
        else:
            self.alert_system = BasicAlertSystem()
            print("⚠️ Using Basic Alert System")

        # Firebase Storage
        if FIREBASE_STORAGE_AVAILABLE:
            self.firebase_storage = FirebaseAlertStorage()
            print("✅ Firebase Alert Storage initialized")
        else:
            self.firebase_storage = None
            print("⚠️ Firebase Alert Storage not available")

        # ═══════════════════════════════════════════════════════════════════
        # TRACKING SYSTEM
        # ═══════════════════════════════════════════════════════════════════
        
        self.camera_index = camera_index
        self.cap = None
        self.person_id_counter = 0
        self.active_tracks = {}
        self.frame_count = 0
        self.detection_history = []

        # ═══════════════════════════════════════════════════════════════════
        # EVIDENCE STORAGE
        # ═══════════════════════════════════════════════════════════════════
        
        self.evidence_folder = "evidence"
        self.init_evidence_storage()

        # ═══════════════════════════════════════════════════════════════════
        # CALLBACK SYSTEM
        # ═══════════════════════════════════════════════════════════════════
        
        self._detection_callbacks = []
        self.recent_detections = []
        self.last_detections = []

        # ═══════════════════════════════════════════════════════════════════
        # TIMING AND STATISTICS
        # ═══════════════════════════════════════════════════════════════════
        
        self.start_time = time.time()
        self.fps = 0.0
        self._frame_times = []
        
        self.alert_active = False
        self.last_alert_time = 0

        self.stats = {
            "total_detections": 0,
            "threat_detections": 0,
            "alerts_triggered": 0,
            "evidence_saved": 0,
            "hands_up_detections": 0,
            "violence_detections": 0,
            "activity_detections": {},
        }
        
        print("=" * 70)
        print("✅ INTEGRATED GUN DETECTION SYSTEM READY!")
        print("=" * 70 + "\n")

    # ═══════════════════════════════════════════════════════════════════════════
    # EVIDENCE STORAGE
    # ═══════════════════════════════════════════════════════════════════════════

    def init_evidence_storage(self):
        """Initialize evidence storage folder and database"""
        # Create folders
        os.makedirs(self.evidence_folder, exist_ok=True)
        os.makedirs(f"{self.evidence_folder}/videos", exist_ok=True)
        os.makedirs(f"{self.evidence_folder}/images", exist_ok=True)

        # Initialize SQLite database
        self.db_path = os.path.join(self.evidence_folder, "detections.db")
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS detections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL,
                detection_id TEXT,
                bbox TEXT,
                confidence REAL,
                threat_level TEXT,
                threat_score REAL,
                actions TEXT,
                evidence_path TEXT,
                frame_data BLOB
            )
        """)

        conn.commit()
        conn.close()
        print(f"✅ Evidence storage initialized: {self.evidence_folder}")

    # ═══════════════════════════════════════════════════════════════════════════
    # CALLBACK SYSTEM
    # ═══════════════════════════════════════════════════════════════════════════

    def add_detection_callback(self, callback):
        """Register external callback for weapon/threat detections"""
        self._detection_callbacks.append(callback)
        print(f"✅ Detection callback registered (total: {len(self._detection_callbacks)})")

    def remove_detection_callback(self, callback):
        """Remove a registered callback"""
        if callback in self._detection_callbacks:
            self._detection_callbacks.remove(callback)
            print(f"✅ Detection callback removed")

    def _notify_callbacks(self, detection_data: Dict[str, Any]):
        """Notify all registered callbacks about a detection"""
        self.recent_detections.append(detection_data)
        if len(self.recent_detections) > 100:
            self.recent_detections = self.recent_detections[-100:]

        self.last_detections.append(detection_data)

        for callback in self._detection_callbacks:
            try:
                callback(detection_data)
            except Exception as e:
                print(f"⚠️ Callback error: {e}")

    def _notify_weapon_detected(self, class_name: str, confidence: float,
                                 bbox: list = None, detection_id: int = 0,
                                 weapon_type: str = "Unknown", camera_info: dict = None, frame = None):
        """Notify callbacks about weapon detection"""
        detection = {
            'class': class_name.upper(),
            'confidence': float(confidence),
            'bbox': list(bbox) if bbox else None,
            'type': 'WEAPON',
            'weapon_type': weapon_type,
            'timestamp': time.time(),
            'camera_id': camera_info.get('id', 'CAM_001') if camera_info else 'CAM_001',
            'camera_info': camera_info or {'name': 'Main Camera', 'location': 'Default'},
            'location': camera_info.get('location', 'Default') if camera_info else 'Default',
            'threat_level': 'HIGH' if confidence > 0.7 else 'MEDIUM',
            'detection_id': detection_id,
            'frame_count': self.frame_count,
            'frame': frame
        }
        self._notify_callbacks(detection)

    def _notify_violence_detected(self, person_id: int, confidence: float, bbox: list = None,
                                   camera_info: dict = None, frame = None):
        """Notify callbacks about violence detection"""
        detection = {
            'class': 'VIOLENCE',
            'confidence': float(confidence),
            'bbox': list(bbox) if bbox else None,
            'type': 'VIOLENCE',
            'timestamp': time.time(),
            'camera_id': camera_info.get('id', 'CAM_001') if camera_info else 'CAM_001',
            'camera_info': camera_info or {'name': 'Main Camera', 'location': 'Default'},
            'location': camera_info.get('location', 'Default') if camera_info else 'Default',
            'threat_level': 'HIGH' if confidence > 0.7 else 'MEDIUM',
            'person_id': person_id,
            'frame_count': self.frame_count,
            'frame': frame
        }
        self._notify_callbacks(detection)

    def _notify_fire_smoke_detected(self, detection_type: str, confidence: float,
                                     count: int = 1, bbox: list = None, camera_info: dict = None, frame = None):
        """Notify callbacks about fire/smoke detection"""
        detection = {
            'class': detection_type.upper(),
            'confidence': float(confidence),
            'bbox': list(bbox) if bbox else None,
            'type': detection_type.upper(),
            'timestamp': time.time(),
            'camera_id': camera_info.get('id', 'CAM_001') if camera_info else 'CAM_001',
            'camera_info': camera_info or {'name': 'Main Camera', 'location': 'Default'},
            'location': camera_info.get('location', 'Default') if camera_info else 'Default',
            'threat_level': 'CRITICAL',
            'count': count,
            'frame_count': self.frame_count,
            'frame': frame
        }
        self._notify_callbacks(detection)

    def _update_fps(self):
        """Update FPS counter"""
        current_time = time.time()
        self._frame_times.append(current_time)
        if len(self._frame_times) > 30:
            self._frame_times = self._frame_times[-30:]
        if len(self._frame_times) >= 2:
            elapsed = self._frame_times[-1] - self._frame_times[0]
            if elapsed > 0:
                self.fps = (len(self._frame_times) - 1) / elapsed

    # ═══════════════════════════════════════════════════════════════════════════
    # CAMERA OPERATIONS
    # ═══════════════════════════════════════════════════════════════════════════

    def start_camera(self):
        """Start camera capture"""
        self.cap = cv2.VideoCapture(self.camera_index)
        if not self.cap.isOpened():
            raise Exception(f"Could not open camera {self.camera_index}")

        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 480)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 360)
        self.cap.set(cv2.CAP_PROP_FPS, 30)
        self.cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))

        print(f"✅ Camera {self.camera_index} started")
        return True

    # ═══════════════════════════════════════════════════════════════════════════
    # OBJECT DETECTION
    # ═══════════════════════════════════════════════════════════════════════════

    def detect_objects(self, frame: np.ndarray) -> Tuple[List[Dict], Dict]:
        """Detect objects using YOLO model"""
        if frame is None:
            return [], {'fire_detected': False, 'smoke_detected': False}
        
        # Convert grayscale to BGR if needed
        if len(frame.shape) == 2:
            frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
        elif len(frame.shape) == 3 and frame.shape[2] == 1:
            frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)

        weapon_detections = []
        
        # Run YOLO detection - LOWER CONFIDENCE FOR BETTER DETECTION
        if self.model is not None:
            results = self.model(frame, stream=True, conf=0.30)
            results_list = list(results)

            for r in results_list:
                boxes = r.boxes
                for box in boxes:
                    detection = self.convert_yolo_to_detection(box, frame)
                    if detection:
                        weapon_detections.append(detection)

        # Detect humans
        human_detections = self.human_tracker.detect_humans(frame)

        # Detect fire and smoke
        fire_smoke_result = self.fire_smoke_detector.detect_fire_smoke_in_frame(frame)

        # Combine detections
        all_detections = weapon_detections + human_detections

        # Notify callbacks for fire/smoke with alert filtering
        if fire_smoke_result.get("fire_detected", False):
            fire_detections = fire_smoke_result.get("fire_detections", [])
            
            # Check for any detection that should trigger alert
            alert_detections = [d for d in fire_detections if d.get("should_alert", False)]
            
            if alert_detections:
                # Get highest confidence alert detection
                alert_det = max(alert_detections, key=lambda x: x["confidence"])
                class_name = alert_det.get("class_name", "FIRE")
                confidence = alert_det.get("confidence", 0.9)
                
                alert_type = "EXPLOSION" if alert_det.get("is_explosion", False) else "FIRE"
                print(f"🚨 {alert_type} ALERT SENT: {class_name} ({confidence:.2f})")
            else:
                # Fire detected but below alert threshold
                print(f"🔥 Fire detected (no alert)")
            
        if fire_smoke_result.get("smoke_detected", False):
            print(f"💨 SMOKE DETECTED (not alerting)")

        return all_detections, fire_smoke_result

    def convert_yolo_to_detection(self, box, frame: np.ndarray) -> Optional[Dict[str, Any]]:
        """Convert YOLO detection to agent format"""
        try:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            w, h = x2 - x1, y2 - y1

            conf = float(box.conf[0])
            cls = int(box.cls[0])
            original_class = self.model.names[cls].upper()

            # STRICT WEAPON CLASSIFICATION - Only actual weapons
            if original_class == "GUN":
                class_name = "GUN"
                weapon_type = "Firearm"
            elif original_class == "KNIFE":
                class_name = "KNIFE"
                weapon_type = "Blade Weapon"
            elif original_class == "EXPLOSION":
                class_name = "EXPLOSION"
                weapon_type = "Explosive Threat"
            else:
                # Non-weapon objects - do not classify as weapons
                class_name = original_class
                weapon_type = "Non-Weapon"

            # Update or create track
            person_id = self.update_track(x1, y1, w, h, class_name, conf)

            # Build detection dict
            detection = {
                "id": person_id,
                "bbox": [x1, y1, w, h],
                "person_conf": conf if class_name == "GUN" else 0.0,
                "gun_conf": conf if class_name == "GUN" else 0.0,
                "knife_conf": conf if class_name == "KNIFE" else 0.0,
                "explosion_conf": conf if class_name == "EXPLOSION" else 0.0,
                "violence_detected": False,
                "violence_confidence": 0.0,
                "meta": {
                    "class_name": class_name,
                    "weapon_type": weapon_type,
                    "raw_confidence": conf,
                    "frame": self.frame_count,
                    "camera": self.camera_index,
                },
                "timestamp": time.time(),
                "frame": frame.copy(),
            }

            return detection

        except Exception as e:
            print(f"❌ Error converting detection: {e}")
            return None

    def update_track(self, x: int, y: int, w: int, h: int, class_name: str, conf: float) -> int:
        """Update or create person tracks"""
        center_x, center_y = x + w // 2, y + h // 2

        best_match_id = None
        best_distance = float("inf")

        for track_id, track_info in self.active_tracks.items():
            track_center = track_info["center"]
            distance = np.sqrt(
                (center_x - track_center[0]) ** 2 + (center_y - track_center[1]) ** 2
            )

            if distance < 100 and distance < best_distance:
                best_distance = distance
                best_match_id = track_id

        if best_match_id is None:
            self.person_id_counter += 1
            best_match_id = self.person_id_counter

        self.active_tracks[best_match_id] = {
            "center": (center_x, center_y),
            "bbox": [x, y, w, h],
            "last_seen": self.frame_count,
            "class_name": class_name,
            "confidence": conf,
        }

        self.clean_old_tracks()
        return best_match_id

    def clean_old_tracks(self):
        """Remove tracks not seen recently"""
        current_frame = self.frame_count
        stale_ids = []

        for track_id, track_info in self.active_tracks.items():
            frames_since_last_seen = current_frame - track_info["last_seen"]

            if frames_since_last_seen > 30:  # 1 second at 30fps
                stale_ids.append(track_id)

        for stale_id in stale_ids:
            del self.active_tracks[stale_id]

    # ═══════════════════════════════════════════════════════════════════════════
    # DETECTION PROCESSING
    # ═══════════════════════════════════════════════════════════════════════════

    def process_detections(self, detections: List[Dict[str, Any]], frame: np.ndarray) -> List[Dict[str, Any]]:
        """Process detections through agent-based decision engine"""
        results = []

        self.last_detections = []

        # Update detection history
        self.detection_history.append(detections)
        self.detection_history = self.detection_history[-100:]

        # Add frame to evidence buffer
        if hasattr(self, 'evidence_agent'):
            self.evidence_agent.add_frame_to_buffer(frame, time.time())

        # Detect poses for persons
        person_detections = [
            d for d in detections if d.get("meta", {}).get("class_name") == "PERSON"
        ]
        
        if person_detections and POSE_DETECTOR_AVAILABLE:
            pose_results = self.pose_detector.detect_poses_in_frame(frame, person_detections)

            hands_up_count = self.pose_detector.get_hands_up_count()
            if hands_up_count > self.stats.get("hands_up_detections", 0):
                self.stats["hands_up_detections"] = hands_up_count
                hands_up_ids = self.pose_detector.get_hands_up_person_ids()
                print(f"🙋 HANDS-UP: {hands_up_count} persons (IDs: {hands_up_ids})")

        # Detect violence
        if VIOLENCE_DETECTOR_AVAILABLE:
            violence_results = self.violence_detector.detect_violence_in_frame(frame)
            
            if violence_results.get('violence_detected', False):
                violence_confidence = violence_results.get('violence_confidence', 0.0)
                fight_confidence = violence_results.get('fight_confidence', 0.0)
                
                # Update violence detection stats
                self.stats["violence_detections"] = self.stats.get("violence_detections", 0) + 1
                
                print(f"🥊 VIOLENCE DETECTED: Confidence {violence_confidence:.3f} | Fight: {fight_confidence:.3f}")
                
                # Draw VIOLENCE BOX overlay on frame
                h, w = frame.shape[:2]
                
                # 1. Draw thick red border around entire frame
                border_thickness = 20
                cv2.rectangle(frame, (0, 0), (w, h), COLORS['RED'], border_thickness)
                
                # 2. Draw semi-transparent red overlay
                overlay = frame.copy()
                overlay[:] = (0, 0, 255)  # Red color
                cv2.addWeighted(overlay, 0.2, frame, 0.8, 0, frame)
                
                # 3. Draw VIOLENCE text with background box at top
                violence_text = f"🥊 VIOLENCE DETECTED: {violence_confidence:.2f}"
                text_size = cv2.getTextSize(violence_text, cv2.FONT_HERSHEY_SIMPLEX, 1.2, 3)[0]
                
                # Background box for text
                cv2.rectangle(frame, (10, 10), (20 + text_size[0], 60), COLORS['RED'], -1)
                cv2.putText(frame, violence_text, (20, 50), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1.0, COLORS['WHITE'], 3)
                
                # 4. Draw fight confidence at bottom
                fight_text = f"Fight Confidence: {fight_confidence:.3f}"
                cv2.putText(frame, fight_text, (20, h - 30), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, COLORS['RED'], 2)
                
                # 5. Add flashing warning triangles in corners
                for corner_x, corner_y in [(30, 30), (w-60, 30), (30, h-60), (w-60, h-60)]:
                    pts = np.array([[corner_x+20, corner_y], [corner_x, corner_y+30], [corner_x+40, corner_y+30]], np.int32)
                    cv2.fillPoly(frame, [pts], COLORS['RED'])
                    cv2.putText(frame, "!", (corner_x+15, corner_y+25), 
                               cv2.FONT_HERSHEY_SIMPLEX, 1.0, COLORS['WHITE'], 2)
                
                print(f"🥊 VIOLENCE ALERT READY - Confidence: {violence_confidence:.3f}")

        # Process each detection
        for detection in detections:
            person_id = detection.get("id")
            
            # Add pose info
            if person_id and hasattr(self.pose_detector, 'detected_poses'):
                if person_id in self.pose_detector.detected_poses:
                    pose_info = self.pose_detector.detected_poses[person_id]
                    detection["pose_type"] = pose_info.get("pose_type", "NORMAL")
                    detection["pose_confidence"] = pose_info.get("confidence", 0.0)

            # Add violence info
            if person_id and hasattr(self.violence_detector, 'detected_violence'):
                if person_id in self.violence_detector.detected_violence:
                    violence_info = self.violence_detector.detected_violence[person_id]
                    detection["violence_detected"] = violence_info.get("violence_detected", False)
                    detection["violence_confidence"] = violence_info.get("confidence", 0.0)

            # Process through decision engine
            result = self.decision_engine.process(detection)
            results.append(result)

            # Update stats
            self.stats["total_detections"] += 1
            if result.get("threat_score", 0) > 1.0:
                self.stats["threat_detections"] += 1

            # Save evidence if needed
            if "SAVE_EVIDENCE" in result.get("action", ""):
                self.save_evidence(detection, result, frame)

            # Trigger alert if needed
            if "LOCAL_ALARM" in result.get("action", ""):
                self.trigger_alert(result)

            # Save to database
            self.save_to_database(detection, result, frame)

        return results

    def process_frame(self, frame):
        """Process a single frame"""
        if frame is None:
            return None
        
        try:
            self.frame_count += 1
            self._update_fps()
            
            detections, fire_smoke_result = self.detect_objects(frame)
            results = self.process_detections(detections, frame)
            
            return detections
            
        except Exception as e:
            print(f"❌ Error in process_frame: {e}")
            return None

    # ═══════════════════════════════════════════════════════════════════════════
    # EVIDENCE AND ALERT MANAGEMENT
    # ═══════════════════════════════════════════════════════════════════════════

    def save_evidence(self, detection: Dict[str, Any], result: Dict[str, Any], frame: np.ndarray):
        """Save evidence frame"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"evidence_{detection['id']}_{timestamp}.jpg"
            filepath = f"{self.evidence_folder}/images/{filename}"

            annotated_frame = self.draw_annotations(frame, detection, result)
            cv2.imwrite(filepath, annotated_frame)

            self.stats["evidence_saved"] += 1
            print(f"✅ Evidence saved: {filename}")

        except Exception as e:
            print(f"❌ Error saving evidence: {e}")

    def trigger_alert(self, result: Dict[str, Any]):
        """Trigger alert system"""
        current_time = time.time()

        if current_time - self.last_alert_time < 2:
            return

        self.last_alert_time = current_time
        self.stats["alerts_triggered"] += 1

        self.play_alert_sound(result.get("state", "HIGH"))
        print(f"🚨 ALERT: {result.get('state')} (Score: {result.get('threat_score', 0):.2f})")

    def play_alert_sound(self, threat_level: str):
        """Play alert sound based on threat level"""
        try:
            if platform.system() == "Windows":
                import winsound
                if threat_level in ["CRITICAL", "VIOLENT"]:
                    winsound.Beep(1500, 500)
                elif threat_level in ["HIGH", "ARMED"]:
                    winsound.Beep(1000, 300)
                else:
                    winsound.Beep(800, 200)
            else:
                print("\a")  # Terminal bell
        except Exception as e:
            print(f"⚠️ Alert sound failed: {e}")

    def save_to_database(self, detection: Dict[str, Any], result: Dict[str, Any], frame: np.ndarray):
        """Save detection to SQLite database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            _, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            frame_data = buffer.tobytes()

            cursor.execute("""
                INSERT INTO detections 
                (timestamp, detection_id, bbox, confidence, threat_level,
                 threat_score, actions, evidence_path, frame_data)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                detection.get("timestamp", time.time()),
                detection.get("id", 0),
                json.dumps(detection.get("bbox", [])),
                detection.get("person_conf", 0),
                result.get("state", "UNKNOWN"),
                result.get("threat_score", 0),
                result.get("action", ""),
                f"evidence_{detection.get('id', 0)}.jpg",
                frame_data,
            ))

            conn.commit()
            conn.close()

        except Exception as e:
            print(f"❌ Database error: {e}")

    # ═══════════════════════════════════════════════════════════════════════════
    # DRAWING AND VISUALIZATION
    # ═══════════════════════════════════════════════════════════════════════════

    def get_system_state_color(self, state: str) -> tuple:
        """Get color based on system state"""
        colors = {
            "NORMAL": COLORS['GREEN'],
            "SUSPICIOUS": COLORS['YELLOW'],
            "THREAT_DETECTION": COLORS['ORANGE'],
            "EMERGENCY": COLORS['RED'],
            "MINIMAL": COLORS['GREEN'],
            "LOW": COLORS['YELLOW'],
            "MEDIUM": COLORS['ORANGE'],
            "HIGH": COLORS['RED'],
            "CRITICAL": COLORS['RED'],
            "VIOLENT": COLORS['RED'],
            "ARMED": COLORS['ORANGE'],
        }
        return colors.get(state.upper(), COLORS['WHITE'])

    def draw_annotations(self, frame: np.ndarray, detection: Dict[str, Any], result: Dict[str, Any]) -> np.ndarray:
        """Draw professional annotations on frame"""
        annotated = frame.copy()

        bbox = detection.get("bbox", [0, 0, 0, 0])
        x, y, w, h = bbox
        person_id = detection.get("id", 0)

        system_state = result.get("system_state", "NORMAL").upper()
        color = self.get_system_state_color(system_state)

        # Draw bounding box
        cv2.rectangle(annotated, (x, y), (x + w, y + h), color, 3)

        # Draw label background
        label = f"ID:{person_id} {system_state}"
        score_text = f"Score:{result.get('threat_score', 0):.1f}"

        label_size = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)[0]
        cv2.rectangle(annotated, (x, y - 60), (x + label_size[0] + 20, y), color, -1)

        # Draw labels
        cv2.putText(annotated, label, (x + 10, y - 35),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, COLORS['WHITE'], 2)
        cv2.putText(annotated, score_text, (x + 10, y - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['YELLOW'], 2)

        # Draw weapon confidence if available
        confidences = []
        if detection.get("gun_conf", 0) > 0.1:
            confidences.append(f"Gun:{detection['gun_conf']:.2f}")
        if detection.get("knife_conf", 0) > 0.1:
            confidences.append(f"Knife:{detection['knife_conf']:.2f}")

        if confidences:
            conf_text = " | ".join(confidences)
            cv2.putText(annotated, conf_text, (x, y + h + 25),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.4, COLORS['WHITE'], 1)

        return annotated

    def draw_detections_on_frame(self, frame: np.ndarray, detections: List[Dict[str, Any]]) -> np.ndarray:
        """Draw all detections on frame"""
        annotated_frame = frame.copy()

        for detection in detections:
            bbox = detection.get("bbox", [0, 0, 0, 0])
            x1, y1, w, h = bbox
            x2, y2 = x1 + w, y1 + h

            class_name = detection.get("meta", {}).get("class_name", "Unknown").upper()
            confidence = detection.get("meta", {}).get("raw_confidence", 0)
            person_id = detection.get("id", 0)

            # Color based on detection type
            if class_name in ["GUN", "KNIFE", "WEAPON"]:
                color = COLORS['RED']
                thickness = 3
            elif class_name in ["EXPLOSION"]:
                color = COLORS['ORANGE']
                thickness = 4
            elif class_name == "PERSON":
                color = self.human_tracker.get_id_color(person_id)
                thickness = 2
            else:
                color = COLORS['GREEN']
                thickness = 2

            # Draw bounding box
            cv2.rectangle(annotated_frame, (x1, y1), (x2, y2), color, thickness)

            # Draw label
            label_text = f"{class_name} {confidence:.0%}"
            label_size = cv2.getTextSize(label_text, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 2)[0]

            cv2.rectangle(annotated_frame, (x1, y1 - label_size[1] - 10),
                          (x1 + label_size[0] + 10, y1), color, -1)
            cv2.putText(annotated_frame, label_text, (x1 + 5, y1 - 5),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['WHITE'], 2)

            # Draw ID
            cv2.putText(annotated_frame, f"ID:{person_id}", (x1, y2 + 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.4, color, 1)

        return annotated_frame

    # ═══════════════════════════════════════════════════════════════════════════
    # 4-SECTION UI DISPLAY
    # ═══════════════════════════════════════════════════════════════════════════

    def create_birds_eye_view(self, frame: np.ndarray, detections: List[Dict[str, Any]]) -> np.ndarray:
        """Create bird's eye view of detection area"""
        birds_eye = np.zeros((240, 320, 3), dtype=np.uint8)
        birds_eye.fill(20)

        # Draw grid
        for i in range(0, 320, 40):
            cv2.line(birds_eye, (i, 0), (i, 240), (40, 40, 40), 1)
        for i in range(0, 240, 40):
            cv2.line(birds_eye, (0, i), (320, i), (40, 40, 40), 1)

        # Draw border
        cv2.rectangle(birds_eye, (10, 10), (310, 230), COLORS['GREEN'], 2)

        # Title
        cv2.putText(birds_eye, "BIRD'S EYE VIEW", (80, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['GREEN'], 1)

        # Draw detection points
        for detection in detections:
            bbox = detection.get("bbox", [0, 0, 0, 0])
            if len(bbox) >= 4:
                x, y, w, h = bbox[:4]
                bird_x = int((x + w / 2) * 320 / frame.shape[1])
                bird_y = int((y + h / 2) * 240 / frame.shape[0])

                threat_score = detection.get("threat_score", 0)
                if threat_score > 2.0:
                    color = COLORS['RED']
                elif threat_score > 1.0:
                    color = COLORS['ORANGE']
                else:
                    color = COLORS['GREEN']

                cv2.circle(birds_eye, (bird_x, bird_y), 8, color, -1)
                cv2.circle(birds_eye, (bird_x, bird_y), 10, color, 2)

                cv2.putText(birds_eye, str(detection.get("id", "?")),
                            (bird_x - 5, bird_y - 12),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.3, COLORS['WHITE'], 1)

        return birds_eye

    def create_enhanced_heatmap(self, frame: np.ndarray, detections_history: List) -> np.ndarray:
        """Create enhanced activity heatmap"""
        heatmap = np.zeros((180, 240, 3), dtype=np.uint8)
        heatmap.fill(20)

        cv2.putText(heatmap, "ACTIVITY HEATMAP", (50, 20),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, COLORS['GREEN'], 1)

        if detections_history:
            grid_size = 20
            
            # Draw grid
            for i in range(0, 240, grid_size):
                cv2.line(heatmap, (i, 30), (i, 180), (30, 30, 30), 1)
            for i in range(30, 180, grid_size):
                cv2.line(heatmap, (0, i), (240, i), (30, 30, 30), 1)

            activity_grid = np.zeros((8, 12), dtype=float)

            # Process detection history
            for detection_batch in detections_history[-100:]:
                if isinstance(detection_batch, list):
                    for detection in detection_batch:
                        if isinstance(detection, dict):
                            bbox = detection.get("bbox", [0, 0, 0, 0])
                            if len(bbox) >= 4:
                                x, y, w, h = bbox[:4]
                                center_x = int((x + w / 2) / frame.shape[1] * 12)
                                center_y = int((y + h / 2) / frame.shape[0] * 8)

                                if 0 <= center_x < 12 and 0 <= center_y < 8:
                                    threat_score = detection.get("threat_score", 0.5)
                                    activity_grid[center_y, center_x] += threat_score

            # Apply gaussian blur if available
            if SCIPY_AVAILABLE:
                activity_grid = gaussian_filter(activity_grid, sigma=1.0)

            max_activity = np.max(activity_grid) if np.max(activity_grid) > 0 else 1

            # Draw heatmap cells
            for y in range(8):
                for x in range(12):
                    intensity = activity_grid[y, x] / max_activity

                    # Color gradient: Blue -> Cyan -> Green -> Yellow -> Orange -> Red
                    if intensity < 0.2:
                        color = (int(intensity * 5 * 255), 0, 0)
                    elif intensity < 0.4:
                        ratio = (intensity - 0.2) / 0.2
                        color = (255, int(ratio * 255), 0)
                    elif intensity < 0.6:
                        ratio = (intensity - 0.4) / 0.2
                        color = (255, 255, int((1 - ratio) * 255))
                    elif intensity < 0.8:
                        ratio = (intensity - 0.6) / 0.2
                        color = (int((1 - ratio) * 255), 255, 0)
                    else:
                        ratio = (intensity - 0.8) / 0.2
                        color = (0, int((1 - ratio) * 255), 255)

                    cell_x = x * grid_size
                    cell_y = 30 + y * grid_size

                    cv2.rectangle(heatmap, (cell_x, cell_y),
                                  (cell_x + grid_size, cell_y + grid_size), color, -1)
                    cv2.rectangle(heatmap, (cell_x, cell_y),
                                  (cell_x + grid_size, cell_y + grid_size),
                                  (color[0] // 2, color[1] // 2, color[2] // 2), 1)

        return heatmap

    def create_analytics_panel(self, frame: np.ndarray, detections: List[Dict[str, Any]] = None) -> np.ndarray:
        """Create professional analytics panel"""
        analytics = np.zeros((540, 240, 3), dtype=np.uint8)
        analytics.fill(20)

        cv2.putText(analytics, "THREAT ANALYTICS", (50, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['GREEN'], 2)

        # Calculate system state
        system_state = self._get_enhanced_system_state(detections) if detections else "NORMAL"
        
        # Count current people
        current_people = len([d for d in (detections or [])
                              if d.get("meta", {}).get("class_name") == "PERSON"])

        # Calculate uptime
        uptime_seconds = time.time() - self.start_time
        hours = int(uptime_seconds // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        seconds = int(uptime_seconds % 60)
        uptime_str = f"{hours:02d}:{minutes:02d}:{seconds:02d}"

        # Get system resources
        cpu_usage = 45
        memory_usage = 512
        if PSUTIL_AVAILABLE:
            try:
                cpu_usage = psutil.cpu_percent()
                memory_usage = psutil.virtual_memory().used // (1024 * 1024)
            except:
                pass

        # Analytics data
        analytics_data = [
            ("System State:", system_state.upper(), self.get_system_state_color(system_state)),
            ("", "", COLORS['WHITE']),
            ("👥 People Tracking", "", COLORS['GREEN']),
            ("Current:", str(current_people), COLORS['CYAN']),
            ("Total IDs:", str(self.person_id_counter), COLORS['CYAN']),
            ("", "", COLORS['WHITE']),
            ("🔍 Threat Status", "", COLORS['ORANGE']),
            ("Total Detections:", str(self.stats["total_detections"]), COLORS['WHITE']),
            ("Threat Detections:", str(self.stats["threat_detections"]), COLORS['ORANGE']),
            ("Alerts Triggered:", str(self.stats["alerts_triggered"]), COLORS['RED']),
            ("", "", COLORS['WHITE']),
            ("⚡ System Status", "", COLORS['GREEN']),
            ("FPS:", f"{self.fps:.1f}", COLORS['GREEN']),
            ("CPU:", f"{cpu_usage}%", COLORS['YELLOW']),
            ("Memory:", f"{memory_usage}MB", COLORS['ORANGE']),
            ("", "", COLORS['WHITE']),
            ("📊 Session Info", "", COLORS['CYAN']),
            ("Uptime:", uptime_str, COLORS['CYAN']),
            ("Evidence Files:", str(self.stats["evidence_saved"]), COLORS['CYAN']),
            ("", "", COLORS['WHITE']),
            ("📡 Callbacks", "", COLORS['ORANGE']),
            ("Registered:", str(len(self._detection_callbacks)), COLORS['CYAN']),
            ("RT Alerts:", str(len(self.recent_detections)), COLORS['ORANGE']),
        ]

        y_offset = 50
        for label, value, color in analytics_data:
            if label:
                if label.startswith(("👥", "🔍", "⚡", "📊", "📡")):
                    cv2.putText(analytics, label, (10, y_offset),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.4, color, 1)
                else:
                    cv2.putText(analytics, label, (10, y_offset),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.35, COLORS['LIGHT_GRAY'], 1)
                    cv2.putText(analytics, value, (120, y_offset),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.35, color, 1)
            y_offset += 18

        # Footer
        cv2.putText(analytics, "AI-POWERED SECURITY", (50, 520),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.3, (100, 100, 100), 1)

        return analytics

    def _get_enhanced_system_state(self, detections: List[Dict[str, Any]]) -> str:
        """Get enhanced system state"""
        if not detections:
            return "NORMAL"

        has_weapon = False
        has_aiming = False
        has_hands_up = False

        for detection in detections:
            class_name = detection.get("meta", {}).get("class_name", "").upper()
            activity = detection.get("meta", {}).get("activity", "Unknown")

            if class_name in ["GUN", "KNIFE", "WEAPON"]:
                has_weapon = True

            if activity.upper() in ["AIMING", "HANDSUP"]:
                if activity.upper() == "AIMING":
                    has_aiming = True
                elif activity.upper() == "HANDSUP":
                    has_hands_up = True

        if has_weapon and (has_aiming or has_hands_up):
            return "EMERGENCY"
        elif has_weapon:
            return "WEAPON_DETECTED"
        elif has_aiming or has_hands_up:
            return "SUSPICIOUS"
        else:
            return "NORMAL"

    def create_four_section_display(self, frame: np.ndarray, detections: List[Dict[str, Any]],
                                     results: List[Dict[str, Any]],
                                     fire_smoke_result: Dict[str, Any] = None) -> np.ndarray:
        """Create 4-section display layout"""
        full_screen = np.zeros((720, 1280, 3), dtype=np.uint8)
        full_screen.fill(10)

        # Section 1: Live Feed with Detections (800x600)
        annotated_frame = self.draw_detections_on_frame(frame, detections)
        
        if fire_smoke_result and (fire_smoke_result.get("fire_detected") or
                                   fire_smoke_result.get("smoke_detected")):
            annotated_frame = self.fire_smoke_detector.draw_fire_smoke_on_frame(
                annotated_frame, fire_smoke_result
            )
        
        original_section = cv2.resize(annotated_frame, (800, 600))
        full_screen[60:660, 0:800] = original_section

        # Section 2: Bird's Eye View (240x180)
        birds_eye = self.create_birds_eye_view(frame, detections)
        birds_eye_small = cv2.resize(birds_eye, (240, 180))
        full_screen[60:240, 800:1040] = birds_eye_small

        # Section 3: Heatmap (240x180)
        heatmap = self.create_enhanced_heatmap(frame, self.detection_history)
        heatmap_small = cv2.resize(heatmap, (240, 180))
        full_screen[240:420, 800:1040] = heatmap_small

        # Section 4: Analytics Panel (240x540)
        analytics = self.create_analytics_panel(frame, detections)
        full_screen[60:600, 1040:1280] = analytics

        # Draw section borders
        cv2.rectangle(full_screen, (0, 60), (800, 660), COLORS['GREEN'], 2)
        cv2.rectangle(full_screen, (800, 60), (1040, 240), COLORS['GREEN'], 2)
        cv2.rectangle(full_screen, (800, 240), (1040, 420), COLORS['GREEN'], 2)
        cv2.rectangle(full_screen, (1040, 60), (1280, 600), COLORS['GREEN'], 2)

        # Section labels
        cv2.putText(full_screen, "LIVE FEED", (10, 85),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, COLORS['GREEN'], 2)
        cv2.putText(full_screen, "BIRD'S EYE", (810, 85),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, COLORS['GREEN'], 1)
        cv2.putText(full_screen, "HEATMAP", (860, 265),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, COLORS['GREEN'], 1)
        cv2.putText(full_screen, "ANALYTICS", (1100, 85),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['GREEN'], 2)

        # Main header
        cv2.rectangle(full_screen, (0, 0), (1280, 60), COLORS['DARK_GRAY'], -1)
        cv2.putText(full_screen,
                    "🎯 INTELLIGENT WEAPON DETECTION SYSTEM | AI-Powered Security Monitoring",
                    (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, COLORS['GREEN'], 2)

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        cv2.putText(full_screen, timestamp, (1050, 40),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, COLORS['GREEN'], 1)

        # Bottom status bar
        cv2.rectangle(full_screen, (0, 660), (1280, 720), COLORS['DARK_GRAY'], -1)
        cv2.rectangle(full_screen, (0, 660), (1280, 720), COLORS['GREEN'], 1)

        system_state = self._get_enhanced_system_state(detections) if detections else "NORMAL"
        cb_count = len(self._detection_callbacks)
        rt_count = len(self.recent_detections)

        status_text = (f"State: {system_state} | "
                       f"Total: {self.stats['total_detections']} | "
                       f"Threat: {self.stats['threat_detections']} | "
                       f"FPS: {self.fps:.1f} | "
                       f"Callbacks: {cb_count} | "
                       f"Alerts: {rt_count}")
        cv2.putText(full_screen, status_text, (20, 685),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['LIGHT_GRAY'], 1)

        controls = "[Q] Quit [S] Save [R] Reset [E] Evidence"
        cv2.putText(full_screen, controls, (20, 705),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, COLORS['LIGHT_GRAY'], 1)

        return full_screen

    # ═══════════════════════════════════════════════════════════════════════════
    # UTILITY METHODS
    # ═══════════════════════════════════════════════════════════════════════════

    def reset_statistics(self):
        """Reset all statistics"""
        self.stats = {
            "total_detections": 0,
            "threat_detections": 0,
            "alerts_triggered": 0,
            "evidence_saved": 0,
            "hands_up_detections": 0,
            "violence_detections": 0,
            "activity_detections": {},
        }
        self.recent_detections = []
        self.last_detections = []
        
        if hasattr(self.pose_detector, 'clear_poses'):
            self.pose_detector.clear_poses()
        if hasattr(self.violence_detector, 'clear_fights'):
            self.violence_detector.clear_fights()
        
        print("✅ Statistics reset")

    def save_manual_frame(self, frame: np.ndarray):
        """Manually save current frame"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"manual_capture_{timestamp}.jpg"
        filepath = f"{self.evidence_folder}/images/{filename}"
        cv2.imwrite(filepath, frame)
        print(f"✅ Manual frame saved: {filename}")

    def open_evidence_folder(self):
        """Open evidence folder"""
        import subprocess
        try:
            if platform.system() == "Windows":
                os.startfile(self.evidence_folder)
            else:
                subprocess.run(["xdg-open", self.evidence_folder])
            print(f"✅ Evidence folder opened: {self.evidence_folder}")
        except Exception as e:
            print(f"⚠️ Could not open evidence folder: {e}")

    def cleanup(self):
        """Cleanup resources"""
        if hasattr(self, 'evidence_agent'):
            self.evidence_agent.force_stop_recording()

        if self.cap:
            self.cap.release()
        
        cv2.destroyAllWindows()
        print("\n✅ System shutdown complete")

        # Print final statistics
        print("\n" + "=" * 60)
        print("📊 FINAL STATISTICS")
        print("=" * 60)
        for key, value in self.stats.items():
            print(f"   {key.replace('_', ' ').title()}: {value}")
        print(f"\n   Registered Callbacks: {len(self._detection_callbacks)}")
        print(f"   Total RT Alerts: {len(self.recent_detections)}")
        print("=" * 60)


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN APPLICATION CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class WeaponDetectionApp:
    """Main application combining detection system with Firebase IOV alerts"""
    
    def __init__(self):
        """Initialize the complete weapon detection application"""
        
        print("\n" + "=" * 80)
        print("╔" + "═" * 78 + "╗")
        print("║" + " " * 20 + "🎯 WEAPON DETECTION SYSTEM v9.0" + " " * 27 + "║")
        print("║" + " " * 15 + "Complete Integrated System with IOV Alerts" + " " * 20 + "║")
        print("╚" + "═" * 78 + "╝")
        print("=" * 80 + "\n")
        
        # Initialize Firebase Realtime Database
        self.firebase_rt = FirebaseRealtimeDB()
        
        # Initialize detection system
        self.detection_system = None
        
        # Initialize camera handler
        self.camera_handler = CameraHandler()
        
        # Tracking
        self.last_callback_time = 0
        self.callback_cooldown = 10  # seconds
        self.total_alerts_sent = 0
        self.frame_count = 0
        self.frames_added = 0
        
        # Per-camera tracking with per-detection-type cooldown
        self.last_alert_per_camera_type = {}  # Key: camera_id + detection_type
        self.detected_objects = {}
        self.object_colors = {}
        self.total_unique_objects = 0
        self.object_timeout = 30
        
        self.last_print_time = 0

    def get_object_color(self, object_id):
        """Generate unique color for each object"""
        if object_id not in self.object_colors:
            import hashlib
            hash_obj = hashlib.md5(str(object_id).encode())
            hash_hex = hash_obj.hexdigest()
            
            r = int(hash_hex[0:2], 16) % 200 + 55
            g = int(hash_hex[2:4], 16) % 200 + 55
            b = int(hash_hex[4:6], 16) % 200 + 55
            
            self.object_colors[object_id] = (b, g, r)
        
        return self.object_colors[object_id]

    def cleanup_old_objects(self):
        """Remove old detected objects from memory"""
        current_time = time.time()
        expired_ids = []
        
        for obj_id, last_seen in self.detected_objects.items():
            if current_time - last_seen > self.object_timeout:
                expired_ids.append(obj_id)
        
        for obj_id in expired_ids:
            del self.detected_objects[obj_id]
            if obj_id in self.object_colors:
                del self.object_colors[obj_id]

    def is_duplicate_detection(self, detection_data, camera_id):
        """Check if this is a duplicate detection for a specific camera"""
        bbox = detection_data.get('bbox', None)
        if bbox is None or len(bbox) < 4:
            return False, None
        
        current_time = time.time()
        self.cleanup_old_objects()
        
        # Check for existing objects from same camera
        for obj_id, last_seen in self.detected_objects.items():
            if obj_id.startswith(f"{camera_id}_") and abs(current_time - last_seen) < self.callback_cooldown:
                return True, obj_id
        
        # Create new object ID
        new_obj_id = f"{camera_id}_obj_{self.total_unique_objects}_{int(current_time)}"
        self.detected_objects[new_obj_id] = current_time
        self.total_unique_objects += 1
        
        return False, new_obj_id

    def on_detection_callback(self, detection_data: dict):
        """Callback function triggered when weapon is detected"""
        current_time = time.time()

        # Get camera info
        camera_info = detection_data.get('camera_info')
        if camera_info is None:
            print("❌ No camera_info in detection_data!")
            return
        
        camera_id = camera_info['id']
        
        # Get detection type
        det_class = detection_data.get('class', 'UNKNOWN').lower()
        det_type = detection_data.get('type', '').upper()
        
        # Create unique key for camera + detection type
        cooldown_key = f"{camera_id}_{det_type}"
        
        # Per-camera per-detection-type cooldown
        last_time = self.last_alert_per_camera_type.get(cooldown_key, 0)
        time_since_last = current_time - last_time
        
        if time_since_last < self.callback_cooldown:
            print(f"⏸️ Cooldown for {cooldown_key}: {time_since_last:.1f}s / {self.callback_cooldown}s")
            return

        # Duplicate detection check
        is_duplicate, object_id = self.is_duplicate_detection(detection_data, camera_id)
        if is_duplicate:
            print(f"⏸️ Duplicate detection ignored for {camera_id}")
            return
        
        # Handle VIOLENCE detection
        if det_type == 'VIOLENCE' or 'violence' in det_class:
            confidence = detection_data.get('confidence', 0.0)
            if confidence >= 0.2:  # Violence threshold
                print(f"\n{'🥊' * 20}")
                print(f"🥊 VIOLENCE ALERT: {det_class.upper()} ({confidence:.2f})")
                print(f"📹 Camera: {camera_info['name']} ({camera_id})")
                print(f"{'🥊' * 20}\n")
                
                frame = detection_data.get('frame', None)
                # Send violence alert to Firebase
                if self.firebase_rt.send_alert(detection_data, frame, camera_info):
                    self.last_alert_per_camera_type[cooldown_key] = current_time
                    self.last_callback_time = current_time
                    self.total_alerts_sent += 1
                    print(f"✅ Violence Alert #{self.total_alerts_sent} sent from {camera_info['name']}!")
                else:
                    print(f"❌ Failed to send violence alert from {camera_info['name']}")
                return
            else:
                print(f"⏸️ Violence below threshold: {confidence:.2f} < 0.2")
                return
        
        # Handle FIRE, SMOKE, EXPLOSION detection
        if det_type in ['FIRE', 'SMOKE', 'EXPLOSION']:
            confidence = detection_data.get('confidence', 0.0)
            print(f"\n{'🔥' * 20}")
            print(f"🔥 {det_type} ALERT: ({confidence:.2f})")
            print(f"📹 Camera: {camera_info['name']} ({camera_id})")
            print(f"{'🔥' * 20}\n")
            
            frame = detection_data.get('frame', None)
            if self.firebase_rt.send_alert(detection_data, frame, camera_info):
                self.last_alert_per_camera_type[cooldown_key] = current_time
                self.last_callback_time = current_time
                self.total_alerts_sent += 1
                print(f"✅ {det_type} Alert #{self.total_alerts_sent} sent from {camera_info['name']}!")
            else:
                print(f"❌ Failed to send {det_type} alert from {camera_info['name']}")
            return
        
        # Skip non-weapons for regular weapon detection
        if any(ignore in det_class for ignore in IGNORE_CLASSES):
            print(f"⏸️ Ignoring {det_class} (not a weapon)")
            return
        
        # Check for weapon keywords
        is_weapon = any(weapon in det_class for weapon in WEAPON_CLASSES)
        if not is_weapon:
            print(f"⏸️ Ignoring {det_class} (not recognized as weapon)")
            return

        # Confidence check for weapons
        confidence = detection_data.get('confidence', 0.0)
        if confidence < 0.2:
            print(f"⏸️ Low confidence: {confidence:.2f} < 0.2")
            return
        
        # Add object ID
        if object_id:
            detection_data['object_id'] = object_id
        
        detection_data['camera_id'] = camera_id
        detection_data['threat_level'] = 'HIGH' if confidence > 0.7 else 'MEDIUM'
        detection_data['frame_count'] = self.frame_count

        print(f"\n{'🚨' * 20}")
        print(f"🚨 WEAPON DETECTED: {det_class.upper()} ({confidence:.2f})")
        print(f"📹 Camera: {camera_info['name']} ({camera_id})")
        print(f"{'🚨' * 20}\n")

        frame = detection_data.get('frame', None)
        
        # Send alert to Firebase
        if self.firebase_rt.send_alert(detection_data, frame, camera_info):
            self.last_alert_per_camera_type[cooldown_key] = current_time
            self.last_callback_time = current_time
            self.total_alerts_sent += 1
            print(f"✅ Alert #{self.total_alerts_sent} sent from {camera_info['name']}!")
        else:
            print(f"❌ Failed to send alert from {camera_info['name']}")

    def draw_detections_with_colors(self, frame, detections, camera_id, fps=0):
        """Draw colored boxes around detected objects"""
        if frame is None or detections is None:
            return frame
        
        display_frame = frame.copy()
        
        # Camera-specific styling
        if camera_id == 'CAM_CANTT_001':
            camera_name = "Cantt gate"
            color = COLORS['YELLOW']
        elif camera_id == 'CAM_GRW_001':
            camera_name = "Shahenabad"
            color = COLORS['PURPLE']
        else:
            camera_name = "Unknown"
            color = COLORS['WHITE']
        
        # Draw camera info
        location_text = f"{camera_name} Camera | FPS: {fps}"
        cv2.putText(display_frame, location_text, (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
        
        # Draw detections
        for detection in detections:
            bbox = detection.get('bbox')
            if bbox is None or len(bbox) < 4:
                continue
                
            x1, y1, x2, y2 = map(int, bbox[:4])
            confidence = detection.get('confidence', 0)
            class_name = detection.get('class', 'Unknown').lower()
            
            # Only draw weapons
            is_weapon = any(weapon in class_name for weapon in WEAPON_CLASSES)
            is_ignored = any(ignore in class_name for ignore in IGNORE_CLASSES)
            
            if is_weapon and not is_ignored:
                cv2.rectangle(display_frame, (x1, y1), (x2, y2), COLORS['RED'], 3)
                
                label = f"{class_name.upper()} {confidence:.2f}"
                label_size = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 2)[0]
                
                cv2.rectangle(display_frame, (x1, y1 - label_size[1] - 10),
                              (x1 + label_size[0] + 10, y1), COLORS['RED'], -1)
                cv2.putText(display_frame, label, (x1 + 5, y1 - 5),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['WHITE'], 2)
        
        return display_frame

    def combine_frames(self, frames_list):
        """Combine camera feeds into one screen"""
        if not frames_list:
            return None
        
        processed_frames = []
        for frame_data in frames_list:
            if frame_data and frame_data['frame'] is not None:
                frame = cv2.resize(frame_data['frame'], (640, 480))
                processed_frames.append({
                    'frame': frame,
                    'camera_id': frame_data['camera_id'],
                    'fps': frame_data.get('fps', 0)
                })
        
        if len(processed_frames) == 2:
            # Side-by-side view
            combined = np.hstack([processed_frames[0]['frame'], processed_frames[1]['frame']])
            
            # Add status info
            stats_text = (f"Total Alerts: {self.total_alerts_sent} | "
                          f"Videos: {self.firebase_rt.videos_uploaded} | "
                          f"3km IOV Range")
            cv2.putText(combined, stats_text, (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, COLORS['GREEN'], 2)
            
            # Camera labels
            cv2.putText(combined, "Cantt gate (Laptop) - 3km", (10, 60),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, COLORS['YELLOW'], 2)
            cv2.putText(combined, "Shahenabad (Mobile) - 3km", (650, 60),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, COLORS['PURPLE'], 2)
            
            # FPS counters
            cv2.putText(combined, f"FPS: {processed_frames[0]['fps']}", (10, 90),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['GREEN'], 2)
            cv2.putText(combined, f"FPS: {processed_frames[1]['fps']}", (650, 90),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS['GREEN'], 2)
            
            return combined
            
        elif len(processed_frames) == 1:
            frame = processed_frames[0]['frame']
            cv2.putText(frame, f"Alerts: {self.total_alerts_sent} | 3km IOV Range",
                        (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, COLORS['GREEN'], 2)
            return frame
        else:
            return None

    def setup_cameras(self):
        """Setup cameras with locations - MOBILE ONLY"""
        print("\n" + "=" * 60)
        print("📹 SETTING UP CAMERAS (Mobile IP Camera Only)")
        print("=" * 60)
        
        working_count = 0
        
        # Camera 2: Gujranwala (Mobile IP Webcam) - ONLY CAMERA ENABLED
        mobile_url = "http://192.168.1.11:8080/video?fps=30&resolution=640x480"
        if self.camera_handler.add_camera(mobile_url, self.firebase_rt.CAMERA_GUJRANWALA, fps_limit=30):
            working_count += 1
            print(f"✅ {self.firebase_rt.CAMERA_GUJRANWALA['name']} - WORKING")
        else:
            print(f"❌ {self.firebase_rt.CAMERA_GUJRANWALA['name']} - NOT WORKING")
            print("   📱 Make sure IP Webcam is running on your phone")
        
        print(f"\n📊 WORKING CAMERAS: {working_count} / 1")
        
        if working_count == 0:
            print("❌ No working cameras found!")
            return False
        
        self.camera_handler.start_all()
        time.sleep(1)
        
        return True

    def run(self):
        """Main application loop with 4-Section UI"""
        
        print("\n" + "=" * 80)
        print("🎯 WEAPON DETECTION SYSTEM - 3KM IOV FILTERING + 4-SECTION UI")
        print("=" * 80)
        print("📍 Camera 1: Cantt gate→ IOVs within 3km of Rahwali")
        print("📍 Camera 2: Shahenabad → IOVs within 3km of Gujranwala")
        print("-" * 80)
        print(f"🔥 Firebase: {'✅' if self.firebase_rt.initialized else '❌'}")
        print(f"☁️ Cloudinary: {'✅' if self.firebase_rt.cloudinary_initialized else '❌'}")
        print("=" * 80)

        # Check for model
        model_path = "models/gun.pt"
        if not os.path.exists(model_path):
            print(f"❌ Model not found: {model_path}")
            return

        try:
            # Initialize detection system
            print("🚀 Initializing detection system...")
            self.detection_system = IntegratedGunDetectionSystem(model_path)
            print("✅ Detection system ready\n")

            # Setup cameras
            if not self.setup_cameras():
                print("❌ No cameras available")
                return

            # Pre-buffer frames
            if self.firebase_rt.cloudinary_initialized:
                print(f"\n{'📹' * 20}")
                print("📹 PRE-BUFFERING FRAMES...")
                print(f"{'📹' * 20}\n")
                
                prebuffer_count = 0
                prebuffer_target = 300  # 10 seconds at 30fps
                
                while prebuffer_count < prebuffer_target:
                    frames = self.camera_handler.get_frames()
                    for frame_data in frames:
                        if frame_data['frame'] is not None:
                            self.firebase_rt.add_frame_to_buffer(
                                frame_data['frame'],
                                frame_data['camera_id']
                            )
                            prebuffer_count += 1
                    
                    if prebuffer_count < prebuffer_target:
                        time.sleep(0.01)  # Fast pre-buffering
                
                print(f"✅ PRE-BUFFER COMPLETE: {prebuffer_count} frames")
                time.sleep(1)

            # Main loop
            print("\n" + "=" * 60)
            print("🚀 STARTING WEAPON DETECTION WITH 4-SECTION UI...")
            print("=" * 60)
            print("📍 WORKING CAMERAS:")
            for cam in self.camera_handler.working_cameras:
                print(f"   ✅ {cam['name']} - {cam['city']}")
            print("=" * 60)
            print("Press 'q' to quit | 's' to save | 'r' to reset\n")
            
            # Frame processing optimizations - MAXIMUM DETECTION ACCURACY
            process_every_n_frames = 1  # Process EVERY frame - NO SKIPPING
            ui_update_every_n_frames = 1  # Update UI every frame - INSTANT RESPONSE
            frame_skip_count = 0
            
            while True:
                loop_start = time.time()
                
                frames_data = self.camera_handler.get_frames()
                
                # Store all detections for UI
                all_detections = []
                all_results = []
                primary_frame = None
                fire_smoke_result = None
                
                # Process EVERY frame - NO SKIPPING FOR MAXIMUM ACCURACY
                for frame_data in frames_data:
                    frame = frame_data['frame']
                    camera_id = frame_data['camera_id']
                    camera_info = frame_data['camera_info']
                    camera_fps = frame_data.get('fps', 0)
                    
                    if frame is None:
                        continue
                    
                    self.frame_count += 1
                    
                    # Use first camera's frame for UI
                    if primary_frame is None:
                        primary_frame = frame.copy()
                    
                    # Add to buffer (every frame)
                    if self.firebase_rt.cloudinary_initialized:
                        self.firebase_rt.add_post_detection_frame(camera_id, frame)
                        self.frames_added += 1
                    
                    # NO FRAME SKIPPING - PROCESS EVERY SINGLE FRAME
                    try:
                        # Detect objects (optimized)
                        detections, fire_smoke = self.detection_system.detect_objects(frame)
                        
                        # Check for fire/smoke detection and trigger alerts
                        if fire_smoke and fire_smoke.get('fire_detected'):
                            fire_detections = fire_smoke.get('fire_detections', [])
                            alert_detections = [d for d in fire_detections if d.get('should_alert', False)]
                            
                            if alert_detections:
                                alert_det = max(alert_detections, key=lambda x: x['confidence'])
                                alert_type = "EXPLOSION" if alert_det.get('is_explosion', False) else "FIRE"
                                
                                fire_alert_data = {
                                    'class': alert_type,
                                    'confidence': alert_det.get('confidence', 0.9),
                                    'bbox': alert_det.get('bbox'),
                                    'type': alert_type,
                                    'camera_id': camera_id,
                                    'camera_info': camera_info,
                                    'frame': frame,
                                    'timestamp': time.time()
                                }
                                self.on_detection_callback(fire_alert_data)
                        
                        # Check for smoke detection and trigger callback
                        if fire_smoke and fire_smoke.get('smoke_detected'):
                            smoke_alert_data = {
                                'class': 'SMOKE',
                                'confidence': fire_smoke.get('smoke_confidence', 0.8),
                                'bbox': None,
                                'type': 'SMOKE',
                                'camera_id': camera_id,
                                'camera_info': camera_info,
                                'frame': frame,
                                'timestamp': time.time()
                            }
                            self.on_detection_callback(smoke_alert_data)
                        
                        # Store fire/smoke result
                        if fire_smoke_result is None:
                            fire_smoke_result = fire_smoke
                        
                        # Process detections (optimized)
                        results = self.detection_system.process_detections(detections, frame)
                        
                        # Check for violence detection and trigger callback
                        # Use detection results which contain violence info added by process_detections
                        violence_detected = False
                        violence_confidence = 0.0
                        
                        # Check detection results for violence info (more reliable than polling flag)
                        for detection in detections:
                            if detection.get('violence_detected', False):
                                violence_detected = True
                                violence_confidence = max(violence_confidence, 
                                    detection.get('violence_confidence', 0.0))
                        
                        # Also check stats counter as backup
                        if not violence_detected and hasattr(self.detection_system, 'stats'):
                            if self.detection_system.stats.get('violence_detections', 0) > 0:
                                # Stats say violence detected but flag may be cleared
                                # Check violence detector for current confidence
                                if hasattr(self.detection_system, 'violence_detector'):
                                    vd = self.detection_system.violence_detector
                                    # Use smoothed_confidence which persists longer
                                    if hasattr(vd, 'smoothed_confidence'):
                                        conf = vd.smoothed_confidence
                                        if conf >= 0.2:
                                            violence_detected = True
                                            violence_confidence = conf
                        
                        # Trigger violence callback if detected
                        if violence_detected and violence_confidence >= 0.2:
                            violence_alert_data = {
                                'class': 'VIOLENCE',
                                'confidence': violence_confidence,
                                'bbox': None,
                                'type': 'VIOLENCE',
                                'camera_id': camera_id,
                                'camera_info': camera_info,
                                'frame': frame,
                                'timestamp': time.time()
                            }
                            self.on_detection_callback(violence_alert_data)
                            # Reset stats counter after triggering to prevent repeated alerts
                            if hasattr(self.detection_system, 'stats'):
                                self.detection_system.stats['violence_detections'] = 0
                        
                        # Extract weapon detections
                        weapon_detections = []
                        for detection in detections:
                            meta = detection.get('meta', {})
                            det_class = meta.get('class_name', '').lower()
                            
                            confidence = (
                                detection.get('gun_conf', 0) or
                                detection.get('knife_conf', 0) or
                                meta.get('raw_confidence', 0)
                            )
                            
                            # Skip non-weapons
                            if any(ignore in det_class for ignore in IGNORE_CLASSES):
                                continue
                            
                            # Check for weapons
                            is_weapon = any(weapon in det_class
                                            for weapon in WEAPON_CLASSES + EXPLOSIVE_CLASSES)
                            if not is_weapon:
                                continue
                            
                            if confidence < 0.2:
                                continue
                            
                            weapon_detections.append(detection)
                        
                        # Trigger weapon alerts for each detected weapon
                        for weapon_det in weapon_detections:
                            # Determine specific weapon type from confidence values
                            gun_conf = weapon_det.get('gun_conf', 0)
                            knife_conf = weapon_det.get('knife_conf', 0)
                            explosion_conf = weapon_det.get('explosion_conf', 0)
                            grenade_conf = weapon_det.get('grenade_conf', 0)
                            meta = weapon_det.get('meta', {})
                            
                            # Find the weapon type with highest confidence
                            weapon_types = [
                                ('GUN', gun_conf),
                                ('KNIFE', knife_conf),
                                ('EXPLOSION', explosion_conf),
                                ('GRENADE', grenade_conf)
                            ]
                            weapon_class, weapon_conf = max(weapon_types, key=lambda x: x[1])
                            
                            # Fallback to meta class_name if all confidences are 0
                            if weapon_conf == 0:
                                raw_class = meta.get('class_name', 'WEAPON').upper()
                                weapon_conf = meta.get('raw_confidence', 0)
                                # Map generic 'weapon' or 'gun' to GUN
                                if raw_class in ['WEAPON', 'GUN']:
                                    weapon_class = 'GUN'
                                elif raw_class == 'KNIFE':
                                    weapon_class = 'KNIFE'
                                elif raw_class in ['EXPLOSION', 'BOMB']:
                                    weapon_class = 'EXPLOSION'
                                elif raw_class == 'GRENADE':
                                    weapon_class = 'GRENADE'
                                else:
                                    weapon_class = raw_class
                            
                            bbox = weapon_det.get('bbox')
                            
                            weapon_alert_data = {
                                'class': weapon_class,
                                'confidence': weapon_conf,
                                'bbox': bbox,
                                'type': 'WEAPON',
                                'camera_id': camera_id,
                                'camera_info': camera_info,
                                'frame': frame,
                                'timestamp': time.time()
                            }
                            self.on_detection_callback(weapon_alert_data)
                            print(f"🎯 WEAPON ALERT: {weapon_class} ({weapon_conf:.2f}) on {camera_id}")
                        
                        all_detections.extend(detections)
                        all_results.extend(results)
                        
                    except Exception as e:
                        print(f"⚠️ Error on camera {camera_id}: {e}")
                
                # CREATE 4-SECTION UI DISPLAY (Optimized)
                # ═══════════════════════════════════════════════════════
                if primary_frame is not None and self.frame_count % ui_update_every_n_frames == 0:
                    try:
                        # Create 4-section display (optimized)
                        ui_frame = self.detection_system.create_four_section_display(
                            primary_frame,
                            all_detections,
                            all_results,
                            fire_smoke_result
                        )
                        
                        # Add FPS overlay
                        fps_text = f"FPS: {self.detection_system.fps:.1f}"
                        cv2.putText(ui_frame, fps_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                        
                        # Show the UI
                        cv2.imshow("Intelligent Weapon Detection System - 4 Section View", ui_frame)
                        
                    except Exception as e:
                        print(f"⚠️ UI Error: {e}")
                        # Fallback to simple display
                        cv2.imshow("Weapon Detection", primary_frame)
                
                # Handle keyboard input
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    print("\n👋 Quit signal received")
                    break
                elif key == ord('s'):
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    filename = f"screenshot_{timestamp}.jpg"
                    if 'ui_frame' in locals() and ui_frame is not None:
                        cv2.imwrite(filename, ui_frame)
                    elif primary_frame is not None:
                        cv2.imwrite(filename, primary_frame)
                    print(f"✅ Screenshot saved: {filename}")
                elif key == ord('r'):
                    if hasattr(self.detection_system, 'reset_statistics'):
                        self.detection_system.reset_statistics()
                    print(" Statistics reset")
                elif key == ord('e'):
                    if hasattr(self.detection_system, 'open_evidence_folder'):
                        self.detection_system.open_evidence_folder()
                
                # Frame rate limiting - PERFECT DETECTION MODE
                loop_time = time.time() - loop_start
                target_frame_time = 0.025  # 40 FPS - PERFECT for detection
                
                if loop_time < target_frame_time:
                    time.sleep(target_frame_time - loop_time)
                
                # Update FPS counter
                if self.frame_count % 30 == 0:
                    current_fps = 1.0 / max(loop_time, 0.001)
                    print(f"🎯 Current FPS: {current_fps:.1f} | Target: 40.0")
            
            self.camera_handler.release_all()
            cv2.destroyAllWindows()

        except KeyboardInterrupt:
            print("\n👋 Stopped by user (Ctrl+C)")
        except Exception as e:
            print(f"\n❌ System error: {e}")
            import traceback
            traceback.print_exc()
        finally:
            self._print_final_stats()

    def _print_final_stats(self):
        """Print final statistics"""
        print("\n" + "=" * 60)
        print("📊 FINAL STATISTICS")
        print("=" * 60)
        print(f"   Total alerts sent: {self.total_alerts_sent}")
        print(f"   Videos uploaded: {self.firebase_rt.videos_uploaded}")
        print(f"   IOV Range: 3km PER CAMERA")
        print(f"   Working cameras: {len(self.camera_handler.working_cameras)}")
        print(f"   Frames processed: {self.frame_count}")
        print("=" * 60)

        # Update Firebase status
        if self.firebase_rt.initialized:
            try:
                self.firebase_rt.stats_ref.update({
                    'system_status': 'OFFLINE',
                    'shutdown_time': datetime.now().isoformat(),
                    'total_alerts': self.total_alerts_sent,
                    'videos_uploaded': self.firebase_rt.videos_uploaded,
                    'active_cameras': len(self.camera_handler.working_cameras),
                    'iov_range_km': 3
                })
                print("✅ Firebase status updated")
            except Exception as e:
                print(f"⚠️ Could not update Firebase: {e}")

# ... (rest of the code remains the same)

def main():
    """Main entry point for the weapon detection system"""
    
    print("\n")
    print("╔" + "═" * 78 + "╗")
    print("║" + " " * 78 + "║")
    print("║" + " " * 15 + "🎯 INTELLIGENT WEAPON DETECTION SYSTEM 🎯" + " " * 22 + "║")
    print("║" + " " * 20 + "AI-Powered Real-Time Security Monitoring" + " " * 17 + "║")
    print("║" + " " * 78 + "║")
    print("║" + " " * 25 + "Version 9.0 - Ultimate Edition" + " " * 22 + "║")
    print("║" + " " * 78 + "║")
    print("╠" + "═" * 78 + "╣")
    print("║  Features:                                                                  ║")
    print("║  ✅ Multi-Camera Support (Laptop + Mobile IP Webcam)                        ║")
    print("║  ✅ YOLO Weapon Detection (Gun, Knife, Explosion)                          ║")
    print("║  ✅ 3km IOV Radius Filtering Per Camera                                     ║")
    print("║  ✅ Firebase Realtime Database Integration                                  ║")
    print("║  ✅ Cloudinary Video Upload (Slow Motion Evidence)                          ║")
    print("║  ✅ Agent-Based Decision Engine                                             ║")
    print("║  ✅ Violence & Pose Detection                                               ║")
    print("║  ✅ Fire & Smoke Detection                                                  ║")
    print("║  ✅ 4-Section Professional UI                                               ║")
    print("║  ✅ External Callback System                                                ║")
    print("╚" + "═" * 78 + "╝")
    print("\n")
    
    # Run application
    app = WeaponDetectionApp()
    app.run()


if __name__ == "__main__":
    main()
    