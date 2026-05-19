import numpy as np

# =========================================================
# SHAP-LIKE FEATURE CONTRIBUTION
# =========================================================

def generate_shap_values(

    phone_score,
    behavior_score,
    emotion_score,
    hrv_score,
    text_score
):

    contributions = {

        "Phone Usage":

            round(phone_score * 0.40, 2),

        "Behavior":

            round(behavior_score * 0.50, 2),

        "Emotion":

            round(emotion_score * 0.30, 2),

        "HRV":

            round(hrv_score * 0.20, 2),

        "Instagram Text":

            round(text_score * 0.35, 2)
    }

    return contributions

# =========================================================
# CAPTUM-LIKE FACIAL EXPLANATION
# =========================================================

def generate_facial_explanation(

    emotion,
    emotion_score
):

    explanations = {

        "happy":
            "Detected smile intensity and positive eye activity.",

        "neutral":
            "Balanced facial expression with low emotional stress markers.",

        "sad":
            "Detected lowered eyes and reduced smile intensity.",

        "angry":
            "Detected eyebrow tension and compressed lips.",

        "fear":
            "Detected widened eyes and facial stress patterns.",

        "disgust":
            "Detected nose and lip contraction patterns.",

        "surprise":
            "Detected widened eyes and raised eyebrows."
    }

    return explanations.get(

        emotion,

        "Facial explanation unavailable."
    )

# =========================================================
# REAL-TIME FAIRNESS CONFIDENCE
# =========================================================

def generate_fairness_confidence(

    phone_score,
    behavior_score,
    emotion_score,
    hrv_score,
    text_score
):

    scores = np.array([

        phone_score,

        behavior_score,

        emotion_score,

        hrv_score,

        text_score
    ])

    variance = np.var(scores)

    confidence = 100 - variance

    confidence = max(

        0,

        min(100, confidence)
    )

    if confidence > 80:

        statement = (

            "Prediction stable across modalities."
        )

    elif confidence > 60:

        statement = (

            "Moderate modality agreement detected."
        )

    else:

        statement = (

            "Prediction variance across modalities is high."
        )

    return {

        "fairness_confidence":
            round(confidence, 2),

        "statement":
            statement
    }

# =========================================================
# COMPLETE XAI
# =========================================================

def generate_complete_xai(

    phone_score,
    behavior_score,
    emotion,
    emotion_score,
    hrv_score,
    text_score
):

    shap_values = generate_shap_values(

        phone_score,

        behavior_score,

        emotion_score,

        hrv_score,

        text_score
    )

    facial_explanation = generate_facial_explanation(

        emotion,

        emotion_score
    )

    fairness = generate_fairness_confidence(

        phone_score,

        behavior_score,

        emotion_score,

        hrv_score,

        text_score
    )

    return {

        "shap":
            shap_values,

        "captum":
            facial_explanation,

        "fairness":
            fairness
    }