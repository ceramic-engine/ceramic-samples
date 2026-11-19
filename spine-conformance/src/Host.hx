package;

import ceramic.Platform;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * What the conformance app needs from its host, so that it also runs in a browser:
 *
 * - settings: environment variables, or the parameters of the page URL on web
 *   (`index.html?SPINE_CONFORMANCE_ONLY=spineboy-pro`);
 * - output files: written to disk, or kept in memory on web and exposed as
 *   `window.spineConformance.files` (path -> content) when the run ends;
 * - end of the run: the process exits, or the app stays open on web.
 */
class Host {

    /** `true` once the run ended on a host that cannot exit (web) */
    public static var finished(default, null):Bool = false;

    #if !sys
    static var files:haxe.DynamicAccess<String> = {};
    #end

    public static function env(name:String):String {

        var value = Platform.getEnv(name);
        #if (web && !ceramic_use_electron)
        if (value == null) {
            value = new js.html.URLSearchParams(js.Browser.location.search).get(name);
        }
        #end
        return value;

    }

    public static function save(dir:String, file:String, content:String):Void {

        #if sys
        if (!FileSystem.exists(dir))
            FileSystem.createDirectory(dir);
        File.saveContent(Path.join([dir, file]), content);
        #else
        files.set(Path.join([dir, file]), content);
        #end

    }

    public static function exit(code:Int):Void {

        #if sys
        Sys.exit(code);
        #else
        finished = true;
        #if js
        js.Syntax.code('window.spineConformance = { code: {0}, files: {1} }', code, files);
        #end
        #end

    }

}
