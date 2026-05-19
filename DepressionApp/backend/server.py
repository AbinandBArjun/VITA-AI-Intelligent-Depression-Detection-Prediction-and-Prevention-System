from fastapi import FastAPI, UploadFile, File, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from transformers import pipeline
from xai_service import generate_complete_xai

import cv2
import numpy as np
import serial
import threading
import json
import torch
from model import DepressionModel
from captum.attr import IntegratedGradients

import os
from dotenv import load_dotenv

from langchain_community.chat_models import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

import requests
import io

from PIL import Image

import torchvision.transforms as transforms

import warnings
warnings.filterwarnings("ignore")

load_dotenv()

app = FastAPI()



# =========================================================
# FACE DETECTOR
# =========================================================

face_cascade = cv2.CascadeClassifier(

    cv2.data.haarcascades +

    'haarcascade_frontalface_default.xml'
)

# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================================================
# LOAD PHONE MODEL
# =========================================================

if os.path.exists("pytorch_model.pt"):

    phone_model = DepressionModel()

    phone_model.load_state_dict(
        torch.load(
            "pytorch_model.pt",
            map_location=torch.device('cpu')
        )
    )

    phone_model.eval()

else:

    raise FileNotFoundError(
        "pytorch_model.pt not found. "
        "Run train_model.py first."
    )

# =========================================================
# DISTILROBERTA SENTIMENT MODEL
# =========================================================

sentiment_pipeline = pipeline(

    "sentiment-analysis",

    model="cardiffnlp/twitter-roberta-base-sentiment-latest"
)

# =========================================================
# XAI
# =========================================================

ig = IntegratedGradients(phone_model)

# =========================================================
# GLOBAL VARIABLES
# =========================================================

IG_TOKEN = os.getenv("IG_TOKEN")

INSTAGRAM_ID = os.getenv("INSTAGRAM_ID")

# =========================================================
# REALTIME HRV VARIABLES
# =========================================================

latest_bpm = 0

latest_rmssd = 0

latest_sdnn = 0

latest_hrv_score = 40

emotion_history = []
# =========================================================
# REALTIME HRV SERIAL READER
# =========================================================

def calculate_hrv_score(rmssd, sdnn):

    score = 50

    # =============================================
    # RMSSD ANALYSIS
    # =============================================

    if rmssd < 20:

        score += 25

    elif rmssd < 40:

        score += 10

    elif rmssd > 100:

        score -= 10

    # =============================================
    # SDNN ANALYSIS
    # =============================================

    if sdnn < 30:

        score += 20

    elif sdnn < 50:

        score += 10

    elif sdnn > 120:

        score -= 10

    score = max(0, min(100, score))

    return score


def hrv_serial_reader():

    global latest_bpm
    global latest_rmssd
    global latest_sdnn
    global latest_hrv_score

    try:

        ser = serial.Serial(

            'COM3',

            115200,

            timeout=1
        )

        print("✅ HRV serial connected")

        while True:

            try:

                line = ser.readline().decode().strip()

                if not line:
                    continue

                if not line.startswith('{'):
                    continue

                data = json.loads(line)

                latest_bpm = float(
                    data.get("bpm", 0)
                )

                latest_rmssd = float(
                    data.get("rmssd", 0)
                )

                latest_sdnn = float(
                    data.get("sdnn", 0)
                )

                if latest_rmssd > 0 and latest_sdnn > 0:

                    latest_hrv_score = calculate_hrv_score(

        latest_rmssd,

        latest_sdnn
    )

                print(

                    f"HRV | "

                    f"BPM={latest_bpm} | "

                    f"RMSSD={latest_rmssd} | "

                    f"SDNN={latest_sdnn} | "

                    f"HRVScore={latest_hrv_score}"
                )

            except Exception as e:

                print("HRV parse error:", e)

    except Exception as e:

        print("❌ HRV serial connection failed:", e)

# =========================================================
# START HRV THREAD
# =========================================================

threading.Thread(

    target=hrv_serial_reader,

    daemon=True

).start()

# =========================================================
# EMOTION SCORE MAP
# =========================================================

def emotion_score(emotion):

    return {

        "happy": 10,

        "neutral": 30,

        "sad": 90,

        "angry": 70,

        "fear": 80,

        "disgust": 85,

        "surprise": 40

    }.get(emotion, 30)

# =========================================================
# TRAINED FER2013 EMOTION MODEL
# =========================================================

emotion_model = None

emotion_labels = [

    'angry',

    'disgust',

    'fear',

    'happy',

    'sad',

    'surprise',

    'neutral'
]

from torchvision.models import resnet18

def load_emotion_model():

    global emotion_model

    if emotion_model is None:

        try:

            emotion_model = resnet18(
                weights=None
            )

            emotion_model.fc = torch.nn.Linear(

                emotion_model.fc.in_features,

                7
            )

            emotion_model.load_state_dict(

                torch.load(

                    "emotion_model.pth",

                    map_location=torch.device('cpu')
                )
            )

            emotion_model.eval()

            print(
                "✅ Trained FER2013 model loaded"
            )

        except Exception as e:

            print(
                f"Emotion model load error: {e}"
            )

            emotion_model = None

    return emotion_model is not None
# =========================================================
# IMAGE TRANSFORM
# =========================================================

transform = transforms.Compose([

    transforms.Resize((224, 224)),

    transforms.ToTensor(),

    transforms.Normalize(

        mean=[0.485, 0.456, 0.406],

        std=[0.229, 0.224, 0.225]
    )
])

# =========================================================
# DEPRESSION KEYWORDS
# =========================================================

depression_keywords = {

    "depressed": 30,
    "sad": 20,
    "hopeless": 35,
    "empty": 25,
    "worthless": 40,
    "tired": 15,
    "alone": 20,
    "lonely": 25,
    "anxious": 20,
    "stress": 15,
    "cry": 20,
    "suicidal": 60,
    "unhappy": 20,
    "miserable": 35,
    "failure": 20,
    "hate myself": 50,
}

# =========================================================
# HEALTH ENDPOINT
# =========================================================

@app.get("/health")
async def health():

    return {

        "status": "ok",

        "message": "Server running successfully"
    }



# =========================================================
# TEXT ANALYSIS
# =========================================================

@app.post("/text")
async def text_analysis(text: str = Form(...)):

    text_lower = text.lower()

    result = sentiment_pipeline(text)[0]

    label = result['label']

    confidence = result['score']

    if label == "LABEL_2":

        roberta_score = 10

    elif label == "LABEL_1":

        roberta_score = 50

    else:

        roberta_score = 90

    keyword_score = 0

    matched_keywords = []

    for keyword, score in depression_keywords.items():

        if keyword in text_lower:

            keyword_score += score

            matched_keywords.append(keyword)

    keyword_score = min(
        keyword_score,
        100
    )

    final_text_score = (

        0.7 * roberta_score +

        0.3 * keyword_score
    )

    final_text_score = max(
        0,
        min(100, final_text_score)
    )

    print(
        f"RoBERTa={roberta_score} | "
        f"Keywords={matched_keywords}"
    )

    return {

        "text_score":
            round(final_text_score, 2),

        "roberta_score":
            roberta_score,

        "keyword_score":
            keyword_score,

        "matched_keywords":
            matched_keywords,

        "confidence":
            round(confidence, 3)
    }

# =========================================================
# MAIN PREDICTION ENDPOINT
# =========================================================

@app.post("/predict")
async def predict(

    screen_time: float = Form(...),

    night_usage: float = Form(0.0),

    social_media_hours: float = Form(0.0),

    unlock_count: int = Form(0),

    text_score: float = Form(50.0),

    files: list[UploadFile] = File(...)

):

    global latest_hrv_score
    global emotion_history

    print("✅ Prediction request received")

    # =====================================================
    # PHONE SCORE
    # =====================================================

    input_tensor = torch.tensor(
        [[screen_time]],
        dtype=torch.float32
    )

    with torch.no_grad():

        phone_score = (
            phone_model(input_tensor)
            .item()
        )

    # =====================================================
    # ADVANCED PHONE BEHAVIOR SCORE
    # =====================================================

    behavior_score = phone_score

    # =============================================
    # NIGHT USAGE
    # =============================================

    if night_usage > 2:

        behavior_score += 20

    elif night_usage > 1:

        behavior_score += 10

    # =============================================
    # SOCIAL MEDIA OVERUSE
    # =============================================

    if social_media_hours > 5:

        behavior_score += 20

    elif social_media_hours > 3:

        behavior_score += 10

    # =============================================
    # COMPULSIVE UNLOCKING
    # =============================================

    if unlock_count > 120:

        behavior_score += 15

    elif unlock_count > 80:

        behavior_score += 8

    behavior_score = max(
        0,
        min(100, behavior_score)
    )

    print(

        f"Behavior Analytics | "

        f"Night={night_usage}h | "

        f"Social={social_media_hours}h | "

        f"Unlocks={unlock_count} | "

        f"BehaviorScore={behavior_score}"
    )

    # =====================================================
    # EMOTION DETECTION
    # =====================================================

    model_loaded = load_emotion_model()

    if files and model_loaded:

        try:

            file = files[0]

            contents = await file.read()

            image = Image.open(
                io.BytesIO(contents)
            ).convert('RGB')

            frame = np.array(image)

            gray = cv2.cvtColor(
                frame,
                cv2.COLOR_RGB2GRAY
            )

            faces = face_cascade.detectMultiScale(

                gray,

                scaleFactor=1.1,

                minNeighbors=5,

                minSize=(30, 30)
            )

            if len(faces) > 0:

                largest_face = max(

                    faces,

                    key=lambda rect:
                        rect[2] * rect[3]
                )

                x, y, w, h = largest_face

                face_crop = frame[
                    y:y+h,
                    x:x+w
                ]

                face_image = Image.fromarray(
                    face_crop
                )

                print("✅ Face detected")

            else:

                face_image = image

                print(
                    "⚠️ No face detected, using full image"
                )

            input_tensor = transform(
                face_image
            ).unsqueeze(0)

            with torch.no_grad():

                outputs = emotion_model(
                    input_tensor
                )

                pred_id = torch.argmax(
                    outputs,
                    dim=1
                ).item()

                emotion = emotion_labels[pred_id]

            raw_emo_score = emotion_score(
                emotion
            )

            emotion_history.append(
                raw_emo_score
            )

            if len(emotion_history) > 10:

                emotion_history.pop(0)

            emo_score = (

                sum(emotion_history)

                / len(emotion_history)
            )

            print(
                f"Emotion={emotion} | "
                f"Raw={raw_emo_score} | "
                f"Smoothed={emo_score}"
            )

        except Exception as e:

            print(
                f"Emotion prediction error: {e}"
            )

            emotion = "neutral"

            emo_score = 30.0

    else:

        emotion = "neutral"

        emo_score = 30.0

    # =====================================================
    # TEXT SCORE VALIDATION
    # =====================================================

    text_s = max(
        0,
        min(100, text_score)
    )

    # =====================================================
    # FINAL UNIFIED SCORE
    # =====================================================

    final_score = (

        0.35 * behavior_score +

        0.25 * emo_score +

        0.25 * latest_hrv_score +

        0.15 * text_s
    )

    print("✅ Unified score calculated")

    # =====================================================
    # REAL-TIME XAI
    # =====================================================

    xai_result = generate_complete_xai(

    phone_score,

    behavior_score,

    emotion,

    emo_score,

    latest_hrv_score,

    text_s
)

    print(
        f"Phone={phone_score} | "
        f"Behavior={behavior_score} | "
        f"Emotion={emo_score} | "
        f"HRV={latest_hrv_score} | "
        f"Text={text_s} | "
        f"Final={final_score}"
    )

    return {

        "phone_score":
            float(phone_score),

        "behavior_score":
            round(behavior_score, 2),

        "night_usage":
            float(night_usage),

        "social_media_hours":
            float(social_media_hours),

        "unlock_count":
            int(unlock_count),

        "emotion":
            emotion,

        "emotion_score":
            float(emo_score),

        "hrv_score":
            float(latest_hrv_score),

        "bpm":
            float(latest_bpm),

        "rmssd":
            float(latest_rmssd),

        "sdnn":
            float(latest_sdnn),

        "text_score":
            float(text_s),

        "unified_score":
            round(final_score, 2),

        "xai":
            xai_result
    }

# =========================================================
# XAI EXPLANATION
# =========================================================

@app.post("/explain")
async def explain(data: dict):

    screen_time = data["screen_time"]

    input_tensor = torch.tensor(

        [[float(screen_time)]],

        dtype=torch.float32

    ).requires_grad_()

    attributions = ig.attribute(

        input_tensor,

        target=0,

        baselines=torch.zeros_like(
            input_tensor
        )
    )

    return {

        "input":
            screen_time,

        "prediction":
            phone_model(input_tensor).item(),

        "attribution_screen_time":
            attributions.sum().item()
    }

# =========================================================
# AGENTIC AI
# =========================================================

llm = ChatOllama(

    model="gemma:2b",

    temperature=0.3
)

agent_prompt = ChatPromptTemplate.from_template("""

You are Vita AI,
an empathetic and intelligent mental health assistant.

Your role:
- analyze multimodal depression indicators
- provide personalized wellness guidance
- encourage healthy lifestyle changes
- suggest emotional coping strategies
- recommend professional support when risk is high

Patient Metrics:

Unified Depression Score: {unified_score}/100

Phone Usage Score: {phone_score}

Behavior Score: {behavior_score}

Detected Emotion: {emotion}

Emotion Score: {emotion_score}

HRV Score: {hrv_score}

Instagram Text Score: {text_score}

Instructions:

1. Determine risk level:
   - Low
   - Moderate
   - High
   - Critical

2. Explain likely contributing factors.

3. Generate personalized recommendations.

4. Recommendations should include:
   - sleep advice
   - digital wellbeing
   - emotional wellbeing
   - mindfulness
   - exercise
   - relaxation

5. If score > 75:
   strongly encourage professional mental health support.

6. Keep response:
   - supportive
   - concise
   - human-like
   - non-judgmental

""")

agent_chain = (
    agent_prompt
    | llm
    | StrOutputParser()
)

@app.post("/agentic")
async def agentic(data: dict):

    try:

        result = agent_chain.invoke({

            "unified_score":
                data["unified_score"],

            "phone_score":
                data["phone_score"],

            "behavior_score":
                data.get("behavior_score", 0),

            "emotion":
                data["emotion"],

            "emotion_score":
                data["emotion_score"],

            "hrv_score":
                data["hrv_score"],

            "text_score":
                data["text_score"]
        })

        return {

            "agentic_ai":
                result
        }

    except Exception as e:

        print(f"Agentic AI error: {e}")

        return {

            "agentic_ai":

                "AI recommendations temporarily unavailable."
        }

# =========================================================
# INSTAGRAM ANALYSIS
# =========================================================

@app.post("/instagram_analysis")
async def instagram_analysis(

    username: str = Form(...),

    limit: int = Form(10)

):

    try:

        url = (

            "https://graph.facebook.com/v20.0/"

            f"{INSTAGRAM_ID}/media"

            f"?fields=id,caption,media_type"

            f"&access_token={IG_TOKEN}"

            f"&limit={limit}"
        )

        response = requests.get(url)

        response.raise_for_status()

        data = response.json()

        captions = []

        if 'data' in data:

            for post in data['data']:

                if (

                    post.get('media_type')

                    in ['IMAGE', 'VIDEO', 'CAROUSEL_ALBUM']

                    and post.get('caption')

                ):

                    captions.append(
                        post['caption']
                    )

        if not captions:

            return {

                "error":
                    "No captions found",

                "posts_analyzed": 0
            }

        scores = []

        for caption in captions:

            result = sentiment_pipeline(caption)[0]

            label = result['label']

            if label == "LABEL_2":

                score = 10

            elif label == "LABEL_1":

                score = 50

            else:

                score = 90

            scores.append(score)

        avg_score = (

            sum(scores)

            / len(scores)
        )

        return {

            "avg_text_score":
                round(avg_score, 2),

            "posts_analyzed":
                len(captions),

            "sample_captions":
                captions[:3]
        }

    except Exception as e:

        return {

            "error": str(e),

            "posts_analyzed": 0
        }