#!/usr/bin/env python3
"""
Generates level A scenarios (JSON) for every skeleton of a data set: what the
runtime does over time, beyond single animations (mixing, additive tracks, skins).

Usage: make-scenarios.py <data-dir> <output-dir>

Each scenario: {"skeleton", "dt", "steps", "snapshots", "defaultMix", "actions"}.
Actions run at the beginning of their step, before the update:
  {"step", "op": "setAnimation"|"addAnimation"|"setEmptyAnimation"|"setSkin",
   "track", "name", "loop", "delay", "mix", "alpha", "additive"}
"""
import json
import os
import sys

# Steps of 1/31 s: sampled times never fall exactly on keyframes (exported at 30 fps),
# except whole seconds (steps 31, 62), which are not snapshotted
DT = 1.0 / 31.0
STEPS = 61
SNAPSHOTS = [1, 5, 12, 20, 30, 40, 50, 61]


def scenario(skeleton, name, actions, default_mix=0.0):
    return {
        'skeleton': skeleton,
        'name': name,
        'dt': DT,
        'steps': STEPS,
        'snapshots': SNAPSHOTS,
        'defaultMix': default_mix,
        'actions': actions,
    }


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        sys.exit(1)
    data_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    for folder in sorted(os.listdir(data_dir)):
        if not folder.endswith('.spine'):
            continue
        skeleton = folder[:-len('.spine')]
        path = os.path.join(data_dir, folder, skeleton + '.json')
        if not os.path.exists(path):
            continue
        data = json.load(open(path))
        animations = sorted(data.get('animations', {}).keys())
        skins = [s['name'] for s in data.get('skins', []) if s['name'] != 'default']
        if not animations:
            continue
        scenarios = []
        # Single animation (baseline of the runner itself)
        scenarios.append(scenario(skeleton, 'single', [
            {'step': 0, 'op': 'setAnimation', 'track': 0, 'name': animations[0], 'loop': True}]))
        if len(animations) >= 2:
            a, b = animations[0], animations[-1]
            # Crossfade from a to b in the middle, then back to a with an explicit mix
            scenarios.append(scenario(skeleton, 'crossfade', [
                {'step': 0, 'op': 'setAnimation', 'track': 0, 'name': a, 'loop': True},
                {'step': 15, 'op': 'setAnimation', 'track': 0, 'name': b, 'loop': True},
                {'step': 38, 'op': 'setAnimation', 'track': 0, 'name': a, 'loop': True, 'mix': 0.4}],
                default_mix=0.3))
            # Second track at half alpha, then additive, on top of the first one
            scenarios.append(scenario(skeleton, 'layered', [
                {'step': 0, 'op': 'setAnimation', 'track': 0, 'name': a, 'loop': True},
                {'step': 0, 'op': 'setAnimation', 'track': 1, 'name': b, 'loop': True, 'alpha': 0.5},
                {'step': 31, 'op': 'setAnimation', 'track': 1, 'name': b, 'loop': True, 'additive': True, 'alpha': 0.7},
                {'step': 50, 'op': 'setEmptyAnimation', 'track': 1, 'mix': 0.2}]))
            # Queued animations with delay
            scenarios.append(scenario(skeleton, 'queue', [
                {'step': 0, 'op': 'setAnimation', 'track': 0, 'name': b, 'loop': False},
                {'step': 0, 'op': 'addAnimation', 'track': 0, 'name': a, 'loop': True, 'delay': 0.3, 'mix': 0.25}]))
        if skins:
            actions = [{'step': 0, 'op': 'setAnimation', 'track': 0, 'name': animations[0], 'loop': True},
                       {'step': 0, 'op': 'setSkin', 'name': skins[0]}]
            if len(skins) >= 2:
                actions.append({'step': 31, 'op': 'setSkin', 'name': skins[1]})
            scenarios.append(scenario(skeleton, 'skins', actions))
        for s in scenarios:
            with open(os.path.join(out_dir, '%s__%s.json' % (skeleton, s['name'])), 'w') as f:
                json.dump(s, f, indent=1)
            count += 1
    print('%d scenario(s) in %s' % (count, out_dir))


if __name__ == '__main__':
    main()
