import asyncio
import json
import threading
import time

from fastapi import WebSocket
from rapidfuzz import fuzz
import queue
from cartesia import Cartesia

# === CONFIG ===
CARTESIA_API_KEY = 'sk_car_3vt7G9MRLjkkwa1dE1ZaUi'
THRESHOLD = 65
SILENCE_TIMEOUT = 1.5
SAMPLE_RATE = 16000

# === Globals ===
tts_queue = queue.Queue()
is_speaking = False
speak_lock = threading.Lock()
cartesia = Cartesia(api_key=CARTESIA_API_KEY)

# Gender voice map (placeholder)
GENDER_VOICE_MAP = {
    "MALE": "c99d36f3-5ffd-4253-803a-535c1bc9c306",
    "FEMALE": "bc46586b-b463-4367-a96e-44127177a521",
    "NEUTRAL": "c99d36f3-5ffd-4253-803a-535c1bc9c306",
}

def parse_script_from_string(script_text):
    parsed = []
    for line in script_text.splitlines():
        line = line.strip()
        if not line:
            continue
        if ':' in line:
            parts = line.split(':', 1)
            speaker = parts[0].strip().upper()
            dialogue = parts[1].strip()
            parsed.append({"speaker": speaker, "line": dialogue})
    return parsed

def speak(text, voice_id):
    tts_queue.put((text, voice_id))

def tts_worker(ws:WebSocket, loop):
    while True:
        text, voice_id = tts_queue.get()
        try:
            print(f"[TTS] Speaking ({voice_id}): {text}")
            output = cartesia.tts.bytes(
                model_id="sonic-2",
                transcript=text,
                voice={"mode": "id", "id": voice_id},
                language="en",
                output_format={
                    "container": "raw",
                    "encoding": "pcm_s16le",
                    "sample_rate": SAMPLE_RATE
                }
            )
            raw_bytes = b"".join(output)

            # CORRECT way to send via WebSocket from thread
            asyncio.run_coroutine_threadsafe(
                ws.send_text(json.dumps({"tts_text": text})),
                loop
            ).result()
            time.sleep(0.1)
            print(f"[Sending Binary] len={len(raw_bytes)}, type={type(raw_bytes)}")
            asyncio.run_coroutine_threadsafe(
                ws.send_bytes(raw_bytes),
                loop
            ).result()

        except Exception as e:
            print("[TTS Error]", e)
        finally:
            tts_queue.task_done()

def start_tts_thread(ws, loop):
    threading.Thread(target=tts_worker, args=(ws,loop), daemon=True).start()

async def start_stt_ws(expected_line, ws):
    print("[STT] Waiting for user's line...")
    full_transcript = ""
    last_received = time.time()

    while True:
        try:
            recv = await ws.receive()
            if isinstance(recv, bytes):
                continue  # ignore raw audio in backend side
            result = json.loads(recv)
            transcript = result.get("transcript", "")
            if transcript.strip():
                print(f"[STT] Heard: {transcript}")
                full_transcript += " " + transcript.strip()
                full_transcript = full_transcript.strip()
                last_received = time.time()

            if time.time() - last_received > SILENCE_TIMEOUT and full_transcript:
                similarity = fuzz.ratio(full_transcript.lower(), expected_line.lower())
                print(f"[Match] {similarity}%\n[Expected]: {expected_line}\n[Heard]: {full_transcript}")
                if similarity >= THRESHOLD:
                    return True
                else:
                    speak("Please try again.", voice_id=GENDER_VOICE_MAP["NEUTRAL"])
                    return False
        except Exception as e:
            print("[WebSocket STT Error]", e)
            return False

async def wait_until_tts_done():
    while not tts_queue.empty():
        await asyncio.sleep(0.1)

async def _run_session(script_text, user_roles, ai_character_genders, websocket):
    script = parse_script_from_string(script_text)
    print(f"[Session] Roles: {user_roles}")

    tts_thread = threading.Thread(target=tts_worker, args=(websocket, asyncio.get_running_loop()), daemon=True)
    tts_thread.start()

    for entry in script:
        speaker = entry['speaker'].strip().upper()
        line = entry['line']

        if speaker in user_roles:
            await wait_until_tts_done()
            success = await start_stt_ws(line, websocket)
            while not success:
                await wait_until_tts_done()
                success = await start_stt_ws(line, websocket)
        elif speaker in ai_character_genders:
            gender = ai_character_genders[speaker].upper()
            voice_id = GENDER_VOICE_MAP.get(gender, GENDER_VOICE_MAP["NEUTRAL"])
            # print(line)
            speak(line, voice_id)

    await wait_until_tts_done()
    tts_queue.join()
    print("[Session] Complete.")

