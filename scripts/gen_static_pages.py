#!/usr/bin/env python3
"""Generate a SQL migration that upserts all www/*.html pages into static_pages.

Transformations applied:
  1. CSS inlined (style.css -> <style>)
  2. config.js replaced with inline production credentials
  3. Image refs rewritten to Supabase Storage URLs
  4. Inter-page links rewritten to www?page=X format
  5. Query-string parameters converted to hash fragments
  6. CDN script tags preserved as-is
"""

import os
import re
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WWW = os.path.join(BASE, 'www')

SUPABASE_URL = 'https://oandzthkyemwojhebqwc.supabase.co'
SUPABASE_ANON_KEY = (
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hbmR6dGhreWVtd29qaGVicXdjIiwi'
    'cm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDgwNzUsImV4cCI6MjA4NjY4NDA3NX0.'
    'v7hwYm4a-b1aiWj04cCQY2WT9v08FEqvioFU3BG7nus'
)
STORAGE_BASE = f'{SUPABASE_URL}/storage/v1/object/public/www'

PAGES = ['index.html', 'detail.html', 'new.html', 'confirm.html',
         'queue.html', 'analytics.html']

CONFIG_INLINE = (
    '<script>\n'
    f"    const SUPABASE_URL = '{SUPABASE_URL}';\n"
    f"    const SUPABASE_ANON_KEY = '{SUPABASE_ANON_KEY}';\n"
    '  </script>'
)


def read(path):
    with open(os.path.join(WWW, path)) as f:
        return f.read()


def transform(html):
    css = read('style.css')

    # 1. Inline CSS
    html = html.replace(
        '<link rel="stylesheet" href="style.css">',
        f'<style>\n{css}\n</style>'
    )

    # 2. Inline config.js
    html = html.replace(
        '<script src="config.js"></script>',
        CONFIG_INLINE
    )

    # 3. Rewrite image references
    html = html.replace(
        'src="capreq-icon.png"',
        f'src="{STORAGE_BASE}/capreq-icon.png"'
    )
    html = html.replace(
        'href="capreq-icon.png"',
        f'href="{STORAGE_BASE}/capreq-icon.png"'
    )

    # 4. Rewrite inter-page links with query params -> hash fragments
    #    Must happen BEFORE the bare href replacements below.
    #    Covers: detail.html?id=, confirm.html?id=
    html = html.replace('detail.html?id=', 'www?page=detail.html#id=')
    html = html.replace('confirm.html?id=', 'www?page=confirm.html#id=')

    # 5. Rewrite bare inter-page href links
    for page in PAGES:
        html = html.replace(f'href="{page}"', f'href="www?page={page}"')

    # 6. Convert URLSearchParams(location.search) to hash fragments
    html = html.replace(
        'URLSearchParams(location.search)',
        'URLSearchParams(location.hash.substring(1))'
    )

    # 7. Convert history.replaceState for filter param persistence
    #    applyFilters: qs ? '?' + qs : location.pathname
    html = html.replace(
        "history.replaceState(null, '', qs ? '?' + qs : location.pathname)",
        "history.replaceState(null, '', location.pathname + location.search + (qs ? '#' + qs : ''))"
    )
    #    clearFilters: just location.pathname
    html = html.replace(
        "history.replaceState(null, '', location.pathname)",
        "history.replaceState(null, '', location.pathname + location.search)"
    )

    return html


def main():
    out = []
    out.append('-- Migration: Update static_pages with Phase 6b UI changes')
    out.append('-- Updates all existing pages and adds queue.html + analytics.html')
    out.append('-- Transformations: CSS inlined, config.js inlined, image URLs rewritten,')
    out.append('-- inter-page links use www?page= format, params use hash fragments.')
    out.append('')
    out.append('DELETE FROM static_pages;')
    out.append('')

    for page in PAGES:
        html = read(page)
        html = transform(html)
        # Verify the $page$ delimiter doesn't appear in content
        assert '$page$' not in html, f'{page} contains $page$ delimiter!'
        out.append(f'-- ============================================================')
        out.append(f'-- {page}')
        out.append(f'-- ============================================================')
        out.append(f"INSERT INTO static_pages (path, content) VALUES ('{page}', $page${html}$page$);")
        out.append('')

    print('\n'.join(out))


if __name__ == '__main__':
    main()
