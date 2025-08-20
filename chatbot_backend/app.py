# This file is required by HuggingFace Spaces but our main app is in main.py
# Import and run the FastAPI app from main.py

from main import app

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)