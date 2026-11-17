package;

import ceramic.Color;
import ceramic.IntBoolMap;
import ceramic.Quad;
import ceramic.Spine;
import ceramic.SpineBindVisual;
import ceramic.SpineBindVisualOptions;
import ceramic.SpineColors;
import ceramic.SpineData;
import ceramic.Transform;

/**
 * Everything the Ceramic spine layer offers on top of the runtime, on spineboy:
 * child spines bound to slots (whole spine and slot to slot), visuals bound with
 * SpineBindVisual, slot callbacks with custom transforms, hidden/disabled slots,
 * color and alpha, forced tint black, bounding box hit test and slot colors.
 * (Dark colors are not extracted: spineboy has no tint black slot, and the
 * legacy extraction fails on slots without dark color.)
 */
class BindingsScenario {

    public var root:Spine;

    /** Child spine following the `gun` slot of the root */
    public var gunChild:Spine;

    /** Child spine whose `head` slot follows the `front-fist` slot of the root */
    public var fistChild:Spine;

    /** Quad bound to the `head` slot (mesh attachment) */
    public var headQuad:Quad;

    /** Quad bound to the `gun` slot (region attachment), compensating the region rotation */
    public var gunQuad:Quad;

    /** Spine hit tested with the mesh of its `head` slot */
    public var slotHitSpine:Spine;

    /** Separate spine used to extract slot colors (extraction forces a render) */
    public var colorsSpine:Spine;

    public var frames:Array<Dynamic> = [];

    public var events:Array<Dynamic> = [];

    var slotInfoLog:Array<Dynamic> = [];

    static final COLOR_SLOTS = ['gun', 'head', 'muzzle-glow', 'portal-flare1', 'front-fist'];

    public function new(spineData:SpineData) {

        root = new Spine();
        root.spineData = spineData;
        root.autoUpdate = false;
        root.autoFreeze = false;
        root.renderWhenInvisible = true;
        root.skeletonScale = 0.5;
        root.pos(512, 700);
        root.color = Color.fromRGB(200, 220, 255);
        root.alpha = 0.8;
        
        root.hiddenSlots = new IntBoolMap();
        root.hiddenSlots.set(Spine.globalSlotIndexForName('goggles'), true);
        root.disabledSlots = new IntBoolMap();
        root.disabledSlots.set(Spine.globalSlotIndexForName('mouth'), true);

        // Slot callback with a custom transform
        root.onUpdateSlotWithName(null, 'front-fist', info -> {
            var custom = new Transform();
            custom.rotate(0.3);
            custom.translate(4, -2);
            info.customTransform = custom;
        });

        // Slot callback hiding a slot (drawDefault)
        root.onUpdateSlotWithName(null, 'rear-bracer', info -> {
            info.drawDefault = false;
        });

        // Record what the generic slot callback receives for a few slots
        root.onUpdateSlot(null, info -> {
            if (info.globalSlotIndex == Spine.globalSlotIndexForName('gun') || info.globalSlotIndex == Spine.globalSlotIndexForName('head')) {
                var t = info.transform;
                slotInfoLog.push({
                    slot: Spine.globalSlotIndexForName('gun') == info.globalSlotIndex ? 'gun' : 'head',
                    depth: info.depth,
                    drawDefault: info.drawDefault,
                    transform: [t.a, t.b, t.c, t.d, t.tx, t.ty]
                });
            }
        });

        root.onSpineEvent(null, (entry, event) -> {
            events.push({ name: #if spine_legacy event.getData().name #else event.data.name #end, time: event.time });
        });

        root.computeContent();
        root.animate('run', true);
        root.animate('aim', true, 1);

        // Child spine following a slot of the parent
        gunChild = new Spine();
        gunChild.spineData = spineData;
        gunChild.autoFreeze = false;
        gunChild.skeletonScale = 0.3;
        root.add(gunChild);
        gunChild.bindParentSlot('gun');
        gunChild.computeContent();
        gunChild.animate('idle', true);

        // Child spine with one of its slots following a slot of the parent
        fistChild = new Spine();
        fistChild.spineData = spineData;
        fistChild.autoFreeze = false;
        fistChild.forceTintBlack = true;
        root.add(fistChild);
        fistChild.bindParentSlot('front-fist', { toLocalSlot: 'head', flipXOnConcat: true });
        fistChild.computeContent();
        fistChild.animate('walk', true);

        // Visuals bound to slots
        headQuad = new Quad();
        headQuad.size(20, 10);
        SpineBindVisual.bindVisual(root, 'head', headQuad, 10, 5);

        gunQuad = new Quad();
        gunQuad.size(8, 8);
        var gunOptions:SpineBindVisualOptions = SpineBindVisual.bindVisual(root, 'gun', gunQuad);
        gunOptions.compensateRegionRotation = true;

        slotHitSpine = new Spine();
        slotHitSpine.spineData = spineData;
        slotHitSpine.autoUpdate = false;
        slotHitSpine.autoFreeze = false;
        slotHitSpine.renderWhenInvisible = true;
        slotHitSpine.skeletonScale = 0.5;
        slotHitSpine.pos(300, 700);
        slotHitSpine.hitWithSlotIndex = spineData.findSlotIndex('head');
        slotHitSpine.computeContent();
        slotHitSpine.animate('idle', true);

        colorsSpine = new Spine();
        colorsSpine.spineData = spineData;
        colorsSpine.autoUpdate = false;
        colorsSpine.autoFreeze = false;
        colorsSpine.renderWhenInvisible = true;
        colorsSpine.computeContent();
        colorsSpine.animate('portal', true);

    }

    public function update(dt:Float):Void {

        root.update(dt);
        slotHitSpine.update(dt);
        colorsSpine.update(dt);

    }

    public function dump(step:Int, time:Float):Dynamic {


        // Hit test against the mesh of the head slot, on a grid around the spine
        var slotHits = new StringBuf();
        var hy = 300;
        while (hy <= 700) {
            var hx = 150;
            while (hx <= 450) {
                slotHits.add(slotHitSpine.hits(hx, hy) ? '1' : '0');
                hx += 15;
            }
            slotHits.add('|');
            hy += 20;
        }

        var colors = SpineColors.extractColors(colorsSpine, COLOR_SLOTS);

        var result = {
            step: step,
            time: time,
            slotHits: slotHits.toString(),
            colors: [for (c in colors) (c:Int)],
            slotInfos: slotInfoLog,
            root: ConformanceScene.dumpChildren(root),
            gunChildTransform: transformArray(gunChild.transform),
            gunChildDepth: gunChild.depth,
            gunChildDepthRange: gunChild.depthRange
        };
        slotInfoLog = [];
        return result;

    }

    static function transformArray(t:Transform):Array<Float> {

        return t == null ? null : [t.a, t.b, t.c, t.d, t.tx, t.ty];

    }

}
