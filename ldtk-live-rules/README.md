# LDtk Live Rules

Paint IntGrid values of an LDtk level with the pointer and watch the auto-layers being recomputed at runtime,
with the same rule engine as the LDtk editor (`ldtk.rules`, provided by the `ldtk` plugin).

Left click paints the selected value, right click erases.

On macOS, browsers based on Chromium 130 and later (including Electron 33) deliver no mouse event at all while the
right button is held, so erasing by dragging is not possible there: select the `Empty` value (key `0`) and drag with
the left button instead. A right click still erases a single cell. The panel lets you change the brush, switch to fill,
toggle rule groups, regenerate the random seed and check that the runtime result matches the tiles saved by the editor.

This sample requires a Ceramic build that includes `ceramic.LdtkRuleRunner`.
