import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, Subset
from torchvision import transforms, models
import cv2
import numpy as np
import os
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.model_selection import KFold
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, confusion_matrix
from tqdm import tqdm

# =============================
# 1. DATASET CLASS (Updated for Robustness)
# =============================
class VideoDataset(Dataset):
    def __init__(self, root_dir, seq_len=16, transform=None):
        self.samples = []
        self.seq_len = seq_len
        self.transform = transform

        # Ensure directory exists
        if not os.path.exists(root_dir):
            print(f"CRITICAL ERROR: Path {root_dir} does not exist!")
            return

        # RWF-2000 usually has 'train' and 'val'
        for split in ['train', 'val']:
            split_path = os.path.join(root_dir, split)
            if not os.path.exists(split_path): 
                continue

            # Check for class folders (Mapping Fight=1, NonFight=0)
            class_map = {'NonFight': 0, 'Fight': 1}
            for class_name, label in class_map.items():
                class_path = os.path.join(split_path, class_name)
                
                if not os.path.exists(class_path):
                    # Try lowercase if title case fails
                    class_path = os.path.join(split_path, class_name.lower())
                
                if os.path.exists(class_path):
                    videos = [v for v in os.listdir(class_path) if v.endswith(('.mp4', '.avi'))]
                    for video in videos:
                        self.samples.append((os.path.join(class_path, video), label))

    def __len__(self): 
        return len(self.samples)

    def __getitem__(self, idx):
        video_path, label = self.samples[idx]
        cap = cv2.VideoCapture(video_path)
        frames = []
        
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames <= 0: # Handle corrupted video files
            return torch.zeros((self.seq_len, 3, 224, 224)), torch.tensor(label)

        # Uniformly pick frame indices
        indices = np.linspace(0, total_frames - 1, self.seq_len, dtype=int)
        
        for i in range(total_frames):
            ret, frame = cap.read()
            if not ret: break
            if i in indices:
                frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                if self.transform:
                    frame = self.transform(frame)
                frames.append(frame)
            if len(frames) == self.seq_len: break
        cap.release()
        
        # Padding
        while len(frames) < self.seq_len:
            frames.append(torch.zeros((3, 224, 224)) if not frames else frames[-1])
            
        return torch.stack(frames), torch.tensor(label)

# =============================
# 2. MODEL ARCHITECTURE
# =============================
class CNN_LSTM(nn.Module):
    def __init__(self):
        super().__init__()
        self.cnn = models.resnet50(weights='DEFAULT')
        self.cnn.fc = nn.Identity() 
        
        # Freezing CNN weights to save VRAM and prevent overfitting during early phase
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

# =============================
# 3. MAIN SCRIPT
# =============================
def main():
    DATA_PATH = r"D:\Dataset\RWF-2000" 
    RESULTS_DIR = r"D:\Dataset\output"
    EXCEL_PATH = os.path.join(RESULTS_DIR, "Metrics_Progress.xlsx")
    os.makedirs(RESULTS_DIR, exist_ok=True)

    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    SEQ_LEN = 16
    BATCH_SIZE = 8
    K_FOLDS = 10
    EPOCHS = 15

    # Resume Logic: Load existing progress
    all_metrics_log = []
    start_fold = 0
    start_epoch = 1

    if os.path.exists(EXCEL_PATH):
        try:
            existing_df = pd.read_excel(EXCEL_PATH)
            all_metrics_log = existing_df.to_dict('records')
            if len(all_metrics_log) > 0:
                last_entry = all_metrics_log[-1]
                last_fold = last_entry['Fold']
                last_epoch = last_entry['Epoch']
                
                if last_epoch >= EPOCHS:
                    start_fold = last_fold # Move to next fold
                    start_epoch = 1
                else:
                    start_fold = last_fold - 1 # Stay on current fold
                    start_epoch = last_epoch + 1
                print(f"📊 Resuming from Fold {start_fold + 1}, Epoch {start_epoch}")
        except Exception as e:
            print(f"⚠️ Could not read Excel for resume, starting fresh. Error: {e}")

    train_trans = transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])

    full_dataset = VideoDataset(root_dir=DATA_PATH, seq_len=SEQ_LEN, transform=train_trans)
    num_samples = len(full_dataset)
    if num_samples == 0: return

    kf = KFold(n_splits=K_FOLDS, shuffle=True, random_state=42)
    
    # We convert kf.split to a list so we can jump to the correct fold index
    folds = list(kf.split(full_dataset))

    for fold_idx in range(start_fold, K_FOLDS):
        train_idx, val_idx = folds[fold_idx]
        fold_num = fold_idx + 1
        print(f"\n--- Fold {fold_num} ---")
        
        train_loader = DataLoader(Subset(full_dataset, train_idx), batch_size=BATCH_SIZE, 
                                  shuffle=True, num_workers=2, pin_memory=True)
        val_loader = DataLoader(Subset(full_dataset, val_idx), batch_size=BATCH_SIZE, 
                                num_workers=2, pin_memory=True)

        model = CNN_LSTM().to(DEVICE)
        
        # RESUME WEIGHTS: If resuming mid-fold, load the best model so far for that fold
        model_path = f"{RESULTS_DIR}/best_model_fold_{fold_num}.pth"
        if os.path.exists(model_path) and fold_idx == start_fold:
            model.load_state_dict(torch.load(model_path))
            print(f"✅ Loaded existing weights for Fold {fold_num}")

        optimizer = optim.AdamW(model.parameters(), lr=1e-4)
        criterion = nn.CrossEntropyLoss()
        scaler = torch.amp.GradScaler('cuda')

        # Determine best_acc for current fold session
        best_acc = 0
        if fold_idx == start_fold and len(all_metrics_log) > 0:
            fold_metrics = [m['Accuracy'] for m in all_metrics_log if m['Fold'] == fold_num]
            if fold_metrics: best_acc = max(fold_metrics)

        # Loop through epochs, starting from start_epoch ONLY for the first resumed fold
        current_start_epoch = start_epoch if fold_idx == start_fold else 1
        
        for epoch in range(current_start_epoch, EPOCHS + 1):
            model.train()
            train_loss = 0
            pbar = tqdm(train_loader, desc=f"Fold {fold_num} Ep {epoch}")
            
            for videos, labels in pbar:
                videos, labels = videos.to(DEVICE), labels.to(DEVICE)
                optimizer.zero_grad()
                with torch.amp.autocast('cuda'):
                    outputs = model(videos)
                    loss = criterion(outputs, labels)
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
                train_loss += loss.item()

            # Validation
            model.eval()
            v_preds, v_targets = [], []
            with torch.no_grad():
                for videos, labels in val_loader:
                    videos = videos.to(DEVICE)
                    outputs = model(videos)
                    _, pred = torch.max(outputs, 1)
                    v_preds.extend(pred.cpu().numpy())
                    v_targets.extend(labels.numpy())

            acc = accuracy_score(v_targets, v_preds)
            f1 = f1_score(v_targets, v_preds, zero_division=0)
            
            # Update Log and Save
            epoch_log = {'Fold': fold_num, 'Epoch': epoch, 'Loss': train_loss/len(train_loader), 'Accuracy': acc, 'F1': f1}
            all_metrics_log.append(epoch_log)
            
            # Save Excel immediately after every epoch
            pd.DataFrame(all_metrics_log).to_excel(EXCEL_PATH, index=False)

            if acc > best_acc:
                best_acc = acc
                torch.save(model.state_dict(), model_path)
                plt.figure(figsize=(5,4))
                sns.heatmap(confusion_matrix(v_targets, v_preds), annot=True, fmt='d', cmap='Blues')
                plt.savefig(f"{RESULTS_DIR}/fold_{fold_num}_cm.png")
                plt.close()
            
            print(f"Fold {fold_num} Ep {epoch} - Acc: {acc:.4f}")

if __name__ == '__main__':
    main()