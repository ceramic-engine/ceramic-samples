#!/usr/bin/env python3
"""
Summarize spine-bench results.

Usage: report.py <label,label,...> <output.md>

For each scenario and build label (results/<label>/<scenario>.log), takes the mean
time of each phase in every run, and reports the median over runs with the min/max
spread. Allocations are the difference between regular runs and the control run
(results/<label>/<scenario>-control.log).
"""
import os
import re
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PHASES = ['anim', 'world', 'render', 'total']


def parse(path):
    runs = []
    current = None
    if not os.path.exists(path):
        return runs
    for line in open(path):
        line = line.strip()
        if line.startswith('RUN '):
            current = {}
            runs.append(current)
            continue
        if current is None:
            continue
        m = re.match(r'BENCH (\w+) ms: mean=([\d.]+) p50=([\d.]+) p95=([\d.]+) p99=([\d.]+) max=([\d.]+)', line)
        if m:
            current[m.group(1)] = {'mean': float(m.group(2)), 'p50': float(m.group(3)), 'p95': float(m.group(4)), 'p99': float(m.group(5))}
            continue
        m = re.match(r'BENCH alloc whole frame: (\d+) bytes/frame', line)
        if m:
            current['alloc'] = int(m.group(1))
            continue
        m = re.match(r'BENCH process cpu ms/frame: ([\d.]+)', line)
        if m:
            current['cpu'] = float(m.group(1))
            continue
        m = re.match(r'BENCH CONFIG: (.*)', line)
        if m:
            current['config'] = m.group(1)
            continue
        m = re.match(r'BENCH DEFINES: (.*)', line)
        if m:
            current['defines'] = m.group(1)
    return [r for r in runs if 'total' in r]


def fmt(values):
    if not values:
        return 'n/a'
    med = statistics.median(values)
    return '%.3f (%.3f-%.3f)' % (med, min(values), max(values))


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        sys.exit(2)
    labels = sys.argv[1].split(',')
    out = sys.argv[2]
    scenarios = set()
    for label in labels:
        d = os.path.join(HERE, 'results', label)
        if os.path.isdir(d):
            for name in os.listdir(d):
                if name.endswith('.log') and not name.endswith('-control.log'):
                    scenarios.add(name[:-4])
    lines = ['# spine-bench results', '',
             'Milliseconds per frame for all spine updates of the frame: median of the per-run means, (min-max) over runs.',
             'Allocations: bytes per frame of regular runs minus control runs (spines never updated).', '']
    defines = {}
    for scenario in sorted(scenarios):
        lines.append('## ' + scenario)
        lines.append('')
        lines.append('| build | runs | anim | world | render | total | total p99 | alloc B/frame |')
        lines.append('|---|---|---|---|---|---|---|---|')
        for label in labels:
            runs = parse(os.path.join(HERE, 'results', label, scenario + '.log'))
            control = parse(os.path.join(HERE, 'results', label, scenario + '-control.log'))
            if not runs:
                continue
            if runs and 'defines' in runs[0]:
                defines[label] = runs[0]['defines']
            cols = [fmt([r[p]['mean'] for r in runs if p in r]) for p in PHASES]
            p99 = fmt([r['total']['p99'] for r in runs])
            alloc = 'n/a'
            if control and all('alloc' in r for r in runs):
                base = statistics.median([c['alloc'] for c in control])
                alloc = '%d' % (statistics.median([r['alloc'] for r in runs]) - base)
            lines.append('| %s | %d | %s | %s |' % (label, len(runs), ' | '.join(cols), p99 + ' | ' + alloc))
        lines.append('')
    if defines:
        lines.append('## Build defines')
        lines.append('')
        for label, d in defines.items():
            lines.append('- **%s**: `%s`' % (label, d))
        lines.append('')
    open(out, 'w').write('\n'.join(lines) + '\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
