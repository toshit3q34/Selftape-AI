import asyncio
import websockets
import json
import sounddevice as sd
import queue
import time
from rapidfuzz import fuzz
import pyttsx3
import threading
import re

DEEPGRAM_API_KEY = 'dg.48a1be6a18bf4495f6960cc86812f1a40d8af598'
SCRIPT_FILE = "formatted_script (2).txt"
THRESHOLD = 65
SILENCE_TIMEOUT = 1.85
SAMPLE_RATE = 16000
BLOCK_SIZE = 1024
CHANNELS = 1

audio_q = queue.Queue()
is_speaking = False
speak_lock = threading.Lock()
engine = pyttsx3.init()

# === SETUP VOICES (Zira & David) ===
voices = engine.getProperty('voices')
voice_ids = {
    "MALE": None,
    "FEMALE": None
}
for v in voices:
    if "zira" in v.name.lower():
        voice_ids["FEMALE"] = v.id
    elif "david" in v.name.lower():
        voice_ids["MALE"] = v.id

# === Character to voice mapping ===
voice_map = {
    "PAMELA": "FEMALE",
    "JACK": "MALE",
    "NARRATOR": "MALE"
} #manually karna padega probably

def speak(text, voice_id=None):
    global is_speaking
    with speak_lock:
        is_speaking = True
        if voice_id:
            engine.setProperty('voice', voice_id)
        print(f"[TTS] Speaking: {text}")
        engine.say(text)
        engine.runAndWait()
        is_speaking = False

def audio_callback(indata, frames, time_info, status):
    # if status:
    #     print(f"[Audio Callback] Status: {status}")
    with speak_lock:
        if not is_speaking:
            audio_q.put(bytes(indata))
            # print(f"[Audio callback] Received audio chunk size: {len(indata)}")

# def parse_script(filename):
#     with open(filename, 'r', encoding='utf-8') as f:
#         lines = f.readlines()

#     parsed = []
#     current_speaker = None
#     buffer = []

#     def flush():
#         if current_speaker and buffer:
#             line = ' '.join(l.strip() for l in buffer if l.strip())
#             parsed.append({'speaker': current_speaker, 'line': line})

#     for line in lines:
#         line = line.rstrip()
#         if not line.strip():
#             continue

#         if re.match(r'^[A-Z][A-Z0-9\s\'().-]*$', line):
#             flush()
#             current_speaker = line.strip()
#             buffer = []
#         elif line.startswith("    ") or current_speaker == "NARRATOR":
#             buffer.append(line)
#         else:
#             flush()
#             current_speaker = None
#             buffer = []

#     flush()
#     return parsed

def parse_script(filename):
    parsed = []
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue  # skip empty lines

            if ':' in line:
                parts = line.split(':', 1)
                speaker = parts[0].strip().upper()
                dialogue = parts[1].strip()
                parsed.append({"speaker": speaker, "line": dialogue})

    return parsed


async def send_audio(ws):
    print("[send_audio] Waiting to let Deepgram initialize...")
    await asyncio.sleep(0)
    while True:
        try:
            data = await asyncio.get_event_loop().run_in_executor(None, audio_q.get)
            await ws.send(data)
            # print(f"[send_audio] Sent audio chunk of size {len(data)}")
        except Exception as e:
            print(f"[send_audio error]: {e}")
            break

async def start_stt(expected_line):
    uri = (
        "wss://api.deepgram.com/v1/listen"
        "?interim_results=true&encoding=linear16&sample_rate=16000&channels=1"
    )
    headers = {'Authorization': f'Token 48a1be6a18bf4495f6960cc86812f1a40d8af598'}

    async with websockets.connect(uri, extra_headers=headers) as ws:
        print("[STT] WebSocket connected")
        send_task = asyncio.create_task(send_audio(ws))
        full_transcript = ""
        last_final_time = None

        try:
            async for message in ws:
                result = json.loads(message)
                transcript = result.get("channel", {}).get("alternatives", [{}])[0].get("transcript", "")
                is_final = result.get("is_final", False)

                if transcript.strip():
                    print(f"[Transcript] '{transcript}' | Final: {is_final}")

                if is_final and transcript.strip():
                    full_transcript += " " + transcript
                    full_transcript = full_transcript.strip()
                    last_final_time = time.time()

                if last_final_time is not None:
                    if time.time() - last_final_time > SILENCE_TIMEOUT and full_transcript:
                        similarity = fuzz.ratio(full_transcript.lower(), expected_line.lower())
                        print(f"\nMatch %: {similarity}\nExpected: {expected_line}\nHeard: {full_transcript}")

                        if similarity >= THRESHOLD:
                            print("Matched.")
                            return True
                        else:
                            print("Not matched. Asking to repeat.")
                            speak("Please try again", voice_id=voice_ids["MALE"])
                            return False
        finally:
            send_task.cancel()
            try:
                await send_task
            except asyncio.CancelledError:
                pass
            print("[STT] STT stopped.")

async def main():
    print("Choose your character:")
    user_role = "JACK".strip().upper()
    script = parse_script(SCRIPT_FILE)

    with sd.InputStream(samplerate=SAMPLE_RATE, blocksize=BLOCK_SIZE, channels=CHANNELS, dtype='int16', callback=audio_callback):
        for entry in script:
            speaker = entry['speaker']
            line = entry['line']
            print(f"\n[{speaker}] {line}")

            if speaker == user_role:
                success = await start_stt(line)
                while not success:
                    success = await start_stt(line)
            else:
                gender = voice_map.get(speaker.split()[0], "MALE")
                voice_id = voice_ids.get(gender)
                speak(line, voice_id=voice_id)

    print("[Main] All lines complete.")

if __name__ == '__main__':
    asyncio.run(main())