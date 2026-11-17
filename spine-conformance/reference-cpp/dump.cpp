// Reference dump of what a renderer should draw, computed with the official
// spine-cpp runtime (an implementation independent from spine-haxe).
//
// Usage: spine-reference-dump <skeleton.json|.skel> <atlas> <animation> <output.json> [fps]
//
// The skeleton is updated the same way as the Ceramic spine plugin does with the
// spine-haxe runtime: a first update without elapsed time (physics posed), then
// fixed steps (1/30 s by default, 1/fps when given). At steps 1, 7, 15 and 30, every slot of the applied draw order
// with a region or mesh attachment is written: world vertices (x, y), uvs, triangles,
// final color (skeleton * slot * attachment), dark color, blend mode and atlas page.
// Clipping attachments are applied in software, as official renderers do.
// Region vertices are written in spine-cpp order (starting at the bottom right
// corner), spine-haxe starts at the bottom left corner: the comparison handles it.

#include <spine/spine.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <locale.h>
#include <string>

using namespace spine;

namespace spine {
    SpineExtension *getDefaultExtension() {
        return new DefaultSpineExtension();
    }
}

// Keeps the page size declared in the atlas: uvs are computed from it
class ReferenceTextureLoader : public TextureLoader {
public:
    virtual void load(AtlasPage &page, const String &path) override {
        page.texture = &page;
    }
    virtual void unload(void *texture) override {}
};

static const int STEPS = 30;
static float DT = 1.0f / 30.0f;
static const int DUMP_STEPS[] = {1, 7, 15, 30};

static bool endsWith(const std::string &value, const std::string &suffix) {
    return value.size() >= suffix.size() && value.compare(value.size() - suffix.size(), suffix.size(), suffix) == 0;
}

static void writeFloats(FILE *out, const float *values, size_t count) {
    fputc('[', out);
    for (size_t i = 0; i < count; i++) {
        if (i) fputc(',', out);
        fprintf(out, "%.6f", values[i]);
    }
    fputc(']', out);
}

static void writeIndices(FILE *out, const unsigned short *values, size_t count) {
    fputc('[', out);
    for (size_t i = 0; i < count; i++) {
        if (i) fputc(',', out);
        fprintf(out, "%d", (int) values[i]);
    }
    fputc(']', out);
}

static void writeString(FILE *out, const char *value) {
    fputc('"', out);
    for (const char *c = value; *c; c++) {
        if (*c == '"' || *c == '\\') fputc('\\', out);
        fputc(*c, out);
    }
    fputc('"', out);
}

static void dumpFrame(FILE *out, Skeleton &skeleton, SkeletonClipping &clipper, int step, bool first) {
    static Array<float> worldVertices;

    if (!first) fputc(',', out);
    fprintf(out, "\n{\"step\":%d,\"time\":%.6f,\"items\":[", step, step * DT);

    Array<Slot *> &drawOrder = skeleton.getDrawOrder().getAppliedPose();
    Color &skeletonColor = skeleton.getColor();
    bool firstItem = true;

    for (size_t i = 0; i < drawOrder.size(); i++) {
        Slot *slot = drawOrder[i];
        if (!slot->getBone().isActive()) {
            clipper.clipEnd(*slot);
            continue;
        }
        SlotPose &pose = slot->getAppliedPose();
        Attachment *attachment = pose.getAttachment();
        if (attachment == NULL) {
            clipper.clipEnd(*slot);
            continue;
        }

        if (attachment->getRTTI().isExactly(ClippingAttachment::rtti)) {
            ClippingAttachment *clip = static_cast<ClippingAttachment *>(attachment);
            clipper.clipStart(skeleton, *slot, clip);
            if (getenv("SPINE_REFERENCE_DEBUG_CLIP") != NULL) {
                size_t n = clip->getWorldVerticesLength();
                Array<float> polygon;
                polygon.setSize(n, 0);
                clip->computeWorldVertices(skeleton, *slot, 0, n, polygon.buffer(), 0, 2);
                fprintf(stderr, "step %d clip %s:", step, slot->getData().getName().buffer());
                for (size_t k = 0; k < n; k++) fprintf(stderr, " %.0f", polygon[k]);
                BonePose &bone = slot->getBone().getAppliedPose();
                fprintf(stderr, " | bone %s a=%.3f b=%.3f c=%.3f d=%.3f x=%.1f y=%.1f\n", slot->getBone().getData().getName().buffer(), bone.getA(), bone.getB(), bone.getC(), bone.getD(), bone.getWorldX(), bone.getWorldY());
            }
            continue;
        }

        const char *type = NULL;
        Array<float> *uvs = NULL;
        unsigned short *triangles = NULL;
        size_t trianglesCount = 0;
        size_t verticesCount = 0;
        Color *attachmentColor = NULL;
        TextureRegion *region = NULL;
        static unsigned short quadTriangles[6] = {0, 1, 2, 2, 3, 0};

        if (attachment->getRTTI().isExactly(RegionAttachment::rtti)) {
            RegionAttachment *regionAttachment = static_cast<RegionAttachment *>(attachment);
            Sequence &sequence = regionAttachment->getSequence();
            int index = sequence.resolveIndex(pose);
            worldVertices.setSize(8, 0);
            regionAttachment->computeWorldVertices(*slot, regionAttachment->getOffsets(pose), worldVertices, 0, 2);
            verticesCount = 8;
            uvs = &sequence.getUVs(index);
            triangles = quadTriangles;
            trianglesCount = 6;
            attachmentColor = &regionAttachment->getColor();
            region = sequence.getRegion(index);
            type = "region";
        }
        else if (attachment->getRTTI().isExactly(MeshAttachment::rtti)) {
            MeshAttachment *mesh = static_cast<MeshAttachment *>(attachment);
            Sequence &sequence = mesh->getSequence();
            int index = sequence.resolveIndex(pose);
            verticesCount = mesh->getWorldVerticesLength();
            worldVertices.setSize(verticesCount, 0);
            mesh->computeWorldVertices(skeleton, *slot, 0, verticesCount, worldVertices.buffer(), 0, 2);
            uvs = &sequence.getUVs(index);
            triangles = mesh->getTriangles().buffer();
            trianglesCount = mesh->getTriangles().size();
            attachmentColor = &mesh->getColor();
            region = sequence.getRegion(index);
            type = "mesh";
        }
        else {
            clipper.clipEnd(*slot);
            continue;
        }

        float *vertices = worldVertices.buffer();
        float *uvsBuffer = uvs->buffer();
        bool clipped = false;
        if (clipper.isClipping()) {
            // Like the spine-cpp SkeletonRenderer: the clipped output is always used while
            // clipping (the return value of clipTriangles is false when every triangle is
            // outside, the output is then empty)
            clipper.clipTriangles(vertices, triangles, trianglesCount, uvsBuffer, 2);
            clipped = true;
            vertices = clipper.getClippedVertices().buffer();
            verticesCount = clipper.getClippedVertices().size();
            uvsBuffer = clipper.getClippedUVs().buffer();
            triangles = clipper.getClippedTriangles().buffer();
            trianglesCount = clipper.getClippedTriangles().size();
        }

        Color &slotColor = pose.getColor();
        float r = skeletonColor.r * slotColor.r * attachmentColor->r;
        float g = skeletonColor.g * slotColor.g * attachmentColor->g;
        float b = skeletonColor.b * slotColor.b * attachmentColor->b;
        float a = skeletonColor.a * slotColor.a * attachmentColor->a;

        if (!firstItem) fputc(',', out);
        firstItem = false;
        fprintf(out, "\n {\"slot\":");
        writeString(out, slot->getData().getName().buffer());
        fprintf(out, ",\"type\":\"%s\",\"attachment\":", type);
        writeString(out, attachment->getName().buffer());
        fprintf(out, ",\"blend\":%d,\"page\":", (int) slot->getData().getBlendMode());
        AtlasRegion *atlasRegion = region != NULL ? static_cast<AtlasRegion *>(region) : NULL;
        if (atlasRegion != NULL && atlasRegion->getPage() != NULL) writeString(out, atlasRegion->getPage()->name.buffer());
        else fprintf(out, "null");
        fprintf(out, ",\"clipped\":%s,\"color\":[%.6f,%.6f,%.6f,%.6f],\"dark\":", clipped ? "true" : "false", r, g, b, a);
        if (pose.hasDarkColor()) {
            Color &dark = pose.getDarkColor();
            fprintf(out, "[%.6f,%.6f,%.6f,%.6f]", dark.r, dark.g, dark.b, dark.a);
        }
        else {
            fprintf(out, "null");
        }
        fprintf(out, ",\"vertices\":");
        writeFloats(out, vertices, verticesCount);
        fprintf(out, ",\"uvs\":");
        writeFloats(out, uvsBuffer, verticesCount);
        fprintf(out, ",\"triangles\":");
        writeIndices(out, triangles, trianglesCount);
        fputc('}', out);

        clipper.clipEnd(*slot);
    }
    clipper.clipEnd();

    fprintf(out, "]}");
}

int main(int argc, char *argv[]) {
    setlocale(LC_ALL, "C");

    if (argc != 5 && argc != 6) {
        fprintf(stderr, "Usage: spine-reference-dump <skeleton.json|.skel> <atlas> <animation> <output.json> [fps]\n");
        return 1;
    }
    if (argc == 6) DT = 1.0f / (float) atoi(argv[5]);
    std::string skeletonPath = argv[1];
    const char *atlasPath = argv[2];
    const char *animationName = argv[3];
    const char *outputPath = argv[4];

    // Spine's own coordinate system (y up), which the Ceramic plugin keeps (spine-cpp defaults to y down)
    Bone::setYDown(false);

    ReferenceTextureLoader textureLoader;
    Atlas atlas(atlasPath, &textureLoader);
    AtlasAttachmentLoader attachmentLoader(atlas);

    SkeletonData *skeletonData = NULL;
    if (endsWith(skeletonPath, ".skel")) {
        SkeletonBinary binary(attachmentLoader);
        skeletonData = binary.readSkeletonDataFile(skeletonPath.c_str());
        if (skeletonData == NULL) {
            fprintf(stderr, "Failed to read %s: %s\n", skeletonPath.c_str(), binary.getError().buffer());
            return 1;
        }
    }
    else {
        SkeletonJson json(attachmentLoader);
        skeletonData = json.readSkeletonDataFile(skeletonPath.c_str());
        if (skeletonData == NULL) {
            fprintf(stderr, "Failed to read %s: %s\n", skeletonPath.c_str(), json.getError().buffer());
            return 1;
        }
    }

    Animation *animation = skeletonData->findAnimation(animationName);
    if (animation == NULL) {
        fprintf(stderr, "Animation not found: %s\n", animationName);
        return 1;
    }

    Skeleton skeleton(*skeletonData);
    AnimationStateData stateData(*skeletonData);
    AnimationState state(stateData);
    SkeletonClipping clipper;

    skeleton.setupPose();
    state.setAnimation(0, *animation, true);

    // First update without elapsed time
    state.update(0);
    state.apply(skeleton);
    skeleton.update(0);
    skeleton.updateWorldTransform(Physics_Pose);

    FILE *out = fopen(outputPath, "w");
    if (out == NULL) {
        fprintf(stderr, "Cannot write %s\n", outputPath);
        return 1;
    }
    fprintf(out, "{\"skeleton\":");
    writeString(out, skeletonPath.c_str());
    fprintf(out, ",\"animation\":");
    writeString(out, animationName);
    fprintf(out, ",\"frames\":[");

    bool first = true;
    size_t nextDump = 0;
    for (int step = 1; step <= STEPS; step++) {
        state.update(DT);
        state.apply(skeleton);
        skeleton.update(DT);
        skeleton.updateWorldTransform(Physics_Update);
        if (nextDump < sizeof(DUMP_STEPS) / sizeof(DUMP_STEPS[0]) && DUMP_STEPS[nextDump] == step) {
            dumpFrame(out, skeleton, clipper, step, first);
            first = false;
            nextDump++;
        }
    }

    fprintf(out, "\n]}\n");
    fclose(out);

    delete skeletonData;
    return 0;
}
