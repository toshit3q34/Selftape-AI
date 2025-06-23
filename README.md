sceneapp is the flutter front-end for all platforms. To run do :
1. cd sceneapp/
2. flutter pub get
3. flutter run -d <device_id> OR flutter run [ Use flutter devices for list of devices ]
4. For hot reload do r, for reset do R

Install dependencies in backend :
1. cd backend/
2. python -m venv venv
3. source venv/bin/activate      # macOS/Linux
   venv\Scripts\activate         # Windows
4. pip install -r requirements.txt

backend is in FastAPI. To run do :
1. cd backend/
2. source venv/bin/activate
3. uvicorn main:app --reload --host 0.0.0.0 --port 8000 [ Runs backend at http://127.0.0.1:8000 ]

Order should be :
1. Install dependencies for backend
2. Start the backend on one terminal
3. Then start the frontend on another terminal
