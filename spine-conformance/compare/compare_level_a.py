#!/usr/bin/env python3
"""
Level A conformance: compares the skeleton states produced by spine-haxe (built and
run inside the Ceramic conformance app) with the official reference runtime
(spine-libgdx, reference-java), for the scenarios of tools/make-scenarios.py.

Usage: compare_level_a.py <haxe-dir> <java-dir> <report.md>

Java computes with 32 bit floats, Haxe with doubles: values are compared with an
absolute tolerance plus a relative one. Physics constraints amplify these differences
over time: skeletons with physics get a larger tolerance, reported separately.
"""
import json
import math
import os
import sys

ABS_TOL = 5e-3
REL_TOL = 1e-4
ROTATION_TOL = 1e-2
PHYSICS_FACTOR = 50

BONE_FIELDS = ['x', 'y', 'rotation', 'scaleX', 'scaleY', 'shearX', 'shearY', 'a', 'b', 'c', 'd', 'worldX', 'worldY']


def close(a, b, factor):
    tol = (ABS_TOL + REL_TOL * abs(b)) * factor
    return abs(a - b) <= tol


def angle_close(a, b, factor):
    d = (a - b) % 360.0
    d = min(d, 360.0 - d)
    return d <= ROTATION_TOL * factor


def compare(h, j, factor):
    problems = []
    for sh, sj in zip(h['snapshots'], j['snapshots']):
        step = sj['step']
        if sh['step'] != step:
            problems.append('snapshot steps differ')
            break
        for bi, (bh, bj) in enumerate(zip(sh['bones'], sj['bones'])):
            for fi, name in enumerate(BONE_FIELDS):
                ok = angle_close(bh[fi], bj[fi], factor) if name in ('rotation', 'shearX', 'shearY') else close(bh[fi], bj[fi], factor)
                if not ok:
                    problems.append('step %d bone %d %s: %.6f != %.6f' % (step, bi, name, bh[fi], bj[fi]))
                    break
        for si, (ph, pj) in enumerate(zip(sh['slots'], sj['slots'])):
            if ph['a'] != pj['a']:
                problems.append('step %d slot %d attachment %s != %s' % (step, si, ph['a'], pj['a']))
            # Without attachment, the sequence index is the default value of SlotPose, which
            # differs between runtimes (spine-haxe -1, spine-libgdx and spine-cpp 0) and is never used
            if ph['s'] != pj['s'] and pj['a'] is not None:
                problems.append('step %d slot %d sequence index %d != %d' % (step, si, ph['s'], pj['s']))
            if any(abs(x - y) > 2e-3 for x, y in zip(ph['c'], pj['c'])):
                problems.append('step %d slot %d color %s != %s' % (step, si, ph['c'], pj['c']))
            if len(ph['f']) != len(pj['f']):
                problems.append('step %d slot %d deform length %d != %d' % (step, si, len(ph['f']), len(pj['f'])))
            elif any(not close(x, y, factor) for x, y in zip(ph['f'], pj['f'])):
                worst = max(abs(x - y) for x, y in zip(ph['f'], pj['f']))
                problems.append('step %d slot %d deform differs (max %.4f)' % (step, si, worst))
        if sh['o'] != sj['o']:
            problems.append('step %d draw order differs' % step)
        if len(problems) > 6:
            break
    return problems


def main():
    if len(sys.argv) != 4:
        print(__doc__.strip())
        sys.exit(2)
    haxe_dir, java_dir, report = sys.argv[1:4]
    lines = ['# Spine conformance, level A (runtime state, spine-haxe vs spine-libgdx)', '']
    total = failed = 0
    for name in sorted(os.listdir(java_dir)):
        if not name.endswith('.json'):
            continue
        total += 1
        j = json.load(open(os.path.join(java_dir, name)))
        hp = os.path.join(haxe_dir, name)
        if not os.path.exists(hp):
            failed += 1
            lines.append('- MISSING `%s`' % name[:-5])
            continue
        h = json.load(open(hp))
        skeleton = name.split('__')[0]
        physics = skeleton in PHYSICS_SKELETONS
        problems = compare(h, j, PHYSICS_FACTOR if physics else 1)
        if problems:
            failed += 1
            lines.append('- FAIL `%s`%s' % (name[:-5], ' (physics)' if physics else ''))
            for p in problems[:6]:
                lines.append('    - ' + p)
    lines.insert(2, '**%d / %d scenarios pass** (tolerance %.0e + %.0e x |value|, x%d for skeletons with physics)' % (total - failed, total, ABS_TOL, REL_TOL, PHYSICS_FACTOR))
    lines.insert(3, '')
    open(report, 'w').write('\n'.join(lines) + '\n')
    print('\n'.join(lines[:4]))
    sys.exit(1 if failed else 0)


PHYSICS_SKELETONS = set()

if __name__ == '__main__':
    data_dir = os.environ.get('SPINE_CONFORMANCE_DATA')
    if data_dir:
        for folder in os.listdir(data_dir):
            path = os.path.join(data_dir, folder, folder[:-len('.spine')] + '.json')
            if folder.endswith('.spine') and os.path.exists(path):
                d = json.load(open(path))
                if any(c.get('type') == 'physics' for c in d.get('constraints', [])):
                    PHYSICS_SKELETONS.add(folder[:-len('.spine')])
    main()
