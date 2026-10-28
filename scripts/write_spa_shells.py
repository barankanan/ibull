#!/usr/bin/env python3
"""Write a neutral Flutter boot shell for known client routes.

Home keeps build/web/index.html. Prerendered public pages are left untouched.
Known app routes get a copy of the boot document without the home merchandising
block. Unknown URLs are not given a shell, so Firebase can return 404.html.
"""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

# Exact client routes. Dynamic tails stay as firebase.json globs.
PRIVATE = [
    "/favoriler",
    "/sepet",
    "/hesabim",
    "/hesabim/siparisler",
    "/hesabim/kiralamalar",
    "/hesabim/favoriler",
    "/hesabim/kuponlar",
    "/hesabim/takip-ettiklerim",
    "/hesabim/adresler",
    "/hesabim/kartlar",
    "/hesabim/degerlendirmeler",
    "/hesabim/musteri-hizmetleri",
    "/hesabim/ayarlar",
    "/hesabim/bildirim-ayarlari",
    "/hesabim/guvenlik",
    "/hesabim/yapay-zeka",
    "/hesabim/avm-basvurusu",
    "/login",
    "/register",
    "/seller-login",
    "/seller",
    "/seller-forgot-password",
    "/admin",
    "/qr",
    "/visual-search",
    "/visual-search/analyze",
    "/visual-search/match",
    "/visual-search/history",
    "/blog/yazar",
    "/avm/giris",
    "/avm/kayit",
    "/avm/basvuru",
    "/avm-basvurusu",
    "/avm/yonetim",
    "/avm-yonetim",
    "/home",
]
PUBLIC = {
    "/map": "İBUL Harita | Yakındaki Mağazalar",
    "/arac": "Araçlar | İBUL",
    "/arac/arama": "Araç Arama | İBUL",
    "/avm": "AVM | İBUL",
    "/ihiz": "İHIZ | İBUL",
    "/yatirimci": "Yatırımcı | İBUL",
    "/gizlilik": "Gizlilik | İBUL",
    "/kullanim": "Kullanım Koşulları | İBUL",
    "/kvkk": "KVKK | İBUL",
    "/hakkimizda": "Hakkımızda | İBUL",
    "/iletisim": "İletişim | İBUL",
    "/sss": "Sıkça Sorulan Sorular | İBUL",
    "/iade": "İade | İBUL",
    "/guvenli-alisveris": "Güvenli Alışveriş | İBUL",
    "/kariyer": "Kariyer | İBUL",
    "/basin": "Basın | İBUL",
    "/reklam-ver": "Reklam | İBUL",
    "/api-entegrasyonu": "API | İBUL",
    "/is-birlikleri": "İş Birlikleri | İBUL",
    "/destek": "Destek | İBUL",
    "/kargo-takibi": "Kargo Takibi | İBUL",
    "/become-seller": "Satıcı Başvurusu | İBUL",
}
PRIVATE_TITLES = {
    "/favoriler": "Favorilerim | İBUL",
    "/sepet": "Sepetim | İBUL",
    "/hesabim": "Hesabım | İBUL",
    "/map": "İBUL Harita | Yakındaki Mağazalar",
}


def neutralize(html: str, title: str, canonical: str, noindex: bool) -> str:
    description = "İBUL açılıyor."
    html = re.sub(r"<title>[^<]*</title>", f"<title>{title}</title>", html, count=1)
    html = re.sub(
        r'(<meta name="description" content=")[^"]*(")',
        rf"\1{description}\2",
        html,
        count=1,
    )
    html = re.sub(
        r'(<meta property="og:title" content=")[^"]*(")',
        rf"\1{title}\2",
        html,
        count=1,
    )
    html = re.sub(
        r'(<meta property="og:description" content=")[^"]*(")',
        rf"\1{description}\2",
        html,
        count=1,
    )
    html = re.sub(
        r'(<meta name="twitter:title" content=")[^"]*(")',
        rf"\1{title}\2",
        html,
        count=1,
    )
    html = re.sub(
        r'(<meta name="twitter:description" content=")[^"]*(")',
        rf"\1{description}\2",
        html,
        count=1,
    )
    html = re.sub(
        r'(<meta property="og:url" content=")[^"]*(")',
        rf"\1{canonical}\2",
        html,
        count=1,
    )
    robots = "noindex, nofollow" if noindex else "index, follow"
    html = re.sub(
        r'(<meta name="robots" content=")[^"]*(")',
        rf"\1{robots}\2",
        html,
        count=1,
    )
    html = re.sub(
        r'<link rel="canonical" href="[^"]*">',
        f'<link rel="canonical" href="{canonical}">',
        html,
        count=1,
    )
    html = re.sub(
        r'<script type="application/ld\+json">[\s\S]*?</script>\s*',
        "",
        html,
        count=1,
    )
    html = re.sub(r'\s*<nav class="ibul-cats"[\s\S]*?</nav>', "", html, count=1)
    html = re.sub(
        r'<div id="ibul-loader-text">[\s\S]*?</div>',
        '<div id="ibul-loader-text">İBUL açılıyor</div>',
        html,
        count=1,
    )
    return html


def write_route(web: Path, route: str, html: str) -> str:
    dest = web.joinpath(*route.strip("/").split("/")) / "index.html"
    if dest.exists():
        existing = dest.read_text(encoding="utf-8")
        if 'id="ibul-prerender"' in existing or "<article>" in existing:
            return "skip"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(html, encoding="utf-8")
    return "write"


def main() -> int:
    web = Path(sys.argv[1])
    source = web / "index.html"
    template = source.read_text(encoding="utf-8")
    generic = neutralize(template, "İBUL", "https://ibul.com.tr/", True)
    (web / "app-shell.html").write_text(generic, encoding="utf-8")
    repo_web = Path(__file__).resolve().parents[1] / "ibul_app" / "web" / "404.html"
    if repo_web.is_file():
        shutil.copyfile(repo_web, web / "404.html")
    written = skipped = 0
    for route in PRIVATE:
        title = PRIVATE_TITLES.get(route, "İBUL")
        status = write_route(
            web,
            route,
            neutralize(template, title, f"https://ibul.com.tr{route}", True),
        )
        written += status == "write"
        skipped += status == "skip"
    for route, title in PUBLIC.items():
        status = write_route(
            web,
            route,
            neutralize(template, title, f"https://ibul.com.tr{route}", False),
        )
        written += status == "write"
        skipped += status == "skip"
    print(f"write_spa_shells: wrote {written}, skipped {skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
