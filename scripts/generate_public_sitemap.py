#!/usr/bin/env python3
"""Write https://ibul.com.tr/sitemap.xml from public catalog data.

Static public routes are always included. Products, categories, stores, malls
and blog posts are added when IBUL_SUPABASE_URL and IBUL_SUPABASE_ANON_KEY
are set, or when --fixture supplies the same public rows. Account, cart,
checkout, admin and drafts are omitted.

More than 50,000 URLs become a sitemap index plus sitemap-part-N.xml files.
The script exits 0 when the network is unavailable so a web build still ships
the static sitemap copied from web/sitemap.xml.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ORIGIN = "https://ibul.com.tr"
PAGE = 1000
INDEX_LIMIT = 50000
ACTIVE = {"aktif", "active"}
APPROVED = {"approved", "onaylandi", "onaylandı", "onayli", "onaylı"}
BLOCKED = {
    "pending", "pending_review", "pending_approval", "bekleniyor",
    "onay bekliyor", "rejected", "reddedildi", "draft", "taslak",
    "passive", "pasif", "inactive", "cancelled", "deleted",
}
STATIC = ["/", "/blog", "/map", "/avm", "/arac", "/ihiz", "/yatirimci"]


def esc(value) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def slugify(raw: str) -> str:
    lowered = (raw or "").strip().lower()
    table = str.maketrans("ığüşöçâîû", "igusocaiu")
    lowered = lowered.translate(table)
    out = []
    for char in lowered:
        if char.isascii() and char.isalnum():
            out.append(char)
        elif out and out[-1] != "-":
            out.append("-")
    return "".join(out).strip("-")


def token(value) -> str:
    return (str(value or "").strip().lower()
            .replace("ı", "i").replace("ğ", "g").replace("ü", "u")
            .replace("ş", "s").replace("ö", "o").replace("ç", "c"))


def public_product(row: dict) -> bool:
    status = token(row.get("status"))
    if status in BLOCKED or status not in ACTIVE:
        return False
    has_approval = "approval_status" in row or "admin_approval_status" in row
    if not has_approval:
        return True
    for key in ("approval_status", "admin_approval_status"):
        approved = token(row.get(key))
        if approved and approved not in BLOCKED and approved in APPROVED:
            return True
    return False


def urlset(urls: list[str]) -> str:
    body = "".join(f"<url><loc>{esc(url)}</loc></url>" for url in urls)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        f"{body}</urlset>\n"
    )


def sitemap_index(parts: list[str]) -> str:
    body = "".join(f"<sitemap><loc>{esc(url)}</loc></sitemap>" for url in parts)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        f"{body}</sitemapindex>\n"
    )


def absolute(path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        return path
    if not path.startswith("/"):
        path = f"/{path}"
    return ORIGIN if path == "/" else f"{ORIGIN}{path}"


def catalog_paths(data: dict) -> list[str]:
    paths = list(STATIC)
    for row in data.get("products") or []:
        if not isinstance(row, dict) or not public_product(row):
            continue
        product_id = str(row.get("id") or "").strip()
        name = str(row.get("name") or "").strip()
        if not product_id or not name:
            continue
        slug = slugify(name)
        paths.append(f"/urun/{urllib.parse.quote(product_id)}/{slug}" if slug else f"/urun/{urllib.parse.quote(product_id)}")
    categories = {
        str(row.get("id")): row
        for row in (data.get("categories") or [])
        if isinstance(row, dict) and row.get("is_active", True) is not False
    }
    for row in categories.values():
        parent = row.get("parent_id")
        if parent is None or str(parent) not in categories:
            continue
        name = str(row.get("name") or "").strip()
        slug = slugify(name)
        if not name or not slug:
            continue
        paths.append(f"/kategori/{parent}/{row.get('id')}/{slug}")
    for row in data.get("stores") or []:
        if not isinstance(row, dict):
            continue
        if row.get("is_deletion_requested") is True:
            continue
        store_id = str(row.get("seller_id") or row.get("id") or "").strip()
        name = str(row.get("business_name") or row.get("name") or "").strip()
        if not store_id or not name:
            continue
        slug = slugify(name)
        paths.append(f"/magaza/{urllib.parse.quote(store_id)}/{slug}" if slug else f"/magaza/{urllib.parse.quote(store_id)}")
    for row in data.get("malls") or []:
        if not isinstance(row, dict):
            continue
        mall_id = str(row.get("id") or "").strip()
        if mall_id:
            paths.append(f"/avm/profil/{urllib.parse.quote(mall_id)}")
    for row in data.get("posts") or []:
        if not isinstance(row, dict):
            continue
        slug = str(row.get("slug") or "").strip()
        if slug:
            paths.append(f"/blog/{slug}")
    seen, unique = set(), []
    for path in paths:
        url = absolute(path)
        if url not in seen:
            seen.add(url)
            unique.append(url)
    return unique


def write_sitemaps(web: Path, urls: list[str]) -> None:
    if len(urls) <= INDEX_LIMIT:
        (web / "sitemap.xml").write_text(urlset(urls), encoding="utf-8")
        return
    parts = []
    for index, start in enumerate(range(0, len(urls), INDEX_LIMIT), start=1):
        name = f"sitemap-part-{index}.xml"
        chunk = urls[start:start + INDEX_LIMIT]
        (web / name).write_text(urlset(chunk), encoding="utf-8")
        parts.append(f"{ORIGIN}/{name}")
    (web / "sitemap.xml").write_text(sitemap_index(parts), encoding="utf-8")


def _set_meta(page: str, name: str, content: str, prop: bool = False) -> str:
    attr = "property" if prop else "name"
    pattern = re.compile(rf'<meta {attr}="{re.escape(name)}" content="[^"]*">')
    tag = f'<meta {attr}="{name}" content="{esc(content)}">'
    if pattern.search(page):
        return pattern.sub(tag, page, count=1)
    return page.replace("</head>", f"  {tag}\n</head>", 1)


def _inject(page: str, title: str, description: str, canonical: str, body: str, jsonld: dict | None) -> str:
    page = re.sub(r"<title>[^<]*</title>", f"<title>{esc(title)}</title>", page, count=1)
    page = _set_meta(page, "description", description)
    page = _set_meta(page, "og:title", title, prop=True)
    page = _set_meta(page, "og:description", description, prop=True)
    page = _set_meta(page, "og:url", canonical, prop=True)
    if 'rel="canonical"' in page:
        page = re.sub(
            r'<link rel="canonical" href="[^"]*">',
            f'<link rel="canonical" href="{esc(canonical)}">',
            page,
            count=1,
        )
    else:
        page = page.replace("</head>", f'  <link rel="canonical" href="{esc(canonical)}">\n</head>', 1)
    if jsonld is not None:
        blob = json.dumps(jsonld, ensure_ascii=False).replace("</", "<\\/")
        page = page.replace("</head>", f'  <script type="application/ld+json">{blob}</script>\n</head>', 1)
    match = re.search(r'<div id="ibul-loader-text">[\s\S]*?</div>', page)
    if match is None:
        return page
    return page[:match.start()] + f"<main>{body}</main>\n    " + page[match.start():]


def product_jsonld(row: dict, canonical: str) -> dict:
    price = row.get("discount_price")
    if price in (None, "", 0):
        price = row.get("price")
    try:
        amount = float(price)
    except (TypeError, ValueError):
        amount = 0
    image = str(row.get("image_url") or "").strip()
    stock = row.get("stock")
    offer = {"@type": "Offer", "url": canonical, "priceCurrency": "TRY"}
    if amount > 0:
        offer["price"] = f"{amount:.2f}"
    if isinstance(stock, int) and not isinstance(stock, bool):
        offer["availability"] = (
            "https://schema.org/InStock" if stock > 0 else "https://schema.org/OutOfStock"
        )
    data = {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": row.get("name"),
        "url": canonical,
        "offers": offer,
    }
    description = str(row.get("description") or "").strip()
    if description:
        data["description"] = description[:160]
    brand = str(row.get("brand") or "").strip()
    if brand:
        data["brand"] = {"@type": "Brand", "name": brand}
    if image.startswith("http://") or image.startswith("https://"):
        data["image"] = [image]
    return data


def prerender_products(web: Path, products: list[dict]) -> None:
    template_path = web / "index.html"
    if not template_path.is_file():
        return
    template = template_path.read_text(encoding="utf-8")
    if 'id="ibul-loader-text"' not in template:
        return
    count = 0
    for row in products:
        if not public_product(row):
            continue
        product_id = str(row.get("id") or "").strip()
        name = str(row.get("name") or "").strip()
        if not product_id or not name:
            continue
        slug = slugify(name)
        path = f"/urun/{urllib.parse.quote(product_id)}/{slug}" if slug else f"/urun/{urllib.parse.quote(product_id)}"
        canonical = absolute(path)
        description = str(row.get("description") or name).strip() or name
        image = str(row.get("image_url") or "").strip()
        price = row.get("discount_price")
        if price in (None, "", 0):
            price = row.get("price") or ""
        body = (
            f"<article><nav>İBUL</nav><h1>{esc(name)}</h1>"
            f"<p>{esc(description)}</p>"
            f"<p>{esc(price)} TRY</p>"
            + (f'<img src="{esc(image)}" alt="{esc(name)}">' if image.startswith("http") else "")
            + f'<p><a href="{esc(path)}">{esc(name)}</a></p></article>'
        )
        page = _inject(
            template,
            f"{name} | İBUL",
            description[:160],
            canonical,
            body,
            product_jsonld(row, canonical),
        )
        target = web / "urun" / product_id
        if slug:
            target = target / slug
        target.mkdir(parents=True, exist_ok=True)
        (target / "index.html").write_text(page, encoding="utf-8")
        count += 1
    if count:
        print(f"generate_public_sitemap: prerendered {count} product pages")


def _write_page(web: Path, rel: str, html_text: str) -> None:
    target = web.joinpath(*rel.strip("/").split("/"))
    target.mkdir(parents=True, exist_ok=True)
    (target / "index.html").write_text(html_text, encoding="utf-8")


def prerender_catalog_pages(web: Path, data: dict) -> None:
    template_path = web / "index.html"
    if not template_path.is_file():
        return
    template = template_path.read_text(encoding="utf-8")
    categories = {
        str(row.get("id")): row
        for row in (data.get("categories") or [])
        if isinstance(row, dict) and row.get("is_active", True) is not False
    }
    written = 0
    for row in categories.values():
        parent = row.get("parent_id")
        if parent is None or str(parent) not in categories:
            continue
        name = str(row.get("name") or "").strip()
        slug = slugify(name)
        if not name or not slug:
            continue
        path = f"/kategori/{parent}/{row.get('id')}/{slug}"
        canonical = absolute(path)
        parent_name = str(categories[str(parent)].get("name") or "Kategori")
        body = f"<nav>İBUL / {esc(parent_name)}</nav><h1>{esc(name)} Ürünleri</h1><p>{esc(name)} kategorisindeki ürünler.</p>"
        _write_page(web, path, _inject(
            template, f"{name} Ürünleri | İBUL", f"{name} kategorisindeki ürünler.", canonical, body,
            {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
                {"@type": "ListItem", "position": 1, "name": "İBUL", "item": absolute("/")},
                {"@type": "ListItem", "position": 2, "name": parent_name, "item": absolute("/")},
                {"@type": "ListItem", "position": 3, "name": name, "item": canonical},
            ]},
        ))
        written += 1
    for row in data.get("stores") or []:
        if not isinstance(row, dict) or row.get("is_deletion_requested") is True:
            continue
        store_id = str(row.get("seller_id") or "").strip()
        name = str(row.get("business_name") or "").strip()
        slug = slugify(name)
        if not store_id or not name:
            continue
        path = f"/magaza/{urllib.parse.quote(store_id)}/{slug}" if slug else f"/magaza/{urllib.parse.quote(store_id)}"
        canonical = absolute(path)
        body = f"<nav>İBUL</nav><h1>{esc(name)} Mağazası</h1><p>{esc(name)} mağazasının ürünleri ve bilgileri.</p>"
        _write_page(web, path, _inject(
            template, f"{name} Mağazası | İBUL", f"{name} mağazasının ürünleri ve bilgileri.", canonical, body,
            {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
                {"@type": "ListItem", "position": 1, "name": "İBUL", "item": absolute("/")},
                {"@type": "ListItem", "position": 2, "name": name, "item": canonical},
            ]},
        ))
        written += 1
    for row in data.get("malls") or []:
        if not isinstance(row, dict):
            continue
        mall_id = str(row.get("id") or "").strip()
        name = str(row.get("name") or "AVM").strip()
        if not mall_id:
            continue
        path = f"/avm/profil/{urllib.parse.quote(mall_id)}"
        canonical = absolute(path)
        body = f"<nav>İBUL</nav><h1>{esc(name)} Mağazaları ve Bilgileri</h1><p>{esc(name)}</p>"
        _write_page(web, path, _inject(
            template, f"{name} Mağazaları ve Bilgileri | İBUL", f"{name} mağazaları ve bilgileri.", canonical, body,
            {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
                {"@type": "ListItem", "position": 1, "name": "İBUL", "item": absolute("/")},
                {"@type": "ListItem", "position": 2, "name": name, "item": canonical},
            ]},
        ))
        written += 1
    print(f"generate_public_sitemap: prerendered {written} category/store/mall pages")


class Live:
    def __init__(self, url: str, key: str) -> None:
        self.url, self.key = url.rstrip("/"), key

    def get(self, path: str, params: dict | None = None) -> list:
        query = urllib.parse.urlencode(params or {}, safe="(),.*")
        request = urllib.request.Request(
            f"{self.url}{path}?{query}",
            headers={"apikey": self.key, "Authorization": f"Bearer {self.key}"},
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode())
        return payload if isinstance(payload, list) else []

    def rpc(self, name: str, params: dict | None = None):
        request = urllib.request.Request(
            f"{self.url}/rest/v1/rpc/{name}",
            data=json.dumps(params or {}).encode(),
            headers={
                "apikey": self.key,
                "Authorization": f"Bearer {self.key}",
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode() or "null")


def load_live() -> dict:
    url, key = os.environ.get("IBUL_SUPABASE_URL"), os.environ.get("IBUL_SUPABASE_ANON_KEY")
    if not url or not key:
        print("generate_public_sitemap: Supabase env yok, statik sitemap yazıldı.")
        return {}
    live = Live(url, key)
    data: dict = {"products": [], "categories": [], "stores": [], "malls": [], "posts": []}
    try:
        offset = 0
        while True:
            rows = live.get("/rest/v1/products", {
                "select": "id,name,description,brand,price,discount_price,stock,image_url,status,approval_status,admin_approval_status",
                "status": "in.(Aktif,active)",
                "limit": PAGE,
                "offset": offset,
            })
            data["products"].extend(rows)
            if len(rows) < PAGE:
                break
            offset += PAGE
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"generate_public_sitemap: products skipped ({error.__class__.__name__})")
    for key_name, path, select in (
        ("categories", "/rest/v1/categories", "id,name,parent_id,is_active"),
        ("stores", "/rest/v1/stores", "seller_id,business_name,is_deletion_requested"),
    ):
        try:
            data[key_name] = live.get(path, {"select": select, "limit": PAGE})
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            code = getattr(error, "code", "")
            print(f"generate_public_sitemap: {key_name} skipped ({error.__class__.__name__} {code})")
    try:
        pins = live.rpc("public_mall_map_pins")
        data["malls"] = pins if isinstance(pins, list) else []
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"generate_public_sitemap: malls skipped ({error.__class__.__name__})")
    try:
        offset = 0
        while True:
            page = live.rpc("blog_list_posts", {"p_limit": 48, "p_offset": offset})
            rows = page if isinstance(page, list) else (page or {}).get("posts") or []
            data["posts"].extend(rows)
            if len(rows) < 48:
                break
            offset += 48
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"generate_public_sitemap: blog skipped ({error.__class__.__name__})")
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("web")
    parser.add_argument("--fixture")
    args = parser.parse_args()
    web = Path(args.web)
    web.mkdir(parents=True, exist_ok=True)
    if args.fixture:
        data = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
    else:
        try:
            data = load_live()
        except Exception as error:
            print(f"generate_public_sitemap: live read failed ({error.__class__.__name__})")
            data = {}
    urls = catalog_paths(data)
    write_sitemaps(web, urls)
    prerender_products(web, data.get("products") or [])
    prerender_catalog_pages(web, data)
    print(f"generate_public_sitemap: {len(urls)} URLs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
