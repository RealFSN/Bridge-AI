import os
import whisper
import torch
import asyncio
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import google.generativeai as genai
import edge_tts
from typing import Optional

# 1. إنشاء تطبيق FastAPI
app = FastAPI(title="Bridge-AI Backend")

# 2. إعدادات الـ CORS لضمان اتصال فلاتر بدون مشاكل
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 3. تحميل موديل Whisper (مرة واحدة عند التشغيل)
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"--- Loading Whisper model on: {device} ---")
whisper_model = whisper.load_model("base", device=device)

# 4. إعداد Gemini
GEMINI_API_KEY = "AIzaSyCEha0n0YrS-1nFwOLRptOqW0_ixBkRJqw"
genai.configure(api_key=GEMINI_API_KEY)
gemini_model = genai.GenerativeModel('gemini-2.5-flash')

@app.get("/")
async def health_check():
    return {"status": "online", "message": "Backend is running"}

# 5. الدالة الأساسية (تم تعديلها لتستقبل نص أو ملف)
@app.post("/process-audio")
async def process_data(
    file: Optional[UploadFile] = File(None), 
    text: Optional[str] = Form(None),
    language: str = Form("en")
):
    """
    تستقبل هذه الدالة:
    - ملف صوتي (من التسجيل أو الرفع)
    - أو نص مباشر (من حقل الكتابة في فلاتر)
    """
    try:
        input_text = ""

        # الحالة الأولى: إذا أرسل المستخدم ملف صوتي
        if file:
            temp_path = f"temp_{file.filename}"
            with open(temp_path, "wb") as f:
                f.write(await file.read())
            
            print(f"Processing audio file: {temp_path}")
            result = whisper_model.transcribe(temp_path)
            input_text = result['text']
            os.remove(temp_path) # حذف الملف المؤقت فوراً
        
        # الحالة الثانية: إذا أرسل المستخدم نصاً
        elif text:
            print(f"Processing text input: {text}")
            input_text = text
        
        else:
            raise HTTPException(status_code=400, detail="No input provided")

        # معالجة النص عبر Gemini (تحويل النص لوصف لغة إشارة)
        # يمكنك تعديل الـ Prompt هنا ليناسب مخرجاتك
        prompt = f"Convert the following sentence into sign language gloss or keywords for animation: {input_text}"
        response = gemini_model.generate_content(prompt)
        ai_result = response.text

        # إرسال الرد لفلاتر (حالياً رابط فيديو ثابت كما في طلبك)
        return {
            "status": "success",
            "original_text": input_text,
            "ai_description": ai_result,
            "video_url": "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4" 
        }

    except Exception as e:
        print(f"Error occurred: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    # تشغيل السيرفر على 0.0.0.0 ليتمكن الجوال من الوصول إليه عبر الشبكة
    uvicorn.run(app, host="0.0.0.0", port=8000)