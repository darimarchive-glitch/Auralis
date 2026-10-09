from __future__ import annotations

import importlib.util
from dataclasses import dataclass
from typing import Callable, Protocol

from .db import LibraryDatabase
from .models import Book, TranslationOptions, TranslationResult
from .text import translation_chunks

LANGUAGE_NAMES = {
    "auto": "Detectar automaticamente",
    "pt": "Português",
    "en": "English",
    "es": "Español",
    "fr": "Français",
    "de": "Deutsch",
    "it": "Italiano",
    "ja": "日本語",
    "ko": "한국어",
    "zh": "中文",
    "ru": "Русский",
    "ar": "العربية",
    "hi": "हिन्दी",
    "la": "Latim",
    "el": "Ελληνικά",
}

MADLAD_LANGUAGE_TAGS = {
    "pt": "pt", "en": "en", "es": "es", "fr": "fr", "de": "de", "it": "it",
    "ja": "ja", "ko": "ko", "zh": "zh", "ru": "ru", "ar": "ar", "hi": "hi",
    "la": "la", "el": "el",
}


class TranslationProvider(Protocol):
    name: str

    def available(self) -> bool: ...
    def translate(self, text: str, source: str, target: str) -> str: ...


class ArgosProvider:
    name = "Argos Lite"

    def available(self) -> bool:
        return importlib.util.find_spec("argostranslate") is not None

    def translate(self, text: str, source: str, target: str) -> str:
        if source == "auto":
            raise RuntimeError("Argos precisa de um idioma de origem explícito.")
        try:
            import argostranslate.package
            import argostranslate.translate
        except ImportError as exc:
            raise RuntimeError("Instale o pacote opcional 'translation-lite'.") from exc

        installed = argostranslate.translate.get_installed_languages()
        source_lang = next((x for x in installed if x.code == source), None)
        target_lang = next((x for x in installed if x.code == target), None)
        if source_lang and target_lang:
            translation = source_lang.get_translation(target_lang)
            return translation.translate(text)

        argostranslate.package.update_package_index()
        packages = argostranslate.package.get_available_packages()
        package = next((p for p in packages if p.from_code == source and p.to_code == target), None)
        if package is None:
            raise RuntimeError(f"Não há pacote Argos direto de {source} para {target}.")
        argostranslate.package.install_from_path(package.download())
        installed = argostranslate.translate.get_installed_languages()
        source_lang = next(x for x in installed if x.code == source)
        target_lang = next(x for x in installed if x.code == target)
        return source_lang.get_translation(target_lang).translate(text)


class MadladProvider:
    """High-quality, local-only literary translation with an Apache-2.0 model."""

    name = "MADLAD-400 3B"
    model_id = "google/madlad400-3b-mt"

    def __init__(self) -> None:
        self._tokenizer = None
        self._model = None
        self._device = None

    def available(self) -> bool:
        return (
            importlib.util.find_spec("transformers") is not None
            and importlib.util.find_spec("torch") is not None
        )

    def _load(self) -> None:
        if self._model is not None:
            return
        try:
            import torch
            from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
        except ImportError as exc:
            raise RuntimeError("Instale o pacote opcional 'translation-ai'.") from exc
        self._tokenizer = AutoTokenizer.from_pretrained(self.model_id)
        dtype = torch.float16 if torch.cuda.is_available() else torch.float32
        self._model = AutoModelForSeq2SeqLM.from_pretrained(
            self.model_id,
            torch_dtype=dtype,
            low_cpu_mem_usage=True,
        )
        self._device = "cuda" if torch.cuda.is_available() else "cpu"
        self._model.to(self._device)
        self._model.eval()

    def translate(self, text: str, source: str, target: str) -> str:
        self._load()
        import torch
        target_tag = MADLAD_LANGUAGE_TAGS.get(target, target)
        prompt = f"<2{target_tag}> {text}"
        inputs = self._tokenizer(prompt, return_tensors="pt", truncation=True, max_length=1024)
        inputs = {key: value.to(self._device) for key, value in inputs.items()}
        with torch.inference_mode():
            output = self._model.generate(
                **inputs,
                max_new_tokens=1100,
                num_beams=4,
                repetition_penalty=1.05,
            )
        return self._tokenizer.decode(output[0], skip_special_tokens=True).strip()


class QwenLiteraryPostEditor:
    """Optional local second pass for archaic prose, tone and fluency.

    It never invents a translation from scratch: it receives both source and translated text and is
    instructed to preserve names, facts, omissions and paragraph structure.
    """

    model_id = "Qwen/Qwen3-4B-Instruct-2507"

    def __init__(self) -> None:
        self._tokenizer = None
        self._model = None
        self._device = None

    def available(self) -> bool:
        return (
            importlib.util.find_spec("transformers") is not None
            and importlib.util.find_spec("torch") is not None
        )

    def _load(self) -> None:
        if self._model is not None:
            return
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
        self._tokenizer = AutoTokenizer.from_pretrained(self.model_id)
        dtype = torch.float16 if torch.cuda.is_available() else torch.float32
        self._model = AutoModelForCausalLM.from_pretrained(
            self.model_id,
            torch_dtype=dtype,
            low_cpu_mem_usage=True,
        )
        self._device = "cuda" if torch.cuda.is_available() else "cpu"
        self._model.to(self._device)
        self._model.eval()

    def refine(self, source: str, translated: str, target: str, mode: str) -> str:
        self._load()
        import torch
        instructions = {
            "faithful": "Preserve o registro literário, a época, o ritmo e as ambiguidades do original.",
            "modern": "Use linguagem contemporânea natural, sem resumir, censurar ou alterar fatos.",
            "literal": "Faça o mínimo de reescrita; corrija apenas erros claros da tradução.",
            "study": "Preserve o texto e deixe termos historicamente importantes claros pelo contexto, sem notas extras.",
        }
        prompt = (
            f"Você é um editor literário profissional. Revise a tradução abaixo para {target}. "
            f"{instructions.get(mode, instructions['faithful'])} "
            "Não invente informação, não omita frases, preserve nomes próprios, diálogos, parágrafos e pontuação. "
            "Responda somente com o texto final.\n\n"
            f"ORIGINAL:\n{source}\n\nTRADUÇÃO BASE:\n{translated}"
        )
        messages = [{"role": "user", "content": prompt}]
        rendered = self._tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = self._tokenizer(rendered, return_tensors="pt", truncation=True, max_length=4096)
        inputs = {key: value.to(self._device) for key, value in inputs.items()}
        with torch.inference_mode():
            generated = self._model.generate(**inputs, max_new_tokens=2400, do_sample=False)
        new_tokens = generated[0][inputs["input_ids"].shape[1] :]
        return self._tokenizer.decode(new_tokens, skip_special_tokens=True).strip()


@dataclass(slots=True)
class TranslationProgress:
    chapter: int
    chapter_count: int
    chunk: int
    chunk_count: int
    message: str


class BookTranslationService:
    def __init__(self, db: LibraryDatabase) -> None:
        self.db = db
        self.madlad = MadladProvider()
        self.argos = ArgosProvider()
        self.post_editor = QwenLiteraryPostEditor()

    def choose_provider(self, quality: str) -> TranslationProvider:
        if quality in {"smart", "studio"} and self.madlad.available():
            return self.madlad
        if self.argos.available():
            return self.argos
        if self.madlad.available():
            return self.madlad
        raise RuntimeError(
            "Nenhum tradutor local está instalado. Instale 'translation-lite' para o modo leve "
            "ou 'translation-ai' para o modelo MADLAD-400."
        )

    def translate_text(self, text: str, options: TranslationOptions) -> TranslationResult:
        if options.source_language == options.target_language:
            return TranslationResult(text, "identity", options.source_language, options.target_language, options.literary_mode)
        provider = self.choose_provider(options.quality)
        translated_parts: list[str] = []
        for chunk in translation_chunks(text):
            translated = provider.translate(chunk, options.source_language, options.target_language)
            if options.post_edit and options.quality == "studio" and self.post_editor.available():
                translated = self.post_editor.refine(
                    chunk,
                    translated,
                    options.target_language,
                    options.literary_mode,
                )
            translated_parts.append(translated)
        return TranslationResult(
            "\n\n".join(translated_parts),
            provider.name,
            options.source_language,
            options.target_language,
            options.literary_mode,
        )

    def translate_book(
        self,
        book: Book,
        options: TranslationOptions,
        progress: Callable[[TranslationProgress], None] | None = None,
    ) -> list[str]:
        provider = self.choose_provider(options.quality)
        translated_chapters: list[str] = []
        for chapter_no, chapter in enumerate(book.chapters):
            cached = self.db.cached_translation(
                book_id=book.id,
                chapter_index=chapter.index,
                target_language=options.target_language,
                literary_mode=options.literary_mode,
                provider=provider.name,
                source_text=chapter.text,
            )
            if cached is not None:
                translated_chapters.append(cached)
                if progress:
                    progress(TranslationProgress(chapter_no + 1, len(book.chapters), 1, 1, "Capítulo em cache"))
                continue

            chunks = translation_chunks(chapter.text)
            translated_parts: list[str] = []
            for chunk_no, chunk in enumerate(chunks):
                if progress:
                    progress(
                        TranslationProgress(
                            chapter_no + 1,
                            len(book.chapters),
                            chunk_no + 1,
                            len(chunks),
                            f"Traduzindo capítulo {chapter_no + 1}/{len(book.chapters)}",
                        )
                    )
                translated = provider.translate(chunk, options.source_language, options.target_language)
                if options.post_edit and options.quality == "studio" and self.post_editor.available():
                    translated = self.post_editor.refine(
                        chunk,
                        translated,
                        options.target_language,
                        options.literary_mode,
                    )
                translated_parts.append(translated)
            translated_text = "\n\n".join(translated_parts)
            self.db.store_translation(
                book_id=book.id,
                chapter_index=chapter.index,
                target_language=options.target_language,
                literary_mode=options.literary_mode,
                provider=provider.name,
                source_text=chapter.text,
                translated_text=translated_text,
            )
            translated_chapters.append(translated_text)
        return translated_chapters
