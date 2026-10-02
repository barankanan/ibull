#!/usr/bin/env python3
"""Write crawlable HTML for published blog posts into a Flutter web build.

Usage:
  prerender_blog.py <build/web dir> [--fixture data.json] [--origin https://ibul.com.tr]

Reads only public RPCs (anon key): blog_list_posts, blog_get_post,
blog_list_categories, blog_list_public_redirects. Drafts are never fetched.
Output (per deploy; unpublished posts disappear on the next build):
  blog/index.html, blog/<slug>/index.html, blog/<old-slug>/index.html (redirect),
  blog-sitemap.xml

The block → HTML mapping mirrors lib/features/blog/widgets/blog_block_view.dart
and the inline markup in lib/features/blog/models/blog_content.dart.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path

SAFE_URL = re.compile(r"^(https?://[^\s/]+|mailto:\S+|/([^/\s]|$))", re.I)
INLINE = re.compile(r"\*\*(.+?)\*\*|\*(.+?)\*|\[([^\]]+)\]\(([^)\s]+)\)")
YOUTUBE = re.compile(
    r"^https://(?:www\.|m\.)?(?:youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/)|youtu\.be/)([A-Za-z0-9_-]{11})"
)
VIMEO = re.compile(r"^https://(?:www\.|player\.)?vimeo\.com/(?:video/)?(\d{6,12})")
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
JSONLD_ID = "ibul-page-jsonld"


def esc(value) -> str:
    return html.escape(str(value or ""), quote=True)


def safe_url(value: str) -> bool:
    v = (value or "").strip()
    return v == "" or (bool(SAFE_URL.match(v)) and not v.startswith("//"))


def inline(source: str, link: str | None = None) -> str:
    out, cursor = [], 0
    for m in INLINE.finditer(source or ""):
        out.append(esc(source[cursor:m.start()]))
        if m.group(1) is not None:
            out.append(f"<strong>{inline(m.group(1), link)}</strong>")
        elif m.group(2) is not None:
            out.append(f"<em>{inline(m.group(2), link)}</em>")
        else:
            target = m.group(4)
            label = inline(m.group(3), link)
            if link is None and safe_url(target):
                rel = "" if target.startswith("/") else ' rel="noopener"'
                out.append(f'<a href="{esc(target)}"{rel}>{label}</a>')
            else:
                out.append(label)
        cursor = m.end()
    out.append(esc((source or "")[cursor:]))
    return "".join(out)


def figure(inner: str, caption: str) -> str:
    cap = f"<figcaption>{inline(caption)}</figcaption>" if caption.strip() else ""
    return f"<figure>{inner}{cap}</figure>"


def block_html(b: dict, nested: bool = False) -> str:
    t = b.get("type")
    if t == "paragraph":
        text = b.get("text") or ""
        return f"<p>{inline(text)}</p>" if text.strip() else ""
    if t == "heading":
        level = 3 if str(b.get("level")) == "3" else 2
        return f'<h{level} id="{esc(b.get("id"))}">{inline(b.get("text") or "")}</h{level}>'
    if t == "list":
        tag = "ol" if b.get("ordered") else "ul"
        items = "".join(f"<li>{inline(i)}</li>" for i in b.get("items") or [] if str(i).strip())
        return f"<{tag}>{items}</{tag}>" if items else ""
    if t == "quote":
        cite = b.get("cite") or ""
        cite_html = f"<footer>— {esc(cite)}</footer>" if cite.strip() else ""
        return f"<blockquote><p>{inline(b.get('text') or '')}</p>{cite_html}</blockquote>"
    if t == "image":
        url = b.get("url") or ""
        if not url.strip() or not safe_url(url):
            return ""
        return figure(
            f'<img src="{esc(url)}" alt="{esc(b.get("alt"))}" loading="lazy">',
            b.get("caption") or "",
        )
    if t == "video":
        url = (b.get("url") or "").strip()
        if not url or not safe_url(url):
            return ""
        if b.get("source") == "upload":
            return figure(
                f'<video controls preload="metadata" src="{esc(url)}"></video>',
                b.get("caption") or "",
            )
        yt, vm = YOUTUBE.match(url), VIMEO.match(url)
        if yt:
            watch = f"https://www.youtube.com/watch?v={yt.group(1)}"
            thumb = f'<img src="https://i.ytimg.com/vi/{yt.group(1)}/hqdefault.jpg" alt="YouTube videosu" loading="lazy">'
            inner = f'<a class="video-link" href="{esc(watch)}" rel="noopener">{thumb}<span>YouTube üzerinde izle</span></a>'
        elif vm:
            watch = f"https://vimeo.com/{vm.group(1)}"
            inner = f'<a class="video-link" href="{esc(watch)}" rel="noopener"><span>Vimeo üzerinde izle</span></a>'
        else:
            return ""
        return figure(inner, b.get("caption") or "")
    if t == "button":
        url, label = b.get("url") or "", b.get("label") or ""
        if not label.strip() or not url.strip() or not safe_url(url):
            return ""
        return f'<p><a class="btn" href="{esc(url)}">{esc(label)}</a></p>'
    if t == "divider":
        return "<hr>"
    if t == "columns" and not nested:
        cols = (b.get("columns") or [])[:4]
        inner = "".join(
            "<div>" + "".join(block_html(x, nested=True) for x in (c.get("blocks") or [])) + "</div>"
            for c in cols
        )
        return f'<div class="cols cols-{len(cols)}">{inner}</div>'
    return ""


def plain(source: str) -> str:
    return re.sub(r"<[^>]+>", "", inline(source))


def fmt_date(iso: str | None) -> str:
    if not iso:
        return ""
    months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz",
              "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", iso)
    return f"{int(m.group(3))} {months[int(m.group(2)) - 1]} {m.group(1)}" if m else ""


STYLE = """<style id="ibul-prerender-style">
#ibul-loader{overflow-y:auto}
.ibul-blog{max-width:760px;margin:0 auto;padding:32px 20px 64px;font:18px/1.75 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#34313F;background:#fff}
.ibul-blog h1{font-size:40px;line-height:1.18;color:#16141F;margin:12px 0}
.ibul-blog h2{font-size:28px;line-height:1.3;color:#16141F;margin:32px 0 8px}
.ibul-blog h3{font-size:22px;color:#16141F;margin:24px 0 8px}
.ibul-blog a{color:#7A2FF4}.ibul-blog .crumbs a{text-decoration:none;font-weight:700;font-size:14px}
.ibul-blog .sub{font-size:21px;color:#6B6878}.ibul-blog .meta{font-size:14px;color:#6B6878}
.ibul-blog img,.ibul-blog video{max-width:100%;height:auto;border-radius:14px;display:block}
.ibul-blog figure{margin:24px 0}.ibul-blog figcaption{font-size:14px;color:#6B6878;text-align:center}
.ibul-blog blockquote{border-left:4px solid #7A2FF4;margin:24px 0;padding:4px 0 4px 20px;font-style:italic}
.ibul-blog .btn{display:inline-block;background:#7A2FF4;color:#fff;padding:14px 24px;border-radius:12px;text-decoration:none;font-weight:700}
.ibul-blog .cols{display:grid;gap:28px}.ibul-blog .cols-2{grid-template-columns:repeat(2,1fr)}
.ibul-blog .cols-3{grid-template-columns:repeat(3,1fr)}.ibul-blog .cols-4{grid-template-columns:repeat(4,1fr)}
@media(max-width:760px){.ibul-blog .cols{grid-template-columns:1fr}.ibul-blog h1{font-size:30px}}
.ibul-blog nav.toc{border:1px solid #ECEAF2;border-radius:14px;padding:12px 20px;margin:24px 0}
.ibul-blog .card{margin:0 0 28px}.ibul-blog .card h2{font-size:22px;margin:4px 0}
</style>"""


def page(template: str, *, title: str, description: str, canonical: str,
         body: str, image: str | None = None, og_type: str = "website",
         jsonld: dict | None = None, noindex: bool = False,
         extra_head: str = "") -> str:
    doc = template
    doc = re.sub(r"<title>.*?</title>", f"<title>{esc(title)}</title>", doc, count=1, flags=re.S)

    def meta(attr: str, key: str, value: str) -> None:
        nonlocal doc
        pattern = re.compile(rf'<meta {attr}="{re.escape(key)}" content="[^"]*">')
        tag = f'<meta {attr}="{key}" content="{esc(value)}">'
        doc = pattern.sub(lambda _: tag, doc, count=1) if pattern.search(doc) else doc.replace("</head>", f"  {tag}\n</head>", 1)

    meta("name", "description", description)
    meta("name", "robots", "noindex, follow" if noindex else "index, follow")
    meta("property", "og:type", og_type)
    meta("property", "og:title", title)
    meta("property", "og:description", description)
    meta("property", "og:url", canonical)
    meta("name", "twitter:title", title)
    meta("name", "twitter:description", description)
    if image:
        meta("property", "og:image", image)
        meta("name", "twitter:image", image)
    head = [f'<link rel="canonical" href="{esc(canonical)}">', STYLE, extra_head]
    if jsonld:
        data = json.dumps(jsonld, ensure_ascii=False).replace("</", "<\\/")
        head.append(f'<script type="application/ld+json" id="{JSONLD_ID}">{data}</script>')
    doc = doc.replace("</head>", "\n".join(h for h in head if h) + "\n</head>", 1)
    marker = '<div id="ibul-loader-text"></div>'
    if marker not in doc:
        raise SystemExit("index.html: #ibul-loader-text not found; template changed")
    return doc.replace(marker, f'<main id="ibul-prerender" class="ibul-blog">{body}</main>\n    {marker}', 1)


def article_body(post: dict) -> str:
    blocks = (post.get("content") or {}).get("blocks") or []
    category = post.get("category")
    crumbs = '<a href="/blog">Blog</a>'
    if category:
        crumbs += f' › <a href="/blog?kategori={esc(category["slug"])}">{esc(category["name"])}</a>'
    author = (post.get("author") or {}).get("display_name")
    meta_bits = [esc(author)] if author else []
    meta_bits += [fmt_date(post.get("published_at")), f'{post.get("reading_minutes") or 1} dk okuma']
    headings = [b for b in blocks if b.get("type") == "heading" and (b.get("text") or "").strip()]
    toc = ""
    if len(headings) >= 3:
        items = "".join(f'<li><a href="#{esc(h.get("id"))}">{esc(plain(h.get("text")))}</a></li>' for h in headings)
        toc = f'<nav class="toc" aria-label="İçindekiler"><strong>İçindekiler</strong><ul>{items}</ul></nav>'
    cover = ""
    if post.get("cover_url") and safe_url(post["cover_url"]):
        cover = f'<img src="{esc(post["cover_url"])}" alt="{esc(post.get("cover_alt") or post["title"])}">'
    subtitle = f'<p class="sub">{esc(post["subtitle"])}</p>' if post.get("subtitle") else ""
    return (
        f'<article><nav class="crumbs" aria-label="Konum">{crumbs}</nav>'
        f'<h1>{esc(post["title"])}</h1>{subtitle}'
        f'<p class="meta">{" · ".join(b for b in meta_bits if b)}</p>{cover}{toc}'
        + "".join(block_html(b) for b in blocks)
        + '</article><p><a href="/blog">← Tüm blog yazıları</a></p>'
    )


def article_jsonld(post: dict, url: str) -> dict:
    data = {
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        "headline": post.get("seo_title") or post["title"],
        "datePublished": post.get("published_at"),
        "dateModified": post.get("updated_at"),
        "publisher": {"@type": "Organization", "name": "İBUL"},
        "mainEntityOfPage": url,
    }
    if post.get("meta_description") or post.get("excerpt"):
        data["description"] = post.get("meta_description") or post.get("excerpt")
    if post.get("cover_url"):
        data["image"] = [post["cover_url"]]
    if (post.get("author") or {}).get("display_name"):
        data["author"] = {"@type": "Person", "name": post["author"]["display_name"]}
    return data


class LiveSource:
    def __init__(self, url: str, key: str) -> None:
        self.url, self.key = url.rstrip("/"), key

    def rpc(self, name: str, params: dict | None = None):
        req = urllib.request.Request(
            f"{self.url}/rest/v1/rpc/{name}",
            data=json.dumps(params or {}).encode(),
            headers={"apikey": self.key, "Authorization": f"Bearer {self.key}",
                     "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as res:
            return json.loads(res.read() or b"null")

    def load(self) -> dict:
        summaries, offset = [], 0
        while True:
            page = self.rpc("blog_list_posts", {"p_limit": 48, "p_offset": offset})
            summaries += page
            offset += len(page)
            if not page or offset >= int(page[0]["total_count"]) or offset >= 2000:
                break
        posts = [p for p in (self.rpc("blog_get_post", {"p_slug": s["slug"]}) for s in summaries)
                 if isinstance(p, dict) and p.get("slug")]
        return {"posts": posts, "redirects": self.rpc("blog_list_public_redirects")}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("web_dir")
    ap.add_argument("--fixture")
    ap.add_argument("--origin", default=os.environ.get("IBUL_WEB_ORIGIN", "https://ibul.com.tr"))
    args = ap.parse_args()
    web = Path(args.web_dir)
    template = (web / "index.html").read_text(encoding="utf-8")
    origin = args.origin.rstrip("/")

    if args.fixture:
        data = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
    else:
        url, key = os.environ.get("IBUL_SUPABASE_URL"), os.environ.get("IBUL_SUPABASE_ANON_KEY")
        if not url or not key:
            print("prerender_blog: IBUL_SUPABASE_URL/ANON_KEY yok, atlandı.")
            return 0
        try:
            data = LiveSource(url, key).load()
        except (urllib.error.URLError, TimeoutError, ValueError) as error:
            # Blog migrations not applied yet or network down: SPA still works.
            print(f"prerender_blog: blog verisi okunamadı ({error}); statik blog sayfası üretilmedi.")
            return 0

    out = web / "blog"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    posts = sorted((p for p in data.get("posts", []) if SLUG.match(p.get("slug", ""))),
                   key=lambda p: p.get("published_at") or "", reverse=True)

    for post in posts:
        url = f"{origin}/blog/{post['slug']}"
        target = out / post["slug"]
        target.mkdir(parents=True, exist_ok=True)
        (target / "index.html").write_text(page(
            template,
            title=f'{post.get("seo_title") or post["title"]} | İBUL Blog',
            description=post.get("meta_description") or post.get("excerpt") or post.get("subtitle") or "",
            canonical=url, body=article_body(post), image=post.get("cover_url"),
            og_type="article", jsonld=article_jsonld(post, url),
        ), encoding="utf-8")

    live = {p["slug"] for p in posts}
    for r in data.get("redirects", []):
        old, new = r.get("old_slug", ""), r.get("slug", "")
        if not SLUG.match(old) or new not in live or old in live:
            continue
        target_url = f"/blog/{new}"
        (out / old).mkdir(parents=True, exist_ok=True)
        (out / old / "index.html").write_text(page(
            template, title="Yönlendiriliyor | İBUL Blog", description="",
            canonical=f"{origin}{target_url}", noindex=True,
            extra_head=f'<meta http-equiv="refresh" content="0; url={esc(target_url)}">',
            body=f'<p>Bu yazı taşındı: <a href="{esc(target_url)}">{esc(target_url)}</a></p>',
        ), encoding="utf-8")

    cards = "".join(
        f'<div class="card"><a href="/blog/{esc(p["slug"])}"><h2>{esc(p["title"])}</h2></a>'
        f'<p>{esc(p.get("excerpt") or "")}</p><p class="meta">{fmt_date(p.get("published_at"))}</p></div>'
        for p in posts
    )
    (out / "index.html").write_text(page(
        template, title="İBUL Blog",
        description="Alışveriş rehberleri, ürün karşılaştırmaları ve İBUL’dan haberler.",
        canonical=f"{origin}/blog",
        body=f"<h1>İBUL Blog</h1>{cards or '<p>Henüz yazı yok.</p>'}",
    ), encoding="utf-8")

    urls = [f"<url><loc>{esc(origin)}/blog</loc></url>"] + [
        f"<url><loc>{esc(origin)}/blog/{esc(p['slug'])}</loc>"
        + (f"<lastmod>{esc((p.get('updated_at') or '')[:10])}</lastmod>" if p.get("updated_at") else "")
        + "</url>"
        for p in posts
    ]
    (web / "blog-sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + "".join(urls) + "</urlset>\n", encoding="utf-8")
    print(f"prerender_blog: {len(posts)} yazı, {len(data.get('redirects', []))} yönlendirme yazıldı.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
