
import asyncio
import edge_tts
import google.generativeai as genai
import whisper
import nest_asyncio
import torch
import gc
import uuid
import gradio as gr
import os

nest_asyncio.apply()

# --- 1. إعداد Gemini API ---
GOOGLE_API_KEY = "AIzaSyCEha0n0YrS-1nFwOLRptOqW0_ixBkRJqw"
genai.configure(api_key=GOOGLE_API_KEY)
gemini = genai.GenerativeModel('gemini-2.5-flash')

# --- 2. إعداد Whisper Large-v3 ---
device = "cuda" if torch.cuda.is_available() else "cpu"
stt_model = whisper.load_model("large-v3").to(device)

# --- 3. بيانات اللغات الثلاث ---
LANG_DATA = {
    "العربية": {"code": "ar", "voice": "ar-SA-ZariyahNeural", "gen": "Arabic"},
    "الإنجليزية": {"code": "en", "voice": "en-US-GuyNeural", "gen": "English"},
    "الأوردو": {"code": "ur", "voice": "ur-PK-AsadNeural", "gen": "Urdu"}
}

async def generate_speech_pro(text, target_name):
    voice = LANG_DATA[target_name]["voice"]
    filename = f"result_{uuid.uuid4().hex}.mp3"
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(filename)
    return filename

def pro_translator_v2(audio_path, text_input, source_lang, target_lang):
    try:
        input_text = ""
        src_code = LANG_DATA[source_lang]["code"]

        # أ- معالجة المدخل (صوت أو نص)
        if audio_path:
            # هنا أجبرنا Whisper على لغة المدخل المختارة لتقليل الخطأ
            result = stt_model.transcribe(audio_path, language=src_code, beam_size=5)
            input_text = result['text'].strip()
        elif text_input:
            input_text = text_input.strip()

        if not input_text:
            return "⚠️ لم يتم اكتشاف نص، تأكد من اختيار لغة المصدر الصحيحة.", None

        # ب- الترجمة (Gemini)
        target_gen_name = LANG_DATA[target_lang]["gen"]
        prompt = (f"Translate from {source_lang} to {target_gen_name}. "
                  f"Provide ONLY the translation: \n\n{input_text}")

        response = gemini.generate_content(prompt)
        translated_text = response.text.strip()

        # ج- تحويل الترجمة لصوت
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        audio_out = loop.run_until_complete(generate_speech_pro(translated_text, target_lang))
        loop.close()

        gc.collect()
        if torch.cuda.is_available(): torch.cuda.empty_cache()

        final_msg = f"✅ النص المكتشف ({source_lang}):\n{input_text}\n\n✨ الترجمة ({target_lang}):\n{translated_text}"
        return final_msg, audio_out

    except Exception as e:
        return f"❌ خطأ: {str(e)}", None

# ---  Gradio  ---
with gr.Blocks(theme=gr.themes.Soft()) as demo:
    gr.Markdown("# 🎙️ مترجم اللغات")
    gr.Markdown(" Whisper Large-v3 و Gemini.")

    with gr.Row():
        with gr.Column():
            audio_input = gr.Audio(sources=["upload", "microphone"], type="filepath", label="الصوت")
            text_input = gr.Textbox(label="أو النص")

            with gr.Row():
                source_lang = gr.Dropdown(choices=list(LANG_DATA.keys()), label="اللغة الأصلية (من):", value="العربية")
                target_lang = gr.Dropdown(choices=list(LANG_DATA.keys()), label="اللغة المستهدفة (إلى):", value="الإنجليزية")

            submit_btn = gr.Button("🚀 ابدأ المعالجة", variant="primary")

        with gr.Column():
            output_text = gr.Textbox(label="النتائج", lines=10)
            output_audio = gr.Audio(label="الاستماع", autoplay=True)

    submit_btn.click(
        fn=pro_translator_v2,
        inputs=[audio_input, text_input, source_lang, target_lang],
        outputs=[output_text, output_audio]
    )

demo.launch(share=True, debug=True)