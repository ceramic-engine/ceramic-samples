package hscriptls;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds a file of `hscriptls/res` as a string literal at compile time (the
 * grammar): nothing to load at runtime, on the web or natively.
 */
class Embed {

    macro public static function resource(name:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('hscriptls/Embed.hx')));
        final path = haxe.io.Path.join([dir, 'res', name]);
        if (!sys.FileSystem.exists(path)) {
            Context.error('Missing resource: $path', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
