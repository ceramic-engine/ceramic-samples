#!/usr/bin/env python3
"""
Copy the official Spine example exports into a Ceramic asset folder:
one `<skeleton>.spine/` folder per example with its JSON, its non premultiplied
atlas and the atlas pages.

Usage: prepare-data.py <spine-runtimes>/examples <output-dir>
"""
import os
import shutil
import sys


def atlas_pages(atlas_path):
    pages = []
    with open(atlas_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.endswith('.png') and ':' not in line:
                pages.append(line)
    return pages


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        sys.exit(1)
    examples = os.path.abspath(sys.argv[1])
    output = os.path.abspath(sys.argv[2])
    if not os.path.isdir(examples):
        sys.exit('Not a directory: ' + examples)
    os.makedirs(output, exist_ok=True)

    count = 0
    for name in sorted(os.listdir(examples)):
        export = os.path.join(examples, name, 'export')
        if not os.path.isdir(export):
            continue
        files = os.listdir(export)
        # Group the JSON exports by skeleton (name without the -pro / -ess marker),
        # and prefer the Pro export, which uses more features
        groups = {}
        for f in sorted(files):
            if not f.endswith('.json'):
                continue
            base = f[:-len('.json')]
            key = base.replace('-pro', '').replace('-ess', '')
            rank = 0 if '-pro' in base else (1 if '-ess' in base else 2)
            if key not in groups or rank < groups[key][0]:
                groups[key] = (rank, f)
        json_files = [groups[k][1] for k in sorted(groups)]
        # Prefer the straight alpha atlas named after the example
        atlases = sorted(f for f in files if f.endswith('.atlas') and '-pma' not in f)
        if name + '.atlas' in atlases:
            atlases.remove(name + '.atlas')
            atlases.insert(0, name + '.atlas')
        if not json_files or not atlases:
            print('Skip ' + name + ' (no json or no straight alpha atlas)')
            continue
        atlas = atlases[0]
        pages = atlas_pages(os.path.join(export, atlas))
        for json_file in json_files:
            skeleton = json_file[:-len('.json')]
            target = os.path.join(output, skeleton + '.spine')
            os.makedirs(target, exist_ok=True)
            shutil.copyfile(os.path.join(export, json_file), os.path.join(target, json_file))
            shutil.copyfile(os.path.join(export, atlas), os.path.join(target, atlas))
            for page in pages:
                shutil.copyfile(os.path.join(export, page), os.path.join(target, page))
            print('Prepared ' + skeleton + ' (' + atlas + ', ' + str(len(pages)) + ' page(s))')
            count += 1
    print(str(count) + ' skeleton(s) in ' + output)


if __name__ == '__main__':
    main()
