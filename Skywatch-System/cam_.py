import cv2

# Use your PUBLIC IP (from CanYouSeeMe.org)
# Ensure your verification code is exactly as printed on the sticker (All Caps)
public_ip = "39.52.148.17"
v_code = "KIKVFH" 

# Standard EZVIZ RTSP URL
rtsp_url = f"rtsp://admin:{v_code}@{public_ip}:554/h264_stream"

print(f"Connecting to: {rtsp_url}")
cap = cv2.VideoCapture(rtsp_url)

if not cap.isOpened():
    print("Could not connect. Check: 1. Port 554 status 2. Image Encryption is OFF.")
else:
    print("Remote Connection Successful! Press 'q' to close.")
    while True:
        ret, frame = cap.read()
        if not ret: break
        
        cv2.imshow("Remote Project Stream", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

cap.release()
cv2.destroyAllWindows()