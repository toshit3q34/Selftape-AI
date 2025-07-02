# generate_wav.py
import wave
import numpy as np

rate = 16000  # 16kHz
duration = 1  # 1 second
freq = 440.0  # A4

t = np.linspace(0, duration, int(rate * duration), False)
data = (np.sin(2 * np.pi * freq * t) * 32767).astype(np.int16)

with wave.open("sample.wav", "w") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(rate)
    f.writeframes(data.tobytes())
