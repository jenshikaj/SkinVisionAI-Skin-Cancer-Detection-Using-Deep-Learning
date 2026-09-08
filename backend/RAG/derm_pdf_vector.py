"""
Converts dermatology PDF textbooks into a FAISS vector index.
Run this script once to build the vector DB before starting the server.
"""

import faiss
import PyPDF2
import numpy as np
import pickle
import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()  # loads .env from the project root

# ── OpenAI client ─────────────────────────────────────────────────────────────
client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))


def extract_pdf_text(pdf_path: str) -> list[dict]:
    """
    Reads all pages from a PDF and returns a list of page dicts:
    { text, page_number, source }
    """
    print(f"\n📄 Reading PDF: {pdf_path}")
    with open(pdf_path, "rb") as f:
        reader = PyPDF2.PdfReader(f)
        pages = []
        for page_number, page in enumerate(reader.pages):
            text = page.extract_text() or ""
            pages.append({
                "text": text,
                "page_number": page_number + 1,
                "source": os.path.basename(pdf_path)
            })
    print(f"   → {len(pages)} pages extracted")
    return pages


def pdfs_to_vectors(pdf_files: list[str], output_dir: str = "RAG") -> None:
    """
    Processes a list of PDFs into a FAISS vector index.
    Saves:
      - {output_dir}/derm_vectors.index
      - {output_dir}/derm_chunks.pkl
    """
    os.makedirs(output_dir, exist_ok=True)

    all_chunks: list[str] = []
    all_metadata: list[dict] = []

    # ── Step 1: Extract text + chunk every PDF ───────────────────────────────
    for pdf_path in pdf_files:
        if not os.path.exists(pdf_path):
            print(f"⚠️  File not found, skipping: {pdf_path}")
            continue

        pages = extract_pdf_text(pdf_path)
        full_text = "".join([p["text"] for p in pages])
        total_pages = len(pages)
        total_chars = len(full_text)

        print(f"📊 {os.path.basename(pdf_path)}: {total_pages} pages, {total_chars:,} characters")

        # Chunk with 100-char overlap for better context continuity
        chunk_size = 500
        chunk_step = 400   # step < chunk_size → overlap
        chars_per_page = max(1, total_chars // total_pages)

        for i in range(0, total_chars, chunk_step):
            chunk_text = full_text[i: i + chunk_size]
            if not chunk_text.strip():
                continue

            estimated_page = min((i // chars_per_page) + 1, total_pages)

            all_chunks.append(chunk_text)
            all_metadata.append({
                "source": os.path.basename(pdf_path),
                "estimated_page": estimated_page
            })

    if not all_chunks:
        print("❌ No chunks generated. Check your PDF paths.")
        return

    print(f"\n✂️  Total chunks from all PDFs: {len(all_chunks)}\n")

    # ── Step 2: Batch embed with OpenAI ─────────────────────────────────────
    print("🔄 Getting embeddings from OpenAI (batched)...")
    embeddings: list[list[float]] = []
    batch_size = 100

    for batch_start in range(0, len(all_chunks), batch_size):
        batch = all_chunks[batch_start: batch_start + batch_size]
        print(f"   Embedding batch {batch_start // batch_size + 1} "
              f"({batch_start + 1}–{min(batch_start + batch_size, len(all_chunks))} "
              f"of {len(all_chunks)})")

        response = client.embeddings.create(
            model="text-embedding-3-small",
            input=batch
        )
        for item in response.data:
            embeddings.append(item.embedding)

    embeddings_np = np.array(embeddings, dtype="float32")
    print(f"\n✅ Embedding complete. Shape: {embeddings_np.shape}")

    # ── Step 3: Build FAISS index (Inner Product = cosine for unit vectors) ──
    print("\n🗂️  Building FAISS index...")
    dimension = embeddings_np.shape[1]   # 1536 for text-embedding-3-small
    index = faiss.IndexFlatIP(dimension)

    # Normalise vectors → cosine similarity via inner product
    faiss.normalize_L2(embeddings_np)
    index.add(embeddings_np)

    # ── Step 4: Persist ──────────────────────────────────────────────────────
    index_path = os.path.join(output_dir, "derm_vectors.index")
    chunks_path = os.path.join(output_dir, "derm_chunks.pkl")

    print(f"💾 Saving index → {index_path}")
    faiss.write_index(index, index_path)

    print(f"💾 Saving chunks → {chunks_path}")
    with open(chunks_path, "wb") as f:
        pickle.dump({
            "chunks": all_chunks,
            "metadata": all_metadata,
            "total_chunks": len(all_chunks),
            "pdf_files": pdf_files,
            "embedding_model": "text-embedding-3-small",
            "dimension": dimension,
        }, f)

    print("\n🎉 Vector DB created successfully!")
    print(f"   PDFs indexed : {[os.path.basename(p) for p in pdf_files]}")
    print(f"   Total chunks : {len(all_chunks)}")
    print(f"   Dimensions   : {dimension}")


if __name__ == "__main__":
    pdf_files = [
        "RAG/dermatology_knowledge_base/Derm_Handbook_3rd-Edition-_Nov_2020-FINAL.pdf",
        "RAG/dermatology_knowledge_base/Oxford-Handbook-of-Medical-Dermatology.pdf",
    ]
    pdfs_to_vectors(pdf_files)