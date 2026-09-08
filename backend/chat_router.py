"""
chat_router.py — DermaBot RAG Chat
────────────────────────────────────
POST /api/v1/chat
  Receives a question from the Flutter app, passes it through the FAISS RAG
  pipeline backed by dermatology textbooks, and returns a GPT-generated answer.
"""

import asyncio
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from RAG.derm_question_vector import ask_question_silent

router = APIRouter()


class ChatRequest(BaseModel):
    question: str


class ChatResponse(BaseModel):
    answer: str


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    """
    Receives a question from the Flutter app,
    runs it through the RAG pipeline, and returns the answer.
    """
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty.")

    # Run blocking RAG call in a thread so it doesn't block the event loop
    answer = await asyncio.to_thread(ask_question_silent, req.question)
    return ChatResponse(answer=answer)