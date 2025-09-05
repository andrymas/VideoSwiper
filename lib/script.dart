  final pythonScript = '''
import os
import cv2
from PIL import Image
import math
import sys

sys.stdout.reconfigure(encoding='utf-8')

# Retrieve arguments:
# sys.argv[1] is video_path
# sys.argv[2] is framesNumber
# sys.argv[3] is quality_setting (new)
video_path = sys.argv[1]
framesNumber = int(sys.argv[2]) if len(sys.argv) > 2 else 40
quality_setting = int(sys.argv[3]) if len(sys.argv) > 3 else 2 # Default to 'Medium' (index 2)


def estrai_frame_temporizzati(video_path, num_frame):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Errore nell'apertura del video: {video_path}")
        return []

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    duration_seconds = total_frames / fps if fps > 0 else 0

    if duration_seconds == 0:
        print(f"Durata video non valida: {video_path}")
        return []

    step_seconds = duration_seconds / num_frame
    frames = []

    for i in range(num_frame):
        timestamp = i * step_seconds
        cap.set(cv2.CAP_PROP_POS_MSEC, timestamp * 1000)
        ret, frame = cap.read()
        if not ret:
            continue
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(frame_rgb)
        frames.append(img)

    cap.release()
    return frames

# --- Calculate thumbnail size based on quality ---
def calculate_thumbnail_size(quality_level, original_width, original_height):
    """
    Calculates thumbnail dimensions based on quality level and
    original frame size to maintain aspect ratio.

    Args:
        quality_level (int): Quality level (0=Lowest, 4=Ultra).
        original_width (int): Original frame width.
        original_height (int): Original frame height.

    Returns:
        tuple: (thumb_width, thumb_height) calculated dimensions for the thumbnail.
    """
    is_portrait = original_height > original_width
    
    # Define target sizes for the longer side at different quality levels
    # These values should match your Flutter-side calculations
    target_sizes = {
        0: 320,  # Lowest: Longer side target e.g., 180x320 or 320x180
        1: 480,  # Low: Longer side target e.g., 270x480 or 480x270
        2: 640,  # Medium: Longer side target e.g., 360x640 or 640x360
        3: 960,  # High: Longer side target e.g., 540x960 or 960x540
        4: 1280, # Ultra: Longer side target e.g., 720x1280 or 1280x720
    }

    # Get the target size for the longer side based on the quality level
    # Default to Medium (640) if the level is not valid
    target_long_side = target_sizes.get(quality_level, 640) 

    # Calculate the scale factor
    if is_portrait:
        scale_factor = target_long_side / original_height
    else:
        scale_factor = target_long_side / original_width
    
    # Apply the scale factor to get new dimensions while maintaining aspect ratio
    thumb_width = int(original_width * scale_factor)
    thumb_height = int(original_height * scale_factor)
    
    return (thumb_width, thumb_height)


def crea_collage(frames, output_path, cols=8, quality_setting=2):
    if not frames:
        print(f"Nessun frame disponibile per creare il collage: {output_path}")
        return

    # Get original dimensions from the first frame
    original_frame_width = frames[0].width
    original_frame_height = frames[0].height

    # --- Calculate thumb_size based on quality_setting ---
    thumb_size = calculate_thumbnail_size(
        quality_setting,
        original_frame_width,
        original_frame_height
    )

    rows = math.ceil(len(frames) / cols)
    collage_width = cols * thumb_size[0]
    collage_height = rows * thumb_size[1]

    collage = Image.new('RGB', (collage_width, collage_height), color=(0, 0, 0))

    for index, frame in enumerate(frames):
        # Ensure frame is in RGB before resizing
        if frame.mode != 'RGB':
            frame = frame.convert('RGB')
        frame = frame.resize(thumb_size, Image.Resampling.LANCZOS) # Use LANCZOS for better quality resizing
        x = (index % cols) * thumb_size[0]
        y = (index // cols) * thumb_size[1]
        collage.paste(frame, (x, y))

    collage.save(output_path)
    print("Collage salvato:", output_path.encode('utf-8', errors='ignore').decode())

if __name__ == "__main__":
    # Ensure all required arguments are present
    if len(sys.argv) < 2:
        print("Usage: python script.py <video_path> [frames_number] [quality_setting]")
        sys.exit(1)

    # Arguments are already retrieved at the top level
    # video_path = sys.argv[1] # Already assigned
    # framesNumber = int(sys.argv[2]) if len(sys.argv) > 2 else 40 # Already assigned
    # quality_setting = int(sys.argv[3]) if len(sys.argv) > 3 else 2 # Already assigned

    nome_base = os.path.splitext(os.path.basename(video_path))[0]
    cartella = os.path.dirname(video_path)
    output_collage = os.path.join(cartella, f"{nome_base}_collage.png")

    # Pass framesNumber directly
    frames = estrai_frame_temporizzati(video_path, num_frame=framesNumber)
    
    # Pass quality_setting to crea_collage
    crea_collage(frames, output_collage, quality_setting=quality_setting)
''';
