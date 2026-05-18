from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Final

# Virtual / generic Windows queues that must not be shown as POS-ready.
_VIRTUAL_GENERIC_PATTERNS: Final[tuple[re.Pattern[str], ...]] = tuple(
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"\bfax\b",
        r"microsoft\s+print\s+to\s+pdf",
        r"\bpdf\b",
        r"onenote",
        r"\bxps\b",
        r"microsoft\s+xps",
        r"send\s+to\s+onenote",
        r"adobe\s+pdf",
        r"redirected",
        r"generic\s*/\s*text",
        r"generic\s+text\s+only",
        r"file\s+print",
    )
)

_GENERIC_TEXT_PATTERNS: Final[tuple[re.Pattern[str], ...]] = tuple(
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"generic\s*/\s*text",
        r"generic\s+text\s+only",
    )
)

_POS_CANDIDATE_PATTERNS: Final[tuple[re.Pattern[str], ...]] = tuple(
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"\bpos\b",
        r"pos-",
        r"pos58",
        r"pos80",
        r"thermal",
        r"receipt",
        r"escpos",
        r"esc/pos",
        r"\b58\b",
        r"\b80\b",
        r"xp-",
        r"zj-",
        r"gp-",
        r"tm-t",
        r"tm\s",
        r"star\s",
        r"epson\s+tm",
        r"stmicroelectronics",
    )
)


@dataclass(frozen=True)
class WindowsPrinterProfile:
    operator_tier: str
    warning_code: str | None
    is_pos_candidate: bool
    recommended: bool
    status_level: str
    status_message: str
    selection_warning: str | None = None

    def as_metadata(self) -> dict[str, object]:
        return {
            "operatorTier": self.operator_tier,
            "warningCode": self.warning_code,
            "isPosCandidate": self.is_pos_candidate,
            "recommended": self.recommended,
            "selectionWarning": self.selection_warning,
        }


def _matches_any(patterns: tuple[re.Pattern[str], ...], text: str) -> bool:
    return any(pattern.search(text) for pattern in patterns)


def classify_windows_printer(
    *,
    name: str,
    driver_name: str = "",
    port_name: str = "",
    base_status_level: str = "ready",
    base_status_message: str = "Yazıcı hazır.",
) -> WindowsPrinterProfile:
    haystack = " ".join(
        part.strip().lower()
        for part in (name, driver_name, port_name)
        if part and part.strip()
    )
    if not haystack:
        haystack = name.strip().lower()

    is_generic_text = _matches_any(_GENERIC_TEXT_PATTERNS, haystack)
    is_virtual_generic = _matches_any(_VIRTUAL_GENERIC_PATTERNS, haystack)
    is_pos_candidate = _matches_any(_POS_CANDIDATE_PATTERNS, haystack)

    if is_generic_text:
        return WindowsPrinterProfile(
            operator_tier="not_recommended",
            warning_code="generic_text_only",
            is_pos_candidate=False,
            recommended=False,
            status_level="warning",
            status_message=(
                "Bu hedef ESC/POS termal baskı için güvenilir değildir. "
                "Gerçek POS58 sürücüsü ve doğru USB portu kurulumu önerilir."
            ),
            selection_warning=(
                "Generic / Text Only seçildi: Windows sınama sayfası anlamsız "
                "spool metinleri basabilir. POS58 driver kurun."
            ),
        )

    if is_virtual_generic:
        label = name.strip() or "Yazıcı"
        return WindowsPrinterProfile(
            operator_tier="not_recommended",
            warning_code="not_recommended_target",
            is_pos_candidate=False,
            recommended=False,
            status_level="warning",
            status_message=(
                f"'{label}' sanal veya genel bir Windows hedefidir; "
                "adisyon/mutfak termal baskı için uygun değildir."
            ),
            selection_warning=(
                "Fax, PDF, XPS, OneNote veya Generic hedefleri termal fiş için kullanılamaz."
            ),
        )

    if is_pos_candidate:
        return WindowsPrinterProfile(
            operator_tier="pos_candidate",
            warning_code=None,
            is_pos_candidate=True,
            recommended=True,
            status_level=base_status_level if base_status_level in {"ready", "warning"} else "warning",
            status_message=base_status_message
            if base_status_level == "ready"
            else base_status_message,
            selection_warning=None,
        )

    # Normal office/inkjet queues: online in Windows ≠ ESC/POS verified.
    if base_status_level == "ready":
        return WindowsPrinterProfile(
            operator_tier="normal",
            warning_code="verify_with_test_print",
            is_pos_candidate=False,
            recommended=False,
            status_level="warning",
            status_message=(
                "Windows yazıcıyı çevrimiçi görüyor; termal/POS uyumluluğu için "
                "test fişi ile doğrulayın."
            ),
            selection_warning=None,
        )

    return WindowsPrinterProfile(
        operator_tier="normal",
        warning_code=None,
        is_pos_candidate=False,
        recommended=False,
        status_level=base_status_level,
        status_message=base_status_message,
        selection_warning=None,
    )


def windows_pos_setup_guide_steps() -> list[str]:
    return [
        "Windows Ayarlar > Yazıcılar > Yazdırma tercihleri > Windows korumalı yazdırma modunu kapatın.",
        "POS58 için üretici sürücüsünü kurun (Generic / Text Only yerine).",
        "Yazıcıyı USB001/USB002 yerine sürücünün gösterdiği doğru porta bağlayın.",
        "Windows sınama sayfası anlamsız kod/karakter basıyorsa sürücü veya port yanlıştır.",
        "Kurulumdan sonra uygulamada canlı taramayı yenileyin ve test fişi gönderin.",
    ]
