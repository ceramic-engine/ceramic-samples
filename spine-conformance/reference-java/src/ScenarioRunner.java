import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Locale;

import com.badlogic.gdx.ApplicationAdapter;
import com.badlogic.gdx.files.FileHandle;
import com.badlogic.gdx.backends.headless.HeadlessApplication;
import com.badlogic.gdx.backends.headless.HeadlessApplicationConfiguration;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureAtlas;
import com.badlogic.gdx.utils.FloatArray;
import com.badlogic.gdx.utils.JsonReader;
import com.badlogic.gdx.utils.JsonValue;

import com.esotericsoftware.spine.AnimationState;
import com.esotericsoftware.spine.AnimationState.TrackEntry;
import com.esotericsoftware.spine.AnimationStateData;
import com.esotericsoftware.spine.Bone;
import com.esotericsoftware.spine.BonePose;
import com.esotericsoftware.spine.Physics;
import com.esotericsoftware.spine.Skeleton;
import com.esotericsoftware.spine.SkeletonBinary;
import com.esotericsoftware.spine.SkeletonData;
import com.esotericsoftware.spine.SkeletonJson;
import com.esotericsoftware.spine.Slot;
import com.esotericsoftware.spine.SlotPose;
import com.esotericsoftware.spine.attachments.Attachment;

/**
 * Level A reference: plays a scenario (see tools/make-scenarios.py) with the official
 * spine-libgdx runtime and writes the skeleton state at the snapshot steps.
 *
 * Usage: ScenarioRunner <data-dir> <scenarios-dir> <output-dir>
 *
 * The update sequence is the one of the Ceramic spine plugin with spine-haxe: actions of
 * the step, state.update(dt), state.apply(skeleton), skeleton.update(dt),
 * skeleton.updateWorldTransform(Physics.update).
 */
public class ScenarioRunner extends ApplicationAdapter {

	final String dataDir, scenariosDir, outputDir;

	ScenarioRunner (String dataDir, String scenariosDir, String outputDir) {
		this.dataDir = dataDir;
		this.scenariosDir = scenariosDir;
		this.outputDir = outputDir;
	}

	static class MockTexture extends Texture {
		final int width, height;

		MockTexture (int width, int height) {
			super();
			this.width = width;
			this.height = height;
		}

		public int getWidth () {
			return width;
		}

		public int getHeight () {
			return height;
		}

		public void bind () {
		}

		public void bind (int unit) {
		}

		public void dispose () {
		}
	}

	/** Atlas without textures (same as the HeadlessTest of spine-libgdx-tests). */
	static class HeadlessTextureAtlas extends TextureAtlas {
		HeadlessTextureAtlas (FileHandle packFile) {
			TextureAtlasData data = new TextureAtlasData(packFile, packFile.parent(), false);
			for (TextureAtlasData.Page page : data.getPages())
				page.texture = new MockTexture((int)page.width, (int)page.height);
			for (TextureAtlasData.Region region : data.getRegions()) {
				AtlasRegion atlasRegion = new AtlasRegion(region.page.texture, region.left, region.top,
					region.rotate ? region.height : region.width, region.rotate ? region.width : region.height);
				atlasRegion.index = region.index;
				atlasRegion.name = region.name;
				atlasRegion.offsetX = region.offsetX;
				atlasRegion.offsetY = region.offsetY;
				atlasRegion.originalHeight = region.originalHeight;
				atlasRegion.originalWidth = region.originalWidth;
				atlasRegion.rotate = region.rotate;
				atlasRegion.degrees = region.degrees;
				atlasRegion.names = region.names;
				atlasRegion.values = region.values;
				if (region.flip) atlasRegion.flip(false, true);
				getRegions().add(atlasRegion);
			}
		}
	}

	public void create () {
		try {
			File[] files = new File(scenariosDir).listFiles();
			java.util.Arrays.sort(files);
			new File(outputDir).mkdirs();
			int count = 0;
			for (File file : files) {
				if (!file.getName().endsWith(".json")) continue;
				run(file);
				count++;
			}
			System.out.println("Level A reference: " + count + " scenario(s)");
		} catch (Throwable ex) {
			ex.printStackTrace();
			System.exit(1);
		}
		System.exit(0);
	}

	void run (File scenarioFile) throws IOException {
		JsonValue scenario = new JsonReader().parse(new FileHandle(scenarioFile));
		String skeletonName = scenario.getString("skeleton");
		File folder = new File(dataDir, skeletonName + ".spine");
		File atlasFile = null;
		for (File f : folder.listFiles())
			if (f.getName().endsWith(".atlas")) atlasFile = f;
		TextureAtlas atlas = new HeadlessTextureAtlas(new FileHandle(atlasFile));

		SkeletonData data;
		File json = new File(folder, skeletonName + ".json");
		if (json.exists())
			data = new SkeletonJson(atlas).readSkeletonData(new FileHandle(json));
		else
			data = new SkeletonBinary(atlas).readSkeletonData(new FileHandle(new File(folder, skeletonName + ".skel")));

		Skeleton skeleton = new Skeleton(data);
		AnimationStateData stateData = new AnimationStateData(data);
		stateData.setDefaultMix(scenario.getFloat("defaultMix", 0));
		AnimationState state = new AnimationState(stateData);
		skeleton.setupPose();
		skeleton.updateWorldTransform(Physics.pose);
		if (System.getenv("SPINE_REFERENCE_DEBUG_SEQUENCE") != null) {
			Slot debugSlot = skeleton.getSlots().get(skeleton.getSlots().size - 1);
			System.err.println("after setupPose: slot " + debugSlot.getData().getName() + " pose=" + debugSlot.getPose().getSequenceIndex()
				+ " applied=" + debugSlot.getAppliedPose().getSequenceIndex() + " data=" + debugSlot.getData().getSetupPose().getSequenceIndex());
		}

		float dt = scenario.getFloat("dt");
		int steps = scenario.getInt("steps");
		int[] snapshots = scenario.get("snapshots").asIntArray();
		JsonValue actions = scenario.get("actions");

		StringBuilder out = new StringBuilder();
		out.append("{\"skeleton\":").append(quote(skeletonName)).append(",\"scenario\":")
			.append(quote(scenario.getString("name"))).append(",\"snapshots\":[");
		boolean firstSnapshot = true;

		for (int step = 0; step <= steps; step++) {
			for (JsonValue action = actions.child; action != null; action = action.next) {
				if (action.getInt("step") != step) continue;
				apply(action, skeleton, state);
			}
			if (step > 0) {
				state.update(dt);
				state.apply(skeleton);
				skeleton.update(dt);
				skeleton.updateWorldTransform(Physics.update);
			} else {
				state.update(0);
				state.apply(skeleton);
				skeleton.update(0);
				skeleton.updateWorldTransform(Physics.pose);
			}
			for (int s : snapshots) {
				if (s != step) continue;
				if (!firstSnapshot) out.append(',');
				firstSnapshot = false;
				snapshot(out, skeleton, step);
			}
		}
		out.append("]}\n");

		File outFile = new File(outputDir, scenarioFile.getName());
		try (FileWriter writer = new FileWriter(outFile)) {
			writer.write(out.toString());
		}
	}

	static void apply (JsonValue action, Skeleton skeleton, AnimationState state) {
		String op = action.getString("op");
		int track = action.getInt("track", 0);
		TrackEntry entry = null;
		switch (op) {
		case "setAnimation" -> entry = state.setAnimation(track, action.getString("name"), action.getBoolean("loop", false));
		case "addAnimation" -> entry = state.addAnimation(track, action.getString("name"), action.getBoolean("loop", false),
			action.getFloat("delay", 0));
		case "setEmptyAnimation" -> entry = state.setEmptyAnimation(track, action.getFloat("mix", 0));
		case "setSkin" -> {
			skeleton.setSkin(action.getString("name"));
			skeleton.setupPoseSlots();
		}
		default -> throw new RuntimeException("Unknown action: " + op);
		}
		if (entry != null && !op.equals("setEmptyAnimation")) {
			if (action.has("mix")) entry.setMixDuration(action.getFloat("mix"));
			if (action.has("alpha")) entry.setAlpha(action.getFloat("alpha"));
			if (action.has("additive")) entry.setAdditive(action.getBoolean("additive"));
		}
	}

	static void snapshot (StringBuilder out, Skeleton skeleton, int step) {
		out.append("\n{\"step\":").append(step).append(",\"bones\":[");
		for (int i = 0; i < skeleton.getBones().size; i++) {
			if (i > 0) out.append(',');
			BonePose p = skeleton.getBones().get(i).getAppliedPose();
			out.append('[');
			num(out, p.getX()).append(',');
			num(out, p.getY()).append(',');
			num(out, p.getRotation()).append(',');
			num(out, p.getScaleX()).append(',');
			num(out, p.getScaleY()).append(',');
			num(out, p.getShearX()).append(',');
			num(out, p.getShearY()).append(',');
			num(out, p.getA()).append(',');
			num(out, p.getB()).append(',');
			num(out, p.getC()).append(',');
			num(out, p.getD()).append(',');
			num(out, p.getWorldX()).append(',');
			num(out, p.getWorldY()).append(']');
		}
		out.append("],\"slots\":[");
		for (int i = 0; i < skeleton.getSlots().size; i++) {
			if (i > 0) out.append(',');
			Slot slot = skeleton.getSlots().get(i);
			SlotPose p = slot.getAppliedPose();
			Attachment attachment = slot.getBone().isActive() ? p.getAttachment() : null;
			out.append("{\"a\":").append(quote(attachment == null ? null : attachment.getName()));
			out.append(",\"s\":").append(p.getSequenceIndex());
			out.append(",\"c\":[");
			num(out, p.getColor().r).append(',');
			num(out, p.getColor().g).append(',');
			num(out, p.getColor().b).append(',');
			num(out, p.getColor().a).append(']');
			FloatArray deform = p.getDeform();
			out.append(",\"f\":[");
			for (int d = 0; d < deform.size; d++) {
				if (d > 0) out.append(',');
				num(out, deform.get(d));
			}
			out.append("]}");
		}
		out.append("],\"o\":[");
		for (int i = 0; i < skeleton.getDrawOrder().getAppliedPose().size; i++) {
			if (i > 0) out.append(',');
			out.append(skeleton.getDrawOrder().getAppliedPose().get(i).getData().getIndex());
		}
		out.append("]}");
	}

	static StringBuilder num (StringBuilder out, float value) {
		return out.append(String.format(Locale.ROOT, "%.6f", value));
	}

	static String quote (String value) {
		return value == null ? "null" : "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
	}

	public static void main (String[] args) {
		if (args.length != 3) {
			System.err.println("Usage: ScenarioRunner <data-dir> <scenarios-dir> <output-dir>");
			System.exit(1);
		}
		new HeadlessApplication(new ScenarioRunner(args[0], args[1], args[2]), new HeadlessApplicationConfiguration());
	}
}
