import os
import asyncio
import uuid
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from openai import OpenAI
import google.generativeai as genai

app = FastAPI(title="Bridge-AI Cloud Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# تأكد من وضع مفاتيحك هنا أو استخدام ملف .env
OPENAI_API_KEY = "sk-proj-..." 
GEMINI_API_KEY = "AIzaSyC..."

oa_client = OpenAI(api_key=OPENAI_API_KEY)
genai.configure(api_key=GEMINI_API_KEY)
# تم التعديل لإصدار مستقر
gemini_model = genai.GenerativeModel('gemini-2.5-flash')

@app.get("/")
async def health_check():
    return {"status": "online", "mode": "Full Cloud", "project": "Bridge-AI"}

@app.post("/process-audio")
async def process_data(
    file: Optional[UploadFile] = File(None), 
    text: Optional[str] = Form(None),
    language: str = Form("ar")
):
    temp_path = None
    try:
        input_text = ""

        # أ- معالجة الصوت (Whisper)
        if file:
            temp_path = f"temp_{uuid.uuid4().hex}_{file.filename}"
            content = await file.read()
            with open(temp_path, "wb") as f:
                f.write(content)
            
            # استخدام to_thread لمنع تجميد السيرفر
            def transcribe():
                with open(temp_path, "rb") as audio_file:
                    return oa_client.audio.transcriptions.create(
                        model="whisper-1", 
                        file=audio_file,
                        language=language
                    )
            
            transcript = await asyncio.to_thread(transcribe)
            input_text = transcript.text
        
        elif text:
            input_text = text
        else:
            raise HTTPException(status_code=400, detail="No input provided")

        # ب- معالجة النص (Gemini)
        prompt = (f"Convert the following text into sign language gloss (keywords for animation). "
                  f"Provide only the gloss keywords: \n\n{input_text}")
        
        # تشغيل Gemini في thread منفصل
        response = await asyncio.to_thread(gemini_model.generate_content, prompt)
        ai_result = response.text.strip()

        return {
            "status": "success",
            "original_text": input_text,
            "sign_language_gloss": ai_result,
            "video_url": "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4" 
        }

    except Exception as e:
        print(f"Cloud Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        # ضمان حذف الملف المؤقت حتى لو حدث خطأ
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)