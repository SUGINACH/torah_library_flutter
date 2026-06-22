#!/usr/bin/env python3
"""
transcription_worker.py
=======================
Called by the Flutter app via Process.start().
This file is the exact equivalent of the TranscriptionWorker(QThread) class
that lived inside audio_panel.py, extracted into its own process.

Usage
-----
  python3 transcription_worker.py <audio_path> <model_size>

Protocol
--------
Each line written to stdout is a JSON object:
  {"type": "progress", "text": "..."}   — real-time status update
  {"type": "result",   "text": "..."}   — final transcription (success)
  {"type": "error",    "text": "..."}   — failure message

The Flutter parent reads these lines via stdout and updates the UI.
stderr is left for Python warnings / debug output and is NOT shown to the user.
"""
from __future__ import annotations

import json
import sys


# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

def emit(event_type: str, text: str) -> None:
    """Write one JSON event line to stdout and flush immediately.

    flush=True is critical — without it lines are buffered and the Flutter
    parent would not receive progress updates until the buffer fills.
    """
    print(json.dumps({"type": event_type, "text": text}), flush=True)


# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────

def main() -> None:
    if len(sys.argv) < 3:
        emit("error", "Usage: transcription_worker.py <audio_path> <model_size>")
        return

    audio_path: str = sys.argv[1]
    model_size: str = sys.argv[2]

    # ── Import check (mirrors WHISPER_AVAILABLE) ─────────────────────
    try:
        from faster_whisper import WhisperModel  # noqa: PLC0415
    except ImportError:
        emit(
            "error",
            "faster-whisper אינה מותקנת. הרץ: pip install faster-whisper",
        )
        return

    # ── Transcription (mirrors TranscriptionWorker.run) ───────────────
    try:
        emit(
            "progress",
            "טוען מודל בינה מלאכותית (ייתכן שתתבצע הורדה בפעם הראשונה)...",
        )

        # compute_type="int8" reduces memory on CPU — same as original
        model = WhisperModel(model_size, device="cpu", compute_type="int8")

        emit("progress", "מתחיל תמלול...")
        segments, info = model.transcribe(audio_path, language="he", beam_size=5)

        full_text: list[str] = []
        for segment in segments:
            # Real-time progress update per segment — same as original
            emit(
                "progress",
                f"מתמלל... ({segment.start:.1f}s / {info.duration:.1f}s)",
            )
            full_text.append(segment.text)

        emit("result", " ".join(full_text))

    except Exception as exc:  # noqa: BLE001
        emit("error", str(exc))


if __name__ == "__main__":
    main()
