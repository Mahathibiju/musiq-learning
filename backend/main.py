from __future__ import annotations

import ipaddress
import os
import re
import uuid
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from pydantic import BaseModel
from fastapi.staticfiles import StaticFiles

from services.pitch_analysis import PitchAnalysisError, analyze_vocal_pitch
from services.separation import SeparationError, separate_audio
from services.lyrics_transcription import LyricsTranscriptionError, transcribe_vocal_lyrics


BACKEND_DIR = Path(__file__).resolve().parent
UPLOADS_DIR = BACKEND_DIR / "uploads"
SEPARATED_DIR = BACKEND_DIR / "separated"
MAX_UPLOAD_BYTES = int(os.environ.get("MUSIQ_MAX_UPLOAD_BYTES", 500 * 1024 * 1024))
SEPARATION_TIMEOUT_SECONDS = int(
    os.environ.get("MUSIQ_SEPARATION_TIMEOUT_SECONDS", 6 * 60 * 60)
)
ALLOWED_AUDIO_EXTENSIONS = {
    ".aac",
    ".flac",
    ".m4a",
    ".mp3",
    ".ogg",
    ".opus",
    ".wav",
}

UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
SEPARATED_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Musiq Learning Audio Processing Backend")
app.mount("/files", StaticFiles(directory=SEPARATED_DIR), name="files")


class VocalAnalysisRequest(BaseModel):
    vocal_url: str


class VocalLyricsRequest(BaseModel):
    vocal_url: str


@app.get("/")
def health_check() -> dict[str, str]:
    return {"status": "Musiq processing backend is running"}


@app.post("/separate")
def separate_song(request: Request, file: UploadFile = File(...)) -> dict[str, object]:
    extension = Path(file.filename or "").suffix.lower()
    if extension not in ALLOWED_AUDIO_EXTENSIONS:
        raise HTTPException(
            status_code=415,
            detail=(
                "Unsupported audio file type. Use WAV, MP3, M4A, AAC, FLAC, "
                "OGG, or OPUS."
            ),
        )

    lan_ip = _request_lan_ip(request)
    port = request.url.port or int(os.environ.get("PORT", "8000"))
    public_base_url = f"{request.url.scheme}://{lan_ip}:{port}"
    upload_id = uuid.uuid4().hex
    input_path = UPLOADS_DIR / f"upload_{upload_id}{extension}"

    try:
        _save_upload(file, input_path)
        vocal_path, instrumental_path = separate_audio(
            input_path,
            UPLOADS_DIR,
            SEPARATED_DIR,
            timeout_seconds=SEPARATION_TIMEOUT_SECONDS,
        )
    except HTTPException:
        raise
    except (SeparationError, OSError) as error:
        raise HTTPException(status_code=500, detail=str(error)) from error
    except Exception as error:  # Preserve an actionable server-side failure.
        raise HTTPException(
            status_code=500,
            detail=f"Audio separation failed: {error}",
        ) from error
    finally:
        input_path.unlink(missing_ok=True)
        file.file.close()

    return {
        "success": True,
        "vocal_url": f"{public_base_url}/files/{quote(vocal_path.name)}",
        "instrumental_url": f"{public_base_url}/files/{quote(instrumental_path.name)}",
    }


@app.post("/analyze-vocal")
def analyze_vocal(request: VocalAnalysisRequest) -> dict[str, object]:
    filename = Path(unquote(urlsplit(request.vocal_url).path)).name
    if not re.fullmatch(r"[0-9a-f]{32}_vocals\.mp3", filename):
        raise HTTPException(
            status_code=400,
            detail="Analysis accepts only a generated Demucs vocal stem URL.",
        )

    vocal_path = (SEPARATED_DIR / filename).resolve()
    if vocal_path.parent != SEPARATED_DIR.resolve():
        raise HTTPException(status_code=400, detail="Invalid vocal stem URL.")
    if not vocal_path.is_file() or vocal_path.stat().st_size == 0:
        raise HTTPException(status_code=404, detail="The vocal stem file was not found.")

    try:
        duration, pitch_points = analyze_vocal_pitch(vocal_path)
    except PitchAnalysisError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Vocal pitch analysis failed: {error}",
        ) from error

    return {
        "success": True,
        "duration": duration,
        "pitch_points": pitch_points,
    }


@app.post("/transcribe-vocal")
def transcribe_vocal(request: VocalLyricsRequest) -> dict[str, object]:
    """Transcribe timestamped lyrics from a generated vocal stem only."""
    filename = Path(unquote(urlsplit(request.vocal_url).path)).name
    if not re.fullmatch(r"[0-9a-f]{32}_vocals\.mp3", filename):
        raise HTTPException(
            status_code=400,
            detail="Transcription accepts only a generated Demucs vocal stem URL.",
        )
    vocal_path = (SEPARATED_DIR / filename).resolve()
    if vocal_path.parent != SEPARATED_DIR.resolve():
        raise HTTPException(status_code=400, detail="Invalid vocal stem URL.")
    if not vocal_path.is_file() or vocal_path.stat().st_size == 0:
        raise HTTPException(status_code=404, detail="The vocal stem file was not found.")
    try:
        lyrics, cache_hit = transcribe_vocal_lyrics(vocal_path, BACKEND_DIR / "lyrics_cache")
    except LyricsTranscriptionError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=500, detail=f"Vocal transcription failed: {error}") from error
    return {"success": True, "cached": cache_hit, "lyrics": lyrics}


def _save_upload(upload: UploadFile, destination: Path) -> None:
    total_bytes = 0
    with destination.open("wb") as output:
        while chunk := upload.file.read(1024 * 1024):
            total_bytes += len(chunk)
            if total_bytes > MAX_UPLOAD_BYTES:
                destination.unlink(missing_ok=True)
                raise HTTPException(
                    status_code=413,
                    detail=(
                        f"The uploaded song exceeds the configured limit of "
                        f"{MAX_UPLOAD_BYTES // (1024 * 1024)} MB."
                    ),
                )
            output.write(chunk)
    if total_bytes == 0:
        destination.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="The uploaded audio file is empty.")


def _request_lan_ip(request: Request) -> str:
    host = request.url.hostname
    try:
        address = ipaddress.ip_address(host or "")
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=(
                "Call /separate using the Mac's LAN IP address, not a hostname, "
                "localhost, or 127.0.0.1."
            ),
        ) from error
    if address.is_loopback or not address.is_private:
        raise HTTPException(
            status_code=400,
            detail=(
                "Call /separate using the Mac's private LAN IP address, not "
                "localhost or 127.0.0.1."
            ),
        )
    return str(address)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=os.environ.get("HOST", "0.0.0.0"),
        port=int(os.environ.get("PORT", "8000")),
        reload=False,
    )
