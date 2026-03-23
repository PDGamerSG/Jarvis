from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from groq import Groq
import os
from dotenv import load_dotenv
load_dotenv()

app = FastAPI()

# CORS so any client can reach the backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load API key from environment variable — never hardcode it
client = Groq(api_key=os.environ.get("GROQ_API_KEY"))

# Conversation memory — stores the full chat history per session
conversation_history = []

SYSTEM_PROMPT = {
    "role": "system",
    "content": (
        "You are Jarvis, a smart, helpful and concise personal AI assistant. "
        "Keep replies short and conversational unless the user asks for detail. "
        "You remember what was said earlier in the conversation."
    )
}

class Message(BaseModel):
    text: str

@app.post("/chat")
async def chat(message: Message):
    # Add the new user message to history
    conversation_history.append({
        "role": "user",
        "content": message.text
    })

    # Keep history from growing too large (last 20 messages = 10 exchanges)
    trimmed_history = conversation_history[-20:]

    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[SYSTEM_PROMPT] + trimmed_history,
        max_tokens=1024
    )

    reply = response.choices[0].message.content

    # Add Jarvis's reply to history too
    conversation_history.append({
        "role": "assistant",
        "content": reply
    })

    return {"reply": reply}

@app.post("/reset")
async def reset():
    """Call this to clear conversation memory and start fresh."""
    conversation_history.clear()
    return {"status": "Conversation reset."}

@app.get("/")
async def root():
    return {"status": "Jarvis backend is running!"}
