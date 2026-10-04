from __future__ import annotations

import shutil
import subprocess
import sys
import threading
import uuid
from pathlib import Path


MODEL_NAME = "htdemucs"
MP3_BITRATE = "192k"
ENCODING_TIMEOUT_SECONDS = 5 * 60
_separation_lock = threading.Lock()


class SeparationError(RuntimeError):
    """Raised when Demucs does not produce both expected audio stems."""


def separate_audio(
    input_path: Path,
    uploads_dir: Path,
    separated_dir: Path,
    *,
    timeout_seconds: int,
) -> tuple[Path, Path]:
    """Run real Demucs vocals-vs-accompaniment separation and persist outputs."""
    job_id = uuid.uuid4().hex
    work_dir = uploads_dir / f"demucs_{job_id}"
    work_dir.mkdir(parents=True, exist_ok=False)
    vocal_output = separated_dir / f"{job_id}_vocals.mp3"
    instrumental_output = separated_dir / f"{job_id}_instrumental.mp3"
    try:
        command = [
            sys.executable,
            "-m",
            "demucs",
            "--name",
            MODEL_NAME,
            "--two-stems",
            "vocals",
            "--device",
            "cpu",
            "--out",
            str(work_dir),
            str(input_path),
        ]
        # Demucs/PyTorch can use substantial memory. Serialize jobs on this
        # development server to avoid concurrent model runs exhausting the Mac.
        with _separation_lock:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout_seconds,
            )
        if result.returncode != 0:
            details = (result.stderr or result.stdout or "No Demucs output.").strip()
            raise SeparationError(
                f"Demucs exited with code {result.returncode}: {details[-5000:]}"
            )

        demucs_track_dir = work_dir / MODEL_NAME / input_path.stem
        vocal_source = demucs_track_dir / "vocals.wav"
        accompaniment_source = demucs_track_dir / "no_vocals.wav"
        if not _is_non_empty_file(vocal_source):
            raise SeparationError(
                f"Demucs completed but the vocal output was missing: {vocal_source}"
            )
        if not _is_non_empty_file(accompaniment_source):
            raise SeparationError(
                "Demucs completed but its no_vocals.wav accompaniment output "
                f"was missing: {accompaniment_source}"
            )

        _encode_mp3(vocal_source, vocal_output)
        _encode_mp3(accompaniment_source, instrumental_output)
        if not _is_non_empty_file(vocal_output) or not _is_non_empty_file(
            instrumental_output
        ):
            vocal_output.unlink(missing_ok=True)
            instrumental_output.unlink(missing_ok=True)
            raise SeparationError("One or both copied Demucs output files are empty.")
        return vocal_output, instrumental_output
    except subprocess.TimeoutExpired as error:
        raise SeparationError(
            f"Demucs exceeded its {timeout_seconds}-second processing timeout."
        ) from error
    except FileNotFoundError as error:
        raise SeparationError(
            "Could not start Demucs. Install the backend requirements in the active "
            "Python virtual environment."
        ) from error
    except Exception:
        vocal_output.unlink(missing_ok=True)
        instrumental_output.unlink(missing_ok=True)
        raise
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)


def _encode_mp3(source: Path, destination: Path) -> None:
    """Encode a real Demucs WAV stem to a compact MP3 on disk."""
    command = [
        "ffmpeg",
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(source),
        "-map",
        "0:a:0",
        "-vn",
        "-codec:a",
        "libmp3lame",
        "-b:a",
        MP3_BITRATE,
        "-ar",
        "44100",
        "-ac",
        "2",
        str(destination),
    ]
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=ENCODING_TIMEOUT_SECONDS,
        )
    except FileNotFoundError as error:
        raise SeparationError(
            "ffmpeg is required to compress the separated stems. Install it on the "
            "Mac with `brew install ffmpeg` and restart the backend."
        ) from error
    except subprocess.TimeoutExpired as error:
        raise SeparationError(
            f"Compressing {source.name} exceeded the "
            f"{ENCODING_TIMEOUT_SECONDS}-second timeout."
        ) from error

    if result.returncode != 0:
        destination.unlink(missing_ok=True)
        details = (result.stderr or result.stdout or "No ffmpeg output.").strip()
        raise SeparationError(
            f"Could not encode {source.name} as MP3: {details[-3000:]}"
        )


def _is_non_empty_file(path: Path) -> bool:
    return path.is_file() and path.stat().st_size > 0
