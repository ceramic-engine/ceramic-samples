package;

import ceramic.Spine;
import ceramic.Scene;

#if plugin_imgui
import imgui.ImGui;
import imgui.Helpers.*;
#end

using ceramic.SpinePlugin;

class SpineRaptor extends Scene {

    var spine:Spine;

    var shouldLoop:Map<String,Bool> = [
        Spines.RAPTOR_PRO.WALK => true
    ];
    
    override function preload() {
        
        assets.add(Spines.RAPTOR_PRO);

    }

    override function create() {

        spine = new Spine();
        spine.spineData = assets.spine(Spines.RAPTOR_PRO);
        spine.pos(screen.width * 0.5, screen.height * 0.85);
        spine.animation = Spines.RAPTOR_PRO.WALK;
        spine.loop = shouldLoop.exists(spine.animation);
        spine.skeletonScale = 0.33;
        add(spine);

    }

    override function update(delta:Float) {
        
        #if plugin_imgui

        ImGui.begin('Spine');
        ImGui.setWindowSize(ImVec2.create(0, 0));

        if (ImGui.beginCombo('Animation', spine.animation)) {
            for (anim in spine.spineData.skeletonData.animations) {
                var isSelected = (spine.animation == anim.name);
                if (ImGui.selectable(anim.name, isSelected)) {
                    spine.animation = anim.name;
                    spine.loop = shouldLoop.exists(spine.animation);
                }
                if (isSelected) {
                    ImGui.setItemDefaultFocus();
                }
            }
            ImGui.endCombo();
        }

        ImGui.end();

        #end

    }
    
}
