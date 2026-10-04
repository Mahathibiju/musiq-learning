from __future__ import annotations

import hashlib
import json
import os
from functools import lru_cache
from pathlib import Path
from threading import Lock


class LyricsTranscriptionError(RuntimeError):
    pass


_model_lock = Lock()
_transcription_lock = Lock()


@lru_cache(maxsize=1)
def _get_model():
    try:
        from faster_whisper import WhisperModel
    except ImportError as error:
        raise LyricsTranscriptionError(
            "The transcription engine is not installed. Run pip install -r backend/requirements.txt."
        ) from error
    model_name = os.environ.get("MUSIQ_WHISPER_MODEL", "small")
    try:
        with _model_lock:
            return WhisperModel(
                model_name,
                device=os.environ.get("MUSIQ_WHISPER_DEVICE", "cpu"),
                compute_type=os.environ.get("MUSIQ_WHISPER_COMPUTE_TYPE", "int8"),
                cpu_threads=int(os.environ.get("MUSIQ_WHISPER_CPU_THREADS", "4")),
            )
    except Exception as error:
        raise LyricsTranscriptionError(
            f"Could not load Whisper model '{model_name}'. Check network access for its first download: {error}"
        ) from error


def transcribe_vocal_lyrics(
    vocal_path: Path, cache_dir: Path
) -> tuple[list[dict[str, object]], bool]:
    """Run multilingual Whisper on the isolated vocal stem and cache timed segments."""
    if not vocal_path.is_file() or vocal_path.stat().st_size == 0:
        raise LyricsTranscriptionError("The separated vocal stem is missing or empty.")
    cache_dir.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with vocal_path.open("rb") as audio:
        for chunk in iter(lambda: audio.read(1024 * 1024), b""):
            digest.update(chunk)
    model_name = os.environ.get("MUSIQ_WHISPER_MODEL", "small")
    cache_file = cache_dir / f"{digest.hexdigest()}_{model_name}.json"
    if cache_file.is_file():
        try:
            stored = json.loads(cache_file.read_text(encoding="utf-8"))
            if isinstance(stored, list):
                return stored, True
        except (OSError, json.JSONDecodeError):
            cache_file.unlink(missing_ok=True)

    # faster-whisper models can use native threads; serializing calls avoids
    # multiple simultaneous uploads exhausting memory on a development Mac.
    with _transcription_lock:
        if cache_file.is_file():
            stored = json.loads(cache_file.read_text(encoding="utf-8"))
            if isinstance(stored, list):
                return stored, True
        try:
            model = _get_model()
            segments, _info = model.transcribe(
                str(vocal_path),
                task="transcribe",
                language=None,
                beam_size=5,
                vad_filter=True,
                condition_on_previous_text=True,
            )
            result: list[dict[str, object]] = []
            for segment in segments:
                text = segment.text.strip()
                no_speech = getattr(segment, "no_speech_prob", 0.0)
                if not text or no_speech > 0.65:
                    continue
                start = max(0.0, float(segment.start))
                end = max(start, float(segment.end))
                if end > start:
                    result.append({"start": start, "end": end, "text": text})
        except LyricsTranscriptionError:
            raise
        except Exception as error:
            raise LyricsTranscriptionError(f"Whisper transcription failed: {error}") from error
        temporary = cache_file.with_suffix(".tmp")
        temporary.write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
        temporary.replace(cache_file)
        return result, False
