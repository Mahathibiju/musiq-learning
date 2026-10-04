from __future__ import annotations

import os
from pathlib import Path
import tempfile

_numba_cache_dir = os.environ.get("NUMBA_CACHE_DIR") or str(
    Path(tempfile.gettempdir()) / "musiq_learning_numba_cache"
)
os.environ["NUMBA_CACHE_DIR"] = _numba_cache_dir
Path(_numba_cache_dir).mkdir(parents=True, exist_ok=True)

import librosa
import numpy as np


SAMPLE_RATE = 22050
FRAME_LENGTH = 2048
HOP_LENGTH = 1024
MINIMUM_FREQUENCY_HZ = 65.0
MAXIMUM_FREQUENCY_HZ = 1000.0
MINIMUM_VOICED_CONFIDENCE = 0.60


class PitchAnalysisError(RuntimeError):
    """Raised when a vocal stem cannot be decoded or analyzed."""


def analyze_vocal_pitch(vocal_path: Path) -> tuple[float, list[dict[str, float]]]:
    """Extract real pYIN F0 estimates and voicing confidence from one vocal stem."""
    try:
        audio, sample_rate = librosa.load(
            str(vocal_path),
            sr=SAMPLE_RATE,
            mono=True,
        )
    except Exception as error:
        raise PitchAnalysisError(
            f"Could not decode the separated vocal stem: {error}"
        ) from error

    if audio.size == 0:
        raise PitchAnalysisError("The separated vocal stem contains no audio samples.")

    try:
        frequencies, voiced, voiced_probabilities = librosa.pyin(
            audio,
            fmin=MINIMUM_FREQUENCY_HZ,
            fmax=MAXIMUM_FREQUENCY_HZ,
            sr=sample_rate,
            frame_length=FRAME_LENGTH,
            hop_length=HOP_LENGTH,
            n_thresholds=50,
        )
    except Exception as error:
        raise PitchAnalysisError(f"pYIN pitch extraction failed: {error}") from error

    times = librosa.times_like(
        frequencies,
        sr=sample_rate,
        hop_length=HOP_LENGTH,
    )
    points: list[dict[str, float]] = []
    for timestamp, frequency, is_voiced, confidence in zip(
        times,
        frequencies,
        voiced,
        voiced_probabilities,
        strict=True,
    ):
        if (
            not is_voiced
            or not np.isfinite(frequency)
            or not np.isfinite(confidence)
            or confidence < MINIMUM_VOICED_CONFIDENCE
        ):
            continue
        points.append(
            {
                "time": round(float(timestamp), 3),
                "frequency": round(float(frequency), 2),
                "confidence": round(float(confidence), 3),
            }
        )

    duration = float(audio.size / sample_rate)
    return round(duration, 3), points
