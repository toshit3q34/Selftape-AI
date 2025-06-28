import asyncio
import websockets
import json
import sounddevice as sd
import queue
import time
from rapidfuzz import fuzz
import threading
import simpleaudio as sa
from cartesia import Cartesia
import numpy as np

# === CONFIG ===
DEEPGRAM_API_KEY = 'dg.f6b66c53441b20de6204bd091ee2d5a498b0f823'
CARTESIA_API_KEY = 'sk_car_3vt7G9MRLjkkwa1dE1ZaUi'
SCRIPT_FILE = "The_Last_Train_Formatted.txt"
THRESHOLD = 65
SILENCE_TIMEOUT = 1.5
SAMPLE_RATE = 16000
BLOCK_SIZE = 512
CHANNELS = 1

# === Init ===
audio_q = queue.Queue()
tts_queue = queue.Queue()
is_speaking = False
speak_lock = threading.Lock()
cartesia = Cartesia(api_key=CARTESIA_API_KEY)

# === Character to voice mapping ===
voice_map = {
    "PAMELA": "bc46586b-b463-4367-a96e-44127177a521",
    "JACK": "c99d36f3-5ffd-4253-803a-535c1bc9c306",
    "NARRATOR": "c99d36f3-5ffd-4253-803a-535c1bc9c306",
    "MAYA": "bc46586b-b463-4367-a96e-44127177a521",
    "LUCAS": "c99d36f3-5ffd-4253-803a-535c1bc9c306"
}

# === TTS Worker Thread ===
def tts_worker():
    global is_speaking
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
            audio_np = np.frombuffer(raw_bytes, dtype=np.int16)
            amplified = np.clip(audio_np * 2.0, -32768, 32767).astype(np.int16)
            amplified_bytes = amplified.tobytes()

            with speak_lock:
                is_speaking = True
            sa.play_buffer(amplified_bytes, 1, 2, SAMPLE_RATE).wait_done()

        except Exception as e:
            print("[TTS Error]", e)
        finally:
            with speak_lock:
                is_speaking = False
            tts_queue.task_done()

# Start TTS thread
threading.Thread(target=tts_worker, daemon=True).start()

def speak(text, voice_id):
    tts_queue.put((text, voice_id))

def audio_callback(indata, frames, time_info, status):
    with speak_lock:
        if not is_speaking:
            audio_q.put(bytes(indata))

def parse_script(filename):
    parsed = []
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if ':' in line:
                parts = line.split(':', 1)
                speaker = parts[0].strip().upper()
                dialogue = parts[1].strip()
                parsed.append({"speaker": speaker, "line": dialogue})
    return parsed

async def send_audio(ws):
    while True:
        try:
            data = await asyncio.get_event_loop().run_in_executor(None, audio_q.get)
            await ws.send(data)
        except Exception as e:
            print(f"[send_audio error]: {e}")
            break

async def start_stt(expected_line):
    uri = (
        "wss://api.deepgram.com/v1/listen"
        "?interim_results=true&encoding=linear16&sample_rate=16000&channels=1"
    )
    headers = {'Authorization': f'Token f6b66c53441b20de6204bd091ee2d5a498b0f823'}

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
                            speak("Please try again", voice_id=voice_map["NARRATOR"])
                            return False
        finally:
            send_task.cancel()
            try:
                await send_task
            except asyncio.CancelledError:
                pass
            print("[STT] STT stopped.")

async def wait_until_tts_done():
    while True:
        with speak_lock:
            if not is_speaking:
                break
        await asyncio.sleep(0)

async def main():
    print("Choose your character:")
    user_role = "LUCAS".strip().upper()
    script = parse_script(SCRIPT_FILE)

    with sd.InputStream(samplerate=SAMPLE_RATE, blocksize=BLOCK_SIZE, channels=CHANNELS, dtype='int16', callback=audio_callback, latency='low'):
        for entry in script:
            speaker = entry['speaker']
            line = entry['line']
            print(f"\n[{speaker}] {line}") #remove this from app

            if speaker == user_role:
                await wait_until_tts_done()
                success = await start_stt(line)
                while not success:
                    await wait_until_tts_done()
                    success = await start_stt(line)
            else:
                voice_id = voice_map.get(speaker, voice_map["NARRATOR"])
                speak(line, voice_id=voice_id)

    print("[Main] All lines complete.")
    await wait_until_tts_done()
    tts_queue.join()


if __name__ == '__main__':
    asyncio.run(main())
