  final pythonScript = '''
import os
import cv2
from PIL import Image
import math
import sys

sys.stdout.reconfigure(encoding='utf-8')
framesNumber = int(sys.argv[2]) if len(sys.argv) > 2 else 40


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

def crea_collage(frames, output_path, cols=8):
    if not frames:
        print(f"Nessun frame disponibile per creare il collage: {output_path}")
        return

    rows = math.ceil(len(frames) / cols)
    thumb_size = (180, 320) if frames[0].height > frames[0].width else (320, 180)
    collage_width = cols * thumb_size[0]
    collage_height = rows * thumb_size[1]

    collage = Image.new('RGB', (collage_width, collage_height), color=(0, 0, 0))

    for index, frame in enumerate(frames):
        frame = frame.resize(thumb_size)
        x = (index % cols) * thumb_size[0]
        y = (index // cols) * thumb_size[1]
        collage.paste(frame, (x, y))

    collage.save(output_path)
    print("Collage salvato:", output_path.encode('utf-8', errors='ignore').decode())

if __name__ == "__main__":
    video_path = sys.argv[1]
    nome_base = os.path.splitext(os.path.basename(video_path))[0]
    cartella = os.path.dirname(video_path)
    output_collage = os.path.join(cartella, f"{nome_base}_collage.png")
    frames = estrai_frame_temporizzati(video_path, num_frame=framesNumber)
    crea_collage(frames, output_collage)
''';
