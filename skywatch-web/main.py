from flask import Flask, render_template, Response, jsonify, request, redirect, url_for, session
import cv2
import numpy as np
import threading
import json
import time
import os
import platform
from datetime import datetime

# Cross-platform beep sound (works on both Windows and Linux)
def play_alert_beep():
    """Play alert beep sound cross-platform"""
    if platform.system() == 'Windows':
        try:
            import winsound
            winsound.Beep(1000, 500)
        except:
            pass
    else:
        # Linux/Mac - try different methods
        try:
            os.system('play -nq -t alsa synth 0.5 sine 1000')
        except:
            try:
                os.system('beep')
            except:
                pass

# --- CONFIGURATION ---
BROKER_ADDRESS = "localhost"
TOPIC_ALERT = "swarm/alert/violence"

# --- GLOBAL STATE ---
app = Flask(__name__)
app.secret_key = 'skywatch_surveillance_2024'

# Mock data for demo (without YOLO)
def mock_detection():
    """Mock weapon detection for demo purposes"""
    import random
    threats = ["KNIFE", "GUN", "FIGHT", "SUSPICIOUS"]
    locations = ["Wazirabad", "Gujranwala", "Sialkot", "Lahore"]
    
    if random.random() < 0.1:  # 10% chance of detection
        return {
            'weapon': random.choice(threats),
            'location': random.choice(locations),
            'confidence': random.uniform(0.7, 0.95),
            'timestamp': datetime.now().isoformat()
        }
    return None

# --- ROUTES ---
@app.route('/')
def index():
    return render_template('1st.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        # Simple authentication (you can make this more secure)
        if username and password:
            session['username'] = username
            return redirect('/dash')
        else:
            return render_template('login.html', error="Invalid credentials")
    
    return render_template('login.html')

@app.route('/dash')
def dashboard():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('dash.html')

@app.route('/dashboard')
def dashboard_redirect():
    return redirect('/dash')

@app.route('/alerts')
def alerts():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('alerts.html')

@app.route('/logs')
def logs():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('logs.html')

@app.route('/analytics')
def analytics():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('analytics.html')

@app.route('/profile')
def profile():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('profile.html')

@app.route('/map')
def map_page():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('map.html')

@app.route('/iovs')
def iovs_page():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('iov.html')

@app.route('/iov')
def iov_page():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('iov.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# --- MOCK CAMERA FEEDS ---
def generate_camera_feed(camera_id):
    """Generate simulated camera feed"""
    while True:
        # Create a simple frame (black with some noise)
        frame = np.random.randint(0, 50, (480, 640, 3), dtype=np.uint8)
        
        # Add camera ID text
        cv2.putText(frame, f'CAMERA {camera_id}', (50, 50), 
                   cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        cv2.putText(frame, datetime.now().strftime('%H:%M:%S'), (50, 100), 
                   cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        
        # Add random detection indicator
        if np.random.random() < 0.05:  # 5% chance
            cv2.putText(frame, 'THREAT DETECTED', (200, 240), 
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
        
        ret, buffer = cv2.imencode('.jpg', frame)
        frame = buffer.tobytes()
        
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

@app.route('/video_feed/<int:camera_id>')
def video_feed(camera_id):
    return Response(generate_camera_feed(camera_id),
                   mimetype='multipart/x-mixed-replace; boundary=frame')

# --- MOCK API ENDPOINTS ---
@app.route('/api/alerts')
def get_alerts():
    """Mock alerts API"""
    mock_alerts = [
        {
            'id': '1',
            'type': 'CRITICAL',
            'weapon': 'KNIFE',
            'location': 'Wazirabad',
            'confidence': 0.85,
            'timestamp': datetime.now().isoformat(),
            'camera_id': 'CAM_WZD_001'
        },
        {
            'id': '2',
            'type': 'MEDIUM',
            'weapon': 'FIGHT',
            'location': 'Shahenabad',
            'confidence': 0.75,
            'timestamp': datetime.now().isoformat(),
            'camera_id': 'CAM_GRW_001'
        }
    ]
    return jsonify(mock_alerts)

@app.route('/api/stats')
def get_stats():
    """Mock system stats"""
    return jsonify({
        'total_alerts': 12,
        'active_threats': 2,
        'cameras_online': 2,
        'system_status': 'OPERATIONAL'
    })

if __name__ == "__main__":
    print("\n" + "="*60)
    print("🔥 SURVEILLANCE SYSTEM - DEMO MODE 🔥")
    print("="*60)
    print("✅ Demo Mode: Simulated Detection")
    print("✅ Device: CPU")
    print("✅ Camera Feeds: Simulated")
    print("✅ Running on http://0.0.0.0:5000")
    print("="*60 + "\n")
    
    # Use PORT from environment for Render, default to 5000 for local
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True, threaded=True)
