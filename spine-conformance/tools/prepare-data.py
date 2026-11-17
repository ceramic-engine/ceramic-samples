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
        jsons = sorted(f for f in files if f.endswith('.json'))
        # Prefer the Pro export, which uses more features
        pro = [f for f in jsons if f.endswith('-pro.json')]
        ess = [f for f in jsons if f.endswith('-ess.json')]
        json_files = pro if pro else ess
        atlases = sorted(f for f in files if f.endswith('.atlas') and '-pma' not in f)
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
