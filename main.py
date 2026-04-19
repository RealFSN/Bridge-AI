import asyncio
import os
import uuid
import edge_tts
import google.generativeai as genai
from openai import OpenAI
import gradio as gr

# --- 1. إعداد المفاتيح ---
# استبدل النجوم بمفاتيحك الحقيقية
os.environ["OPENAI_API_KEY"] = "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" 
os.environ["GOOGLE_API_KEY"] = "AIzaSyCEha0n0YrS-1nFwOLRptOqW0_ixBkRJqw"

# تهيئة العملاء
oa_client = OpenAI()
genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
# تأكد من استخدام موديل متاح مثل 1.5-flash
gemini_model = genai.GenerativeModel('gemini-2.5-flash')

# --- 2. بيانات اللغات ---
LANG_DATA = {
    "العربية": {"code": "ar", "voice": "ar-SA-ZariyahNeural", "gen": "Arabic"},
    "الإنجليزية": {"code": "en", "voice": "en-US-GuyNeural", "gen": "English"},
    "الأوردو": {"code": "ur", "voice": "ur-PK-AsadNeural", "gen": "Urdu"}
}

# --- 3. الدوال الأساسية ---

async def generate_speech_cloud(text, target_lang_name):
    """تحويل النص إلى صوت باستخدام Edge-TTS"""
    voice = LANG_DATA[target_lang_name]["voice"]
    filename = f"speech_{uuid.uuid4().hex}.mp3"
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(filename)
    return filename

# حولنا الدالة إلى async def لتتوافق مع Gradio و Edge-TTS
async def cloud_translator_v3(audio_path, text_input, source_lang, target_lang):
    try:
        input_text = ""
        
        # أ- STT (OpenAI Whisper)
        if audio_path:
            with open(audio_path, "rb") as audio_file:
                transcript = oa_client.audio.transcriptions.create(
                    model="whisper-1", 
                    file=audio_file,
                    language=LANG_DATA[source_lang]["code"]
                )
                input_text = transcript.text
        elif text_input:
            input_text = text_input.strip()

        if not input_text:
            return "⚠️ لم يتم اكتشاف نص.", None

        # ب- الترجمة (Gemini)
        target_gen_name = LANG_DATA[target_lang]["gen"]
        prompt = (f"Translate from {source_lang} to {target_gen_name}. "
                  f"Provide ONLY the translation text without any notes: \n\n{input_text}")
        
        # تشغيل الترجمة في Thread منفصل لعدم تعطيل الـ Async
        response = await asyncio.to_thread(gemini_model.generate_content, prompt)
        translated_text = response.text.strip()

        # ج- TTS (Edge-TTS)
        # الآن نستخدم await مباشرة وبكل بساطة
        audio_out = await generate_speech_cloud(translated_text, target_lang)

        final_msg = f"✅ النص الأصلي:\n{input_text}\n\n✨ الترجمة ({target_lang}):\n{translated_text}"
        return final_msg, audio_out

    except Exception as e:
        return f"❌ خطأ: {str(e)}", None

# --- 4. واجهة Gradio ---
with gr.Blocks(theme=gr.themes.Soft()) as demo:
    gr.Markdown("# 🎙️ Bridge AI - Cloud Mode")
    
    with gr.Row():
        with gr.Column():
            audio_in = gr.Audio(sources=["upload", "microphone"], type="filepath", label="سجل صوتك")
            text_in = gr.Textbox(label="أو اكتب نصاً")
            with gr.Row():
                src_lang = gr.Dropdown(choices=list(LANG_DATA.keys()), label="من", value="العربية")
                tgt_lang = gr.Dropdown(choices=list(LANG_DATA.keys()), label="إلى", value="الإنجليزية")
            btn = gr.Button("🚀 ابدأ المعالجة", variant="primary")

        with gr.Column():
            txt_out = gr.Textbox(label="النتائج المكتوبة", lines=10)
            aud_out = gr.Audio(label="الاستماع")

    btn.click(
        fn=cloud_translator_v3,
        inputs=[audio_in, text_in, src_lang, tgt_lang],
        outputs=[txt_out, aud_out]
    )

if __name__ == "__main__":
    # استخدام share=True للحصول على رابط خارجي
    demo.launch(share=True)