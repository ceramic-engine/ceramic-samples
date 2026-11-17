#!/usr/bin/env python3
"""
Compares the Ceramic layer scenarios (_bindings, _bbox) of two conformance dumps,
typically legacy (golden) and spine-haxe, played with the same time step (30 fps).
The skeleton data differ slightly (Spine 4.0 and 4.3 exports of the same project),
so transforms are compared with a tolerance.

Usage: compare_bindings.py <dump-a> <dump-b>
"""
import json
import os
import sys

# The two data sets are exports of the same project for Spine 4.0 and 4.3, rounded
# differently: transforms (coordinates of several hundred pixels) differ slightly
TRANSFORM_TOL = 0.25


def max_diff(x, y):
    return max(abs(p - q) for p, q in zip(x, y)) if x and y else 0.0


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        sys.exit(2)
    a = json.load(open(os.path.join(sys.argv[1], '_bindings', 'spineboy-pro.json')))
    b = json.load(open(os.path.join(sys.argv[2], '_bindings', 'spineboy-pro.json')))
    problems = []
    for fa, fb in zip(a['frames'], b['frames']):
        step = fa['step']
        qa = [v for v in fa['root'] if v['kind'] == 'quad']
        qb = [v for v in fb['root'] if v['kind'] == 'quad']
        sa = [v for v in fa['root'] if v['kind'] == 'spine']
        sb = [v for v in fb['root'] if v['kind'] == 'spine']
        if len(qa) != len(qb) or len(sa) != len(sb):
            problems.append('step %d: bound visual count differs' % step)
            continue
        for x, y in zip(qa, qb):
            d = max_diff(x['transform'], y['transform'])
            if d > TRANSFORM_TOL:
                problems.append('step %d: bound quad transform differs by %.3f' % (step, d))
            for key in ('depth', 'alpha', 'color', 'visible', 'active', 'blending'):
                if x[key] != y[key]:
                    problems.append('step %d: bound quad %s %s != %s' % (step, key, x[key], y[key]))
        for x, y in zip(sa, sb):
            if len(x['children']) != len(y['children']):
                problems.append('step %d: child spine mesh count %d != %d' % (step, len(x['children']), len(y['children'])))
        d = max_diff(fa['gunChildTransform'], fb['gunChildTransform'])
        if d > TRANSFORM_TOL:
            problems.append('step %d: child spine transform differs by %.3f' % (step, d))
        for key in ('gunChildDepth', 'gunChildDepthRange', 'slotHits', 'colors'):
            if fa[key] != fb[key]:
                problems.append('step %d: %s differs' % (step, key))
        if len(fa['slotInfos']) != len(fb['slotInfos']):
            problems.append('step %d: slot callback count %d != %d' % (step, len(fa['slotInfos']), len(fb['slotInfos'])))
        for x, y in zip(fa['slotInfos'], fb['slotInfos']):
            if x['slot'] != y['slot'] or x['drawDefault'] != y['drawDefault'] or x['depth'] != y['depth'] or max_diff(x['transform'], y['transform']) > TRANSFORM_TOL:
                problems.append('step %d: slot callback info differs (%s)' % (step, x['slot']))
                break
    if [e['name'] for e in a['events']] != [e['name'] for e in b['events']]:
        problems.append('events differ')
    for p in problems:
        print('FAIL ' + p)
    print('bindings: %s' % ('PASS' if not problems else '%d problem(s)' % len(problems)))
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
