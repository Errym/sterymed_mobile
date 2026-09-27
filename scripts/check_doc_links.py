import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MD_LINK = re.compile(r'(?<!!)\[([^\]]*)\]\(([^)]+)\)')


def slugify(heading):
    # Matches GitHub's github-slugger: strip disallowed chars first (no
    # collapsing), THEN turn each remaining space into its own hyphen —
    # a heading with a double space (e.g. from "/ ") legitimately
    # produces a double hyphen, not a collapsed single one.
    s = heading.strip().lower()
    s = re.sub(r'[^\w\s-]', '', s)
    s = s.replace(' ', '-')
    return s


def headings_of(path):
    slugs = set()
    counts = {}
    try:
        with open(path, encoding='utf-8') as f:
            for line in f:
                m = re.match(r'^(#{1,6})\s+(.*)', line)
                if m:
                    slug = slugify(m.group(2))
                    n = counts.get(slug, 0)
                    counts[slug] = n + 1
                    slugs.add(slug if n == 0 else f'{slug}-{n}')
    except FileNotFoundError:
        pass
    return slugs


def find_md_files():
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        if any(part in dirpath.split(os.sep) for part in
               ('.git', '.dart_tool', 'build', 'node_modules', 'ios', 'android')):
            continue
        for fn in filenames:
            if fn.endswith('.md'):
                out.append(os.path.join(dirpath, fn))
    return out


def main():
    files = find_md_files()
    errors = []
    for path in files:
        with open(path, encoding='utf-8') as f:
            content = f.read()
        for m in MD_LINK.finditer(content):
            text, target = m.group(1), m.group(2).strip()
            if target.startswith(('http://', 'https://', 'mailto:')):
                continue
            file_part, _, anchor = target.partition('#')
            if file_part == '':
                target_path = path
            else:
                target_path = os.path.normpath(os.path.join(os.path.dirname(path), file_part))
            if file_part and not os.path.isfile(target_path):
                errors.append(f'{os.path.relpath(path, ROOT)}: [{text}]({target}) -> missing file {os.path.relpath(target_path, ROOT)}')
                continue
            if anchor:
                slugs = headings_of(target_path)
                if anchor not in slugs:
                    errors.append(f'{os.path.relpath(path, ROOT)}: [{text}]({target}) -> anchor #{anchor} not found in {os.path.relpath(target_path, ROOT)}')

    if errors:
        print(f'{len(errors)} broken link(s):')
        for e in errors:
            print(' -', e)
        sys.exit(1)
    else:
        print(f'All markdown links resolve ({len(files)} files scanned).')


if __name__ == '__main__':
    main()
