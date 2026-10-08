from __future__ import annotations

import hashlib
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


@dataclass(frozen=True, slots=True)
class ModelAsset:
    name: str
    size: int
    sha256: str = ""


MODEL_REVISION = "cca5a0e6c96e1d2c720986bf7e75fcc81dee3ae4"
MODEL_BASE = (
    "https://huggingface.co/csukuangfj2/"
    "sherpa-onnx-supertonic-3-tts-int8-2026-05-11/resolve/" + MODEL_REVISION
)
ASSETS = (
    ModelAsset("duration_predictor.int8.onnx", 3700147, "c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db"),
    ModelAsset("text_encoder.int8.onnx", 36416150, "c7befd5ea8c3119769e8a6c1486c4edc6a3bc8365c67621c881bbb774b9902ff"),
    ModelAsset("tts.json", 8448, ""),
    ModelAsset("unicode_indexer.bin", 262144, "8402ca48e5189a8950138580b0fff64db6f072f24ac07cd54ba8b2fbb9883b30"),
    ModelAsset("vector_estimator.int8.onnx", 78400833, "20cd86fa5c6effedfda0e7cffe5b0569ca401c440a0c3a1d72bf39286c0db3fd"),
    ModelAsset("vocoder.int8.onnx", 25991073, "e923d60f53f95eb1ce235f1dc33ec56d9c057823c96fa6f8acf98f32b0da6152"),
    ModelAsset("voice.bin", 517168, "67d5209b0ee8ce6c74105ffbe12fe6a7628aea3b4ba2fcb308a4a67938a93ce8"),
)


class SupertonicModelManager:
    def __init__(self, root: Path) -> None:
        self.directory = root / "supertonic3"

    def installed(self) -> bool:
        return all((self.directory / asset.name).is_file() and (self.directory / asset.name).stat().st_size > 0 for asset in ASSETS)

    def install(self, progress: Callable[[float, str], None] | None = None) -> None:
        self.directory.mkdir(parents=True, exist_ok=True)
        total = sum(x.size for x in ASSETS)
        completed = 0
        for index, asset in enumerate(ASSETS, 1):
            target = self.directory / asset.name
            if self._valid(target, asset):
                completed += asset.size
                continue
            partial = target.with_suffix(target.suffix + ".part")
            if partial.exists():
                partial.unlink()
            req = urllib.request.Request(f"{MODEL_BASE}/{asset.name}?download=true", headers={"User-Agent": "Auralis-Reader/3.0"})
            digest = hashlib.sha256()
            received = 0
            with urllib.request.urlopen(req, timeout=45) as response, partial.open("wb") as output:
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    output.write(block)
                    digest.update(block)
                    received += len(block)
                    if progress:
                        progress(min(0.98, (completed + received) / total), f"Baixando voz neural {index}/{len(ASSETS)}")
            if received != asset.size:
                partial.unlink(missing_ok=True)
                raise RuntimeError(f"Download incompleto: {asset.name}")
            if asset.sha256 and digest.hexdigest() != asset.sha256:
                partial.unlink(missing_ok=True)
                raise RuntimeError(f"Falha de integridade: {asset.name}")
            partial.replace(target)
            completed += asset.size
        if progress:
            progress(1.0, "Voz neural pronta")

    def _valid(self, path: Path, asset: ModelAsset) -> bool:
        if not path.is_file() or path.stat().st_size != asset.size:
            return False
        if not asset.sha256:
            return True
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        return digest == asset.sha256

    def config(self) -> dict[str, str]:
        return {asset.name: str(self.directory / asset.name) for asset in ASSETS}
