#!/usr/bin/env python3
"""
Collects the call stacks of the hxcpp allocator slow path (a new hole or block
taken by a local allocator, or a large allocation) in a running bench app, to
find what allocates once the app is warmed up.

Usage (run through the window guard, the app window stays hidden):
    xcrun python3 tools/alloc-stacks.py <app binary> <warmup seconds> <stack count> <output file>

The app environment (SPINE_BENCH_SCENARIO...) is inherited. Each hit records the
first frames that are not in the allocator itself. Stacks are grouped and
counted at the end of the output file.
"""

import collections
import os
import sys
import time

lldb_python = os.popen('lldb -P').read().strip()
sys.path.insert(0, lldb_python)
import lldb  # noqa: E402

SKIP = ('CallAlloc', 'InternalNew', 'ImmixAllocator', 'LocalAllocator', 'hx::NewGC', 'NewGCBytes',
        'NewGCPrivate', 'operator new', 'InternalRealloc', 'GetFreeBlock', 'AllocLarge', '::alloc(')


def main():
    binary, warmup, count, out_path = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), sys.argv[4]

    debugger = lldb.SBDebugger.Create()
    debugger.SetAsync(True)
    target = debugger.CreateTarget(binary)
    env = ['%s=%s' % (k, v) for k, v in os.environ.items()]
    error = lldb.SBError()
    listener = debugger.GetListener()
    process = target.Launch(listener, None, env, None, None, None, os.getcwd(), 0, False, error)
    if not error.Success():
        print('launch failed: %s' % error)
        return 1

    def wait_state(states, timeout=30):
        end = time.time() + timeout
        event = lldb.SBEvent()
        while time.time() < end:
            if listener.WaitForEvent(1, event):
                state = lldb.SBProcess.GetStateFromEvent(event)
                if state in states:
                    return state
            elif process.GetState() in states:
                return process.GetState()
        return None

    wait_state([lldb.eStateRunning])
    time.sleep(warmup)
    process.Stop()
    wait_state([lldb.eStateStopped])

    # Slow path of the inline bump allocation (new hole or block), large allocations
    bps = [target.BreakpointCreateByName('LocalAllocator::CallAlloc'),
           target.BreakpointCreateByName('GlobalAllocator::AllocLarge')]
    for bp in bps:
        print('breakpoint %s: %d location(s)' % (bp, bp.GetNumLocations()))

    stacks = collections.Counter()
    hits = 0
    with open(out_path, 'w') as out:
        process.Continue()
        while hits < count:
            state = wait_state([lldb.eStateStopped, lldb.eStateExited], timeout=60)
            if state != lldb.eStateStopped:
                break
            for thread in process:
                if thread.GetStopReason() != lldb.eStopReasonBreakpoint:
                    continue
                frames = []
                inner = []
                for frame in thread:
                    name = frame.GetFunctionName() or '?'
                    if any(s in name for s in SKIP):
                        if not frames:
                            inner.append(name.split('(')[0])
                        continue
                    if not frames:
                        # Allocator calls made by this frame, and the return address offset
                        fileAddress = frame.GetPCAddress().GetFileAddress()
                        name = '%s @0x%x  [via %s]' % (name, fileAddress, ' < '.join(inner))
                    line = frame.GetLineEntry()
                    if line.IsValid() and line.GetFileSpec().GetFilename():
                        name = '%s  (%s:%d)' % (name, line.GetFileSpec().GetFilename(), line.GetLine())
                    frames.append(name)
                    if len(frames) >= 6:
                        break
                key = '\n    '.join(frames)
                stacks[key] += 1
                hits += 1
                out.write('#%d thread %d\n    %s\n' % (hits, thread.GetIndexID(), key))
            process.Continue()
        out.write('\n==== grouped (%d hits) ====\n' % hits)
        for key, n in stacks.most_common():
            out.write('%d x\n    %s\n' % (n, key))
    process.Kill()
    return 0


if __name__ == '__main__':
    sys.exit(main())
