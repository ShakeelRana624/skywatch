"""
Violence Detection Module - CNN-LSTM Model
Uses best_model_fold_3.pth for real-time violence detection
"""

import cv2
import numpy as np
import torch
import torch.nn as nn
from torchvision import transforms, models
from collections import deque
from typing import Dict, List, Any, Optional
import time
import os

class ViolenceDetector:
    """Violence detection using CNN-LSTM model"""
    
    def __init__(self, model_path: str = "../models/best_model_fold_3.pth", device=None):
        """
        Initialize violence detector
        
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
        self.prediction_interval = 0.1  # 10 FPS predictions - balanced speed/accuracy
        self.current_violence_confidence = 0.0
        self.violence_detected = False
        self.detection_threshold = 0.2  # Lowered for more sensitive detection
        
        # Improved smoothing - weighted recent frames more
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
        """Initialize CNN-LSTM model"""
        try:
            # Define CNN-LSTM architecture
            self.model = CNN_LSTM()
            
            # Load model weights
            model_full_path = os.path.join(os.path.dirname(__file__), "..", "models", "best_model_fold_3.pth")
            if os.path.exists(model_full_path):
                checkpoint = torch.load(model_full_path, map_location=self.device)
                self.model.load_state_dict(checkpoint)
                self.model.to(self.device)
                self.model.eval()
                print(f"✅ Model weights loaded from {model_full_path}")
            else:
                print(f"❌ Model file not found: {model_full_path}")
                self.model = None
                
        except Exception as e:
            print(f"❌ Error loading model: {e}")
            self.model = None

    def _init_transforms(self):
        """Initialize image transformations"""
        self.transform = transforms.Compose([
            transforms.ToPILImage(),
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], 
                               std=[0.229, 0.224, 0.225])
        ])

    def detect_violence_in_frame(self, frame: np.ndarray) -> Dict[str, Any]:
        """
        Detect violence in a single frame using buffered sequence
        
        Args:
            frame: Input frame in BGR format
            
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
                # Preprocess sequence
                sequence = []
                for frame_img in self.frame_buffer:
                    if self.transform:
                        frame_tensor = self.transform(frame_img)
                        sequence.append(frame_tensor)
                
                if len(sequence) == self.seq_len:
                    sequence = torch.stack(sequence).unsqueeze(0).to(self.device)
                    
                    with torch.no_grad():
                        outputs = self.model(sequence)
                        probabilities = torch.softmax(outputs, dim=1)
                        
                        # Extract probabilities
                        non_fight_confidence = probabilities[0][0].item()
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
                        
                        # Update current state
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
                        'non_fight_confidence': non_fight_confidence,
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
                    'smoothed_confidence': 0.0,
                    'raw_confidence': 0.0,
                    'error': str(e)
                }
        
        # Return current state if no prediction made
        return {
            'violence_detected': self.violence_detected,
            'violence_confidence': self.current_violence_confidence,
            'fight_confidence': self.current_violence_confidence,
            'non_fight_confidence': 1.0 - self.current_violence_confidence,
            'smoothed_confidence': self.smoothed_confidence,
            'raw_confidence': self.current_violence_confidence,
            'error': None
        }

    def get_status(self) -> Dict[str, Any]:
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

    def reset_buffer(self):
        """Reset frame buffer"""
        self.frame_buffer.clear()
        self.confidence_history.clear()
        self.last_prediction_time = 0
        self.current_violence_confidence = 0.0
        self.smoothed_confidence = 0.0
        self.violence_detected = False
        self.violence_frame_count = 0
        print("🔄 Violence detector buffer reset")
        
    def warmup(self, num_frames=8):
        """Warm up the model with dummy frames for faster initial detection"""
        if self.model is None:
            return
        dummy_frame = np.zeros((224, 224, 3), dtype=np.uint8)
        for _ in range(num_frames):
            self.detect_violence_in_frame(dummy_frame)
        print(f"🔥 Model warmed up with {num_frames} frames")

    def set_threshold(self, threshold: float):
        """Set detection threshold"""
        if 0.0 <= threshold <= 1.0:
            self.detection_threshold = threshold
            print(f"🎯 Detection threshold set to {threshold}")

class CNN_LSTM(nn.Module):
    """CNN-LSTM model for violence detection"""
    
    def __init__(self, num_classes=2, hidden_size=256, num_layers=2, dropout=0.5):
        super(CNN_LSTM, self).__init__()
        
        # CNN Feature Extractor (ResNet50)
        self.cnn = models.resnet50(pretrained=False)
        self.cnn.fc = nn.Identity()  # Remove final classification layer
        
        # LSTM for temporal analysis
        self.lstm = nn.LSTM(
            input_size=2048,  # ResNet50 feature size
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout if num_layers > 1 else 0,
            bidirectional=False
        )
        
        # Classifier
        self.classifier = nn.Sequential(
            nn.Linear(hidden_size, 128),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(128, num_classes)
        )
    
    def forward(self, x):
        # x shape: (batch_size, seq_len, channels, height, width)
        batch_size, seq_len = x.shape[:2]
        
        # Reshape for CNN processing
        x = x.view(batch_size * seq_len, *x.shape[2:])
        
        # Extract CNN features
        features = self.cnn(x)  # (batch_size * seq_len, 2048)
        
        # Reshape for LSTM
        features = features.view(batch_size, seq_len, -1)
        
        # LSTM processing
        lstm_out, (hidden, cell) = self.lstm(features)
        
        # Use last LSTM output for classification
        last_output = lstm_out[:, -1, :]
        
        # Classification
        output = self.classifier(last_output)
        
        return output
