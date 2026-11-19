# Spine conformance

Checks what the Ceramic spine plugin sends to the renderer, with both spine runtimes:

- `legacy`: spine-hx (Spine 4.0), selected with the `spine_legacy` define, reads `data-40/`
- `default`: official spine-haxe (Spine 4.3), reads `data-43/`

Nothing is ever shown on screen: the app uses a hidden SDL window, is flagged as an
agent app (no Dock icon) and runs under `tools/window-guard.swift`, which kills it if a
window, a Dock icon or a focus change shows up.

## Data

The data sets are the official example exports of the spine-runtimes repository,
copied with `tools/prepare-data.py` (not versioned):

```
python3 tools/prepare-data.py <spine-runtimes branch 4.0>/examples data-40
python3 tools/prepare-data.py <spine-runtimes branch 4.3>/examples data-43
```

## Run

```
./run.sh legacy results/golden-legacy
```

Each skeleton animation is played with a fixed 1/30 s step. The meshes, clip shapes
and events of the spine visual are dumped at frames 0, 1, 7, 15 and 30.

## Web

The same dump runs in a browser:

```
ceramic clay build web --setup --assets
```

Then serve `project/web` and open `index.html`. The settings are read from the page URL
(`index.html?SPINE_CONFORMANCE_ONLY=spineboy-pro`), the files are kept in memory and
exposed as `window.spineConformance.files` (path -> content) when the run ends, and the
app stays open at the last step. Level A needs a directory of scenarios: it is not
available on web.

## Scenarios

- every animation of every skeleton, played alone;
- `_bindings`: what the Ceramic layer adds on top of the runtime (child spines bound to
  slots, visuals bound with `SpineBindVisual`, slot callbacks with custom transforms and
  `drawDefault`, hidden and disabled slots, color and alpha, forced tint black, hit test
  with a slot mesh, slot colors);
- `_bbox`: bounding box rendering and hit test. `SPINE_CONFORMANCE_SKIP_BBOX=1` skips it
  (the legacy plugin crashed on visible bounding boxes before it was fixed).

## Levels

- **Level A** (`./run-level-a.sh`): spine-haxe, built with the flags of a Ceramic app, against
  the official reference runtime (spine-libgdx, `reference-java/`), on generated scenarios
  (`tools/make-scenarios.py`: single animations, crossfades, additive tracks, queued
  animations, skins). Compares bone poses, slot attachments, sequence indices, colors,
  deforms and draw order.
- **Level B** (`reference-cpp/run-reference.sh` then `compare/compare_geometry.py`): what
  Ceramic sends to the renderer (meshes) against the official spine-cpp runtime.
- **Ceramic layer** (`compare/compare_bindings.py`): bindings and bounding box scenarios of
  the two runtimes.

## Legacy golden files

`goldens/legacy-40.sha256` holds the hashes of the legacy dumps recorded before the
spine plugin was changed. The legacy output must stay byte identical:

```
./run.sh legacy results/legacy-check
(cd results/legacy-check && shasum -a 256 -c ../../goldens/legacy-40.sha256)
```
