#!/usr/bin/env python3
"""
Level B conformance: compares what the Ceramic spine plugin sends to the renderer
(dump of the conformance app, spine-haxe runtime) with the reference computed by the
official spine-cpp runtime (reference-cpp/dump.cpp).

Usage: compare_geometry.py <ceramic-dump-dir> <reference-dir> <known-gaps.json> <report.md>

Both directories hold <skeleton>/<animation>.json files. Exit code is 1 when a
difference is not declared in known-gaps.json.
"""
import json
import math
import os
import sys

# spine-cpp computes with 32 bit floats, spine-haxe with doubles: the position tolerance
# is relative to the magnitude of the coordinates (about 4 float ulps per operation chain)
POS_TOL = 1e-2
POS_REL_TOL = 4e-6
# Clipped slots: runtimes may cut the same area into different triangles. They are
# compared by sampling the covered area on a grid (union and multiply covered samples).
COVERAGE_STEP = 2.0
COVERAGE_TOL = 0.005
UV_TOL = 1e-5
COLOR_TOL = 1.5 / 255.0

# Ceramic blending values (ceramic.Blending) and spine blend modes (spine-cpp BlendMode)
CERAMIC_AUTO = 0
CERAMIC_ADD = 2
CERAMIC_MULTIPLY = 8
CERAMIC_SCREEN = 9
SPINE_NORMAL = 0
SPINE_ADDITIVE = 1
SPINE_MULTIPLY = 2
SPINE_SCREEN = 3


def ceramic_items(frame):
    meshes = [v for v in frame['visuals'] if v['kind'] == 'mesh' and v['visible']]
    meshes.sort(key=lambda v: (v['depth'], v['index']))
    items = []
    for m in meshes:
        stride = 2 + m['customFloatAttributesSize']
        vertices = m['vertices']
        count = len(vertices) // stride
        xy = []
        extra = []
        for i in range(count):
            xy.append(vertices[i * stride])
            xy.append(vertices[i * stride + 1])
            if stride > 2:
                extra.append(vertices[i * stride + 2:i * stride + stride])
        color = m['colors'][0] if m['colors'] else 0xFFFFFFFF
        color &= 0xFFFFFFFF
        a = ((color >> 24) & 0xFF) / 255.0
        r = ((color >> 16) & 0xFF) / 255.0
        g = ((color >> 8) & 0xFF) / 255.0
        b = (color & 0xFF) / 255.0
        texture = m.get('texture')
        items.append({
            'xy': xy,
            'uvs': m['uvs'][:count * 2] if m['uvs'] is not None else [],
            'indices': m['indices'] or [],
            'color': [r, g, b, a],
            'extra': extra,
            'blending': m['blending'],
            'page': os.path.basename(texture) if texture else None,
        })
    return items


def close(a, b, tol):
    return abs(a - b) <= tol


def _triangles(xy, idx):
    return [((xy[2*idx[t]], xy[2*idx[t]+1]), (xy[2*idx[t+1]], xy[2*idx[t+1]+1]), (xy[2*idx[t+2]], xy[2*idx[t+2]+1]))
            for t in range(0, len(idx) - 2, 3)]


def _in_triangle(x, y, t):
    (ax, ay), (bx, by), (cx, cy) = t
    d1 = (x - bx) * (ay - by) - (ax - bx) * (y - by)
    d2 = (x - cx) * (by - cy) - (bx - cx) * (y - cy)
    d3 = (x - ax) * (cy - ay) - (cx - ax) * (y - ay)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))


def coverage(xy, idx, bounds):
    """Samples covered at least once, and samples covered more than once"""
    tris = _triangles(xy, idx)
    union = multiple = 0
    min_x, min_y, max_x, max_y = bounds
    y = min_y + COVERAGE_STEP / 2
    while y < max_y:
        x = min_x + COVERAGE_STEP / 2
        while x < max_x:
            n = 0
            for t in tris:
                if _in_triangle(x, y, t):
                    n += 1
            if n:
                union += 1
                if n > 1:
                    multiple += 1
            x += COVERAGE_STEP
        y += COVERAGE_STEP
    return union, multiple


def compare_clipped(c, r):
    xs = c['xy'][0::2] + r['vertices'][0::2]
    ys = c['xy'][1::2] + r['vertices'][1::2]
    if not xs:
        return []
    bounds = (min(xs), min(ys), max(xs), max(ys))
    cu, cm = coverage(c['xy'], c['indices'], bounds)
    ru, rm = coverage(r['vertices'], r['triangles'], bounds)
    if abs(cu - ru) > max(2, COVERAGE_TOL * ru) or cm != rm:
        return [('clipping', 'clipped coverage %d samples (%d covered more than once) != reference %d (%d)' % (cu, cm, ru, rm))]
    return []


def align_quad(c, r):
    best = None
    for shift in range(4):
        err = 0.0
        for k in range(4):
            j = (k + shift) % 4
            err = max(err, abs(c['xy'][j * 2] - r['vertices'][k * 2]), abs(c['xy'][j * 2 + 1] - r['vertices'][k * 2 + 1]))
        if best is None or err < best[0]:
            best = (err, shift)
    shift = best[1]
    aligned = dict(c)
    aligned['xy'] = [c['xy'][((k + shift) % 4) * 2 + e] for k in range(4) for e in range(2)]
    if len(c['uvs']) == 8:
        aligned['uvs'] = [c['uvs'][((k + shift) % 4) * 2 + e] for k in range(4) for e in range(2)]
    return aligned


def compare_item(c, r, gaps):
    """Returns a list of (kind, message)"""
    diffs = []
    if (c['page'] or None) != (r['page'] or None):
        diffs.append(('texture', 'page %s != %s' % (c['page'], r['page'])))

    blend = r['blend']
    expected_blending = {SPINE_NORMAL: CERAMIC_AUTO, SPINE_ADDITIVE: CERAMIC_ADD, SPINE_MULTIPLY: CERAMIC_MULTIPLY, SPINE_SCREEN: CERAMIC_SCREEN}[blend]
    if c['blending'] != expected_blending:
        if blend in (SPINE_MULTIPLY, SPINE_SCREEN) and 'blend-multiply-screen' in gaps:
            pass
        else:
            diffs.append(('blend', 'blending %d != expected %d' % (c['blending'], expected_blending)))

    if r['clipped']:
        # Same area, possibly cut into different triangles
        diffs.extend(compare_clipped(c, r))
        for i in range(4):
            if not close(c['color'][i], r['color'][i], COLOR_TOL):
                diffs.append(('color', 'color %s != %s' % (['%.3f' % v for v in c['color']], ['%.3f' % v for v in r['color']])))
                break
        return diffs

    if r['type'] == 'region' and len(c['xy']) == 8 and len(r['vertices']) == 8:
        # Runtimes write the 4 corners of a region starting at different corners
        # (spine-cpp: bottom right, spine-haxe: bottom left). Align the corners, then
        # the quad is the same: the triangles only differ by the diagonal, which gives
        # the same result for a parallelogram (always the case for a region).
        c = align_quad(c, r)
    elif c['indices'] != r['triangles']:
        diffs.append(('triangles', 'triangles differ (%d vs %d indices)' % (len(c['indices']), len(r['triangles']))))

    if len(c['xy']) != len(r['vertices']):
        diffs.append(('vertices', 'vertex count %d != %d' % (len(c['xy']) // 2, len(r['vertices']) // 2)))
    else:
        worst = 0.0
        for a, b in zip(c['xy'], r['vertices']):
            worst = max(worst, abs(a - b) - POS_REL_TOL * abs(b))
        if worst > POS_TOL:
            diffs.append(('vertices', 'max position error %.6f (beyond relative tolerance)' % worst))
        worst = 0.0
        for a, b in zip(c['uvs'], r['uvs']):
            worst = max(worst, abs(a - b))
        if len(c['uvs']) != len(r['uvs']) or worst > UV_TOL:
            diffs.append(('uvs', 'max uv error %.7f (%d vs %d)' % (worst, len(c['uvs']), len(r['uvs']))))

    for i in range(4):
        if not close(c['color'][i], r['color'][i], COLOR_TOL):
            diffs.append(('color', 'color %s != %s' % (['%.3f' % v for v in c['color']], ['%.3f' % v for v in r['color']])))
            break

    if r['dark'] is not None or c['extra']:
        # Official two color tint: the dark color of the slot, premultiplied by the final alpha
        a = r['color'][3]
        dark = r['dark'] or [0, 0, 0, 1]
        expected = [dark[0] * a, dark[1] * a, dark[2] * a, dark[3]] if r['dark'] is not None else [0, 0, 0, 1]
        if c['extra']:
            got = c['extra'][0]
            if any(not close(got[i], expected[i], COLOR_TOL) for i in range(4)):
                if 'dark-color-attachment-tint' not in gaps:
                    diffs.append(('dark', 'dark color %s != %s' % (['%.3f' % v for v in got], ['%.3f' % v for v in expected])))
        elif r['dark'] is not None:
            diffs.append(('dark', 'dark color missing'))
    return diffs


def main():
    if len(sys.argv) != 5:
        print(__doc__.strip())
        sys.exit(2)
    ceramic_dir, reference_dir, gaps_path, report_path = sys.argv[1:5]
    gaps = json.load(open(gaps_path)) if os.path.exists(gaps_path) else {}

    lines = ['# Spine conformance, level B (geometry)', '']
    total = 0
    failed = 0
    summary = {}
    for skeleton in sorted(os.listdir(reference_dir)):
        sk_dir = os.path.join(reference_dir, skeleton)
        if not os.path.isdir(sk_dir):
            continue
        for name in sorted(os.listdir(sk_dir)):
            if not name.endswith('.json'):
                continue
            ref = json.load(open(os.path.join(sk_dir, name)))
            cer_path = os.path.join(ceramic_dir, skeleton, name)
            key = skeleton + '/' + name[:-5]
            if not os.path.exists(cer_path):
                lines.append('- MISSING `%s`: no Ceramic dump' % key)
                failed += 1
                total += 1
                continue
            cer = json.load(open(cer_path))
            cer_frames = {f['step']: f for f in cer['frames']}
            for frame in ref['frames']:
                total += 1
                step = frame['step']
                if step not in cer_frames:
                    lines.append('- MISSING `%s` step %d' % (key, step))
                    failed += 1
                    continue
                c_items = ceramic_items(cer_frames[step])
                r_items = frame['items']
                problems = []
                if len(c_items) != len(r_items):
                    problems.append(('count', 'draw count %d != %d' % (len(c_items), len(r_items))))
                for i, (c, r) in enumerate(zip(c_items, r_items)):
                    for kind, message in compare_item(c, r, gaps):
                        problems.append((kind, 'slot %s (%s): %s' % (r['slot'], r['attachment'], message)))
                        if len(problems) > 8:
                            break
                    if len(problems) > 8:
                        break
                if problems:
                    failed += 1
                    for kind, _ in problems:
                        summary[kind] = summary.get(kind, 0) + 1
                    lines.append('- FAIL `%s` step %d' % (key, step))
                    for _, message in problems[:8]:
                        lines.append('    - ' + message)

    lines.insert(2, '**%d / %d frames pass** (tolerances: position %.0e + %.0e x |value|, uv %.0e, color %.4f)' % (total - failed, total, POS_TOL, POS_REL_TOL, UV_TOL, COLOR_TOL))
    if summary:
        lines.insert(3, '')
        lines.insert(4, 'Failures by kind: ' + ', '.join('%s=%d' % kv for kv in sorted(summary.items())))
    lines.insert(5 if summary else 3, '')
    with open(report_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print('\n'.join(lines[:6]))
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
