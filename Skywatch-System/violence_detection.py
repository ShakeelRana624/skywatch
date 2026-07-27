"""
Violence Detection Module
Uses trained CNN-LSTM model for fight/violence detection
"""

import torch
import torch.nn as nn
from torchvision import transforms, models
import cv2
import numpy as np
import os
from collections import deque
import time

class ViolenceDetector:
    """Violence/Fight Detection using CNN-LSTM model"""
    
    def __init__(self, model_path="models/best_model_fold_3.pth", device=None):
        """
        Initialize Violence Detector
        
        Args:
            model_path: Path to trained model weights
            device: PyTorch device (auto-detect if None)
        """
        self.model_path = model_path
        self.device = device if device else torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.seq_len = 8  # Reduced from 16 for faster detection
        self.frame_buffer = deque(maxlen=self.seq_len)
        self.transform = None
        self.model = None
        self.last_prediction_time = 0
        self.prediction_interval = 0.1  # 10 FPS - balanced speed/accuracy
        self.current_violence_confidence = 0.0
        self.violence_detected = False
        self.detection_threshold = 0.2  # Lowered for more sensitivity
        
        # Smoothing and accuracy improvements - weighted recent frames
        self.confidence_history = deque(maxlen=3)  # Reduced from 5
        self.smoothed_confidence = 0.0
        self.min_violence_frames = 1  # Reduced for faster trigger
        self.violence_frame_count = 0
        
        # Initialize model and transforms
        self._init_model()
        self._init_transforms()
        
        print(f"🥊 Violence Detector initialized on {self.device}")
        print(f"📁 Model: {model_path}")
        print(f"🎬 Sequence length: {self.seq_len}")

    def _init_model(self):
        """Initialize CNN-LSTM model architecture"""
        try:
            self.model = CNN_LSTM().to(self.device)
            
            # Load trained weights
            if os.path.exists(self.model_path):
                checkpoint = torch.load(self.model_path, map_location=self.device)
                self.model.load_state_dict(checkpoint)
                self.model.eval()
                print(f"✅ Model weights loaded from {self.model_path}")
            else:
                print(f"⚠️ Model file not found: {self.model_path}")
                print("   Violence detection will not work until model is provided")
                
        except Exception as e:
            print(f"❌ Error loading violence detection model: {e}")
            self.model = None

    def _init_transforms(self):
        """Initialize frame transforms for model input"""
        self.transform = transforms.Compose([
            transforms.ToPILImage(),
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])

    def detect_violence_in_frame(self, frame):
        """
        Detect violence in a single frame
        
        Args:
            frame: Input frame (BGR format from OpenCV)
            
        Returns:
            dict: Detection results with confidence and violence status
        """
        if self.model is None:
            return {
                'violence_detected': False,
                'violence_confidence': 0.0,
                'fight_confidence': 0.0,
                'non_fight_confidence': 0.0,
                'error': 'Model not loaded'
            }
        
        current_time = time.time()
        
        # Add frame to buffer
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        self.frame_buffer.append(rgb_frame)
        
        # Only make prediction if we have enough frames and enough time has passed
        if len(self.frame_buffer) == self.seq_len and \
           current_time - self.last_prediction_time >= self.prediction_interval:
            
            try:
                # Prepare sequence
                frames_tensor = []
                for frame_rgb in self.frame_buffer:
                    if self.transform:
                        transformed = self.transform(frame_rgb)
                        frames_tensor.append(transformed)
                
                # Stack frames into batch format
                sequence = torch.stack(frames_tensor).unsqueeze(0)  # [1, seq_len, C, H, W]
                sequence = sequence.to(self.device)
                
                # Make prediction
                with torch.no_grad():
                    outputs = self.model(sequence)
                    probabilities = torch.softmax(outputs, dim=1)
                    
                    # Extract probabilities
                    non_fight_conf = probabilities[0][0].item()
                    fight_conf = probabilities[0][1].item()
                    
                    # Add to confidence history for smoothing
                    self.confidence_history.append(fight_conf)
                    
                    # Calculate weighted smoothed confidence (recent frames weighted more)
                    if len(self.confidence_history) > 0:
                        weights = [0.5, 0.3, 0.2][:len(self.confidence_history)]
                        weights = [w/sum(weights) for w in weights]
                        self.smoothed_confidence = sum(c * w for c, w in zip(self.confidence_history, weights))
                    else:
                        self.smoothed_confidence = fight_conf
                    
                    # Update current state with smoothed confidence
                    self.current_violence_confidence = self.smoothed_confidence
                    
                    # Check if violence detected with smoothing
                    if self.smoothed_confidence > self.detection_threshold:
                        self.violence_frame_count += 1
                        if self.violence_frame_count >= self.min_violence_frames:
                            self.violence_detected = True
                    else:
                        self.violence_frame_count = 0
                        self.violence_detected = False
                    
                    self.last_prediction_time = current_time
                
                return {
                    'violence_detected': self.violence_detected,
                    'violence_confidence': self.smoothed_confidence,
                    'fight_confidence': fight_conf,
                    'non_fight_confidence': non_fight_conf,
                    'smoothed_confidence': self.smoothed_confidence,
                    'raw_confidence': fight_conf,
                    'error': None
                }
                
            except Exception as e:
                print(f"❌ Error in violence detection: {e}")
                return {
                    'violence_detected': False,
                    'violence_confidence': 0.0,
                    'fight_confidence': 0.0,
                    'non_fight_confidence': 0.0,
                    'error': str(e)
                }
        
        # Return last known state if not ready for new prediction
        return {
            'violence_detected': self.violence_detected,
            'violence_confidence': self.current_violence_confidence,
            'fight_confidence': self.current_violence_confidence,
            'non_fight_confidence': 1.0 - self.current_violence_confidence,
            'error': None
        }

    def reset_buffer(self):
        """Reset the frame buffer for new detection sequence"""
        self.frame_buffer.clear()
        self.confidence_history.clear()
        self.current_violence_confidence = 0.0
        self.violence_detected = False
        self.violence_frame_count = 0
        self.last_prediction_time = 0
        
    def warmup(self, num_frames=8):
        """Warm up the model with dummy frames for faster initial detection"""
        if self.model is None:
            return
        dummy_frame = np.zeros((224, 224, 3), dtype=np.uint8)
        for _ in range(num_frames):
            self.detect_violence_in_frame(dummy_frame)
        print(f"🔥 Model warmed up with {num_frames} frames")

    def get_status(self):
        """Get current detector status"""
        return {
            'model_loaded': self.model is not None,
            'device': str(self.device),
            'buffer_frames': len(self.frame_buffer),
            'required_frames': self.seq_len,
            'last_prediction': self.last_prediction_time,
            'current_confidence': self.current_violence_confidence,
            'violence_active': self.violence_detected
        }


class CNN_LSTM(nn.Module):
    """
    CNN-LSTM Model Architecture for Violence Detection
    Same architecture used in training script
    """
    def __init__(self):
        super().__init__()
        self.cnn = models.resnet50(weights='DEFAULT')
        self.cnn.fc = nn.Identity() 
        
        # Freeze CNN weights for inference
        for param in self.cnn.parameters():
            param.requires_grad = False

        self.lstm = nn.LSTM(input_size=2048, hidden_size=256, num_layers=2, 
                            batch_first=True, dropout=0.4)
        
        self.classifier = nn.Sequential(
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(128, 2)
        )

    def forward(self, x):
        B, T, C, H, W = x.size()
        x = x.view(B*T, C, H, W)
        
        features = self.cnn(x)
        features = features.view(B, T, -1)
        lstm_out, _ = self.lstm(features)
        
        out = self.classifier(lstm_out[:, -1, :])
        return out


# Test function
def test_violence_detector():
    """Test the violence detector with sample data"""
    print("\n" + "="*60)
    print("🥊 TESTING VIOLENCE DETECTOR")
    print("="*60)
    
    # Initialize detector
    detector = ViolenceDetector()
    
    # Create dummy frame
    dummy_frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    
    # Test detection
    print("Testing with dummy frame...")
    result = detector.detect_violence_in_frame(dummy_frame)
    
    print(f"Model loaded: {detector.model is not None}")
    print(f"Detection result: {result}")
    
    # Test status
    status = detector.get_status()
    print(f"Status: {status}")


if __name__ == "__main__":
    test_violence_detector()
