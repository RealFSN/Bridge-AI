import os
import whisper
import torch
import asyncio
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import google.generativeai as genai
import edge_tts
import Bridge_sADIQ as sadiq
# 1. إنشاء تطبيق FastAPI
app = FastAPI(title="Bridge-AI Backend")

# 2. إعدادات الـ CORS (ضرورية جداً لربط تطبيق فلاتر مستقبلاً)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # يسمح بالاتصال من أي جهاز أو تطبيق
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 3. تحميل الموديلات مرة واحدة عند تشغيل السيرفر (لضمان السرعة والاستقرار)
print("--- جاري تحميل موديل Whisper ---")
device = "cuda" if torch.cuda.is_available() else "cpu"
whisper_model = whisper.load_model("base", device=device)
print(f"--- تم التحميل على: {device} ---")

# 4. إعداد Gemini (تأكد من وضع مفتاحك هنا)
GEMINI_API_KEY = "AIzaSyCEha0n0YrS-1nFwOLRptOqW0_ixBkRJqw"
genai.configure(api_key=GEMINI_API_KEY)
gemini_model = genai.GenerativeModel('gemini-pro')

@app.get("/")
async def health_check():
    return {"status": "online", "project": "Bridge-AI"}

@app.post("/process-bridge")
async def process_audio(audio_file: UploadFile = File(...)):
    """
    هذه الدالة تستقبل ملف صوتي، تحوله لنص، تترجمه بـ Gemini، ثم تصنع منه صوت مترجم.
    """
    input_path = f"temp_in_{audio_file.filename}"
    output_audio_path = "output_translated.mp3"

    try:
        # أ- حفظ الملف الصوتي المرفوع من المستخدم
        with open(input_path, "wb") as f:
            f.write(await audio_file.read())

        # ب- تحويل الصوت لنص (Speech-to-Text)
        print("جاري تحويل الصوت لنص...")
        result = whisper_model.transcribe(input_path)
        original_text = result['text']

        # ج- المعالجة والترجمة عبر Gemini (نفس منطق مشروعك)
        print("جاري الترجمة عبر Gemini...")
        prompt = f"Translate the following text to Arabic (or English if it's already Arabic): {original_text}"
        response = gemini_model.generate_content(prompt)
        translated_text = response.text

        # د- تحويل النص المترجم لصوت (Text-to-Speech)
        print("جاري توليد الصوت المترجم...")
        # ملاحظة: ar-SA-ZariyahNeural هو صوت أنثوي سعودي، يمكنك تغييره
        communicate = edge_tts.Communicate(translated_text, "ar-SA-ZariyahNeural")
        await communicate.save(output_audio_path)

        # هـ- إرسال النتائج النهائية
        return {
            "status": "success",
            "original_text": original_text,
            "translated_text": translated_text,
            "audio_download_url": "/download-result"
        }

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        # تنظيف الملفات المؤقتة المدخلة فقط
        if os.path.exists(input_path):
            os.remove(input_path)

@app.get("/download-result")
async def download_result():
    """دالة للسماح للتطبيق بتحميل ملف الصوت الناتج"""
    if os.path.exists("output_translated.mp3"):
        return FileResponse("output_translated.mp3", media_type="audio/mpeg")
    return {"error": "File not found"}

if __name__ == "__main__":
    import uvicorn
    # تشغيل السيرفر محلياً على بورت 8000
    uvicorn.run(app, host="0.0.0.0", port=8000)