"""
Retrieval-Augmented Generation for dermatology Q&A.

Embeds the user's question, retrieves the top-5 most relevant chunks
from the FAISS index built by derm_pdf_vector.py, then passes them
to GPT-4o-mini to generate a patient-friendly answer.
"""

import faiss
import numpy as np
import pickle
import os
import logging
from openai import OpenAI

logger = logging.getLogger(__name__)

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

# Resolve paths relative to this file so imports work from any working dir
_RAG_DIR     = os.path.dirname(os.path.abspath(__file__))
_INDEX_PATH  = os.path.join(_RAG_DIR, "derm_vectors.index")
_CHUNKS_PATH = os.path.join(_RAG_DIR, "derm_chunks.pkl")


def ask_question_silent(question: str) -> str:
    """
    Takes a user question, retrieves relevant chunks from the FAISS vector DB,
    and returns a GPT-generated educational dermatology answer.
    """
    # ── Guard: check vector DB exists ────────────────────────────────────────
    if not os.path.exists(_INDEX_PATH) or not os.path.exists(_CHUNKS_PATH):
        return (
            "The dermatology knowledge base is not available. "
            "Please run derm_pdf_vector.py first to build the vector database."
        )

    # ── Load FAISS index + chunks ─────────────────────────────────────────────
    index = faiss.read_index(_INDEX_PATH)

    with open(_CHUNKS_PATH, "rb") as f:
        data = pickle.load(f)

    chunks   = data["chunks"]
    metadata = data.get("metadata", [])

    # ── Embed the question ────────────────────────────────────────────────────
    emb_response = client.embeddings.create(
        model="text-embedding-3-small",
        input=question
    )
    q_vec = np.array(emb_response.data[0].embedding).reshape(1, -1).astype("float32")
    faiss.normalize_L2(q_vec)   # Normalise to match index

    # ── Retrieve top-5 relevant chunks ────────────────────────────────────────
    _, idxs = index.search(q_vec, 5)

    context_parts = []
    for idx in idxs[0]:
        if idx < len(chunks):
            chunk_text = chunks[idx]
            if idx < len(metadata):
                source = metadata[idx].get("source", "unknown")
                page   = metadata[idx].get("estimated_page", "?")
                context_parts.append(f"[Source: {source}, Page ~{page}]\n{chunk_text}")
            else:
                context_parts.append(chunk_text)

    context = "\n\n---\n\n".join(context_parts)

    # ── Generate answer via GPT ───────────────────────────────────────────────
    try:
        reply = client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=600,
            temperature=0.3,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are an educational dermatology assistant for general users. "
                        "Your goal is to provide clear, informative, and helpful answers about skin conditions, "
                        "symptoms, and general skincare based strictly on the provided medical context.\n\n"
                        "STRICT RULES:\n"
                        "- Do NOT provide medical diagnoses.\n"
                        "- Do NOT recommend specific medication names or dosages.\n"
                        "- Do NOT provide treatment prescriptions.\n"
                        "- For moderate or severe conditions, always recommend consulting a qualified dermatologist.\n"
                        "- Answer ONLY using the provided context. If the context does not contain enough information, "
                        "say so clearly and suggest the user see a dermatologist.\n"
                        "- Keep answers concise, friendly, and easy to understand for non-medical users.\n"
                        "- Use bullet points where appropriate for readability."
                    )
                },
                {
                    "role": "user",
                    "content": (
                        f"CONTEXT FROM DERMATOLOGY KNOWLEDGE BASE:\n{context}\n\n"
                        f"USER QUESTION: {question}\n\n"
                        "Please provide a clear, educational, non-prescriptive answer based on the context above:"
                    )
                }
            ]
        )
        return reply.choices[0].message.content

    except Exception as e:
        logger.error(f"GPT chat completion failed: {e}")
        return (
            "I'm having trouble reaching the knowledge base right now. "
            "Please try again in a moment, or consult a dermatologist for your question."
        )