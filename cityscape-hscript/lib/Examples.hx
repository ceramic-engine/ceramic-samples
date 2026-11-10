package;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * The example scripts of the toolbar: the files of `scripts/`, embedded at
 * compile time (no asset loading, the same on the web and natively).
 */
class Examples {

    /**
     * The order of the toolbar; other files come after, sorted by name.
     */
    static final ORDER = ['Spiral', 'Tree', 'Starfield', 'Mistakes'];

    public static function all():Array<{name:String, code:String}> {
        final files:Map<String, String> = embed();
        final names = [for (name in files.keys()) name];
        names.sort((a, b) -> {
            final ia = ORDER.indexOf(a);
            final ib = ORDER.indexOf(b);
            if (ia >= 0 && ib >= 0) return ia - ib;
            if (ia >= 0) return -1;
            if (ib >= 0) return 1;
            return a < b ? -1 : 1;
        });
        return [for (name in names) {name: name, code: files.get(name)}];
    }

    macro static function embed():Expr {
        final dir = haxe.io.Path.join([haxe.io.Path.directory(Context.resolvePath('Examples.hx')), '..', 'scripts']);
        final entries:Array<Expr> = [];
        final files = sys.FileSystem.readDirectory(dir);
        files.sort(Reflect.compare);
        for (file in files) {
            if (!StringTools.endsWith(file, '.hscript')) {
                continue;
            }
            final path = haxe.io.Path.join([dir, file]);
            Context.registerModuleDependency(Context.getLocalModule(), path);
            final name = haxe.io.Path.withoutExtension(file);
            final code = StringTools.replace(sys.io.File.getContent(path), '\r\n', '\n');
            entries.push(macro $v{name} => $v{code});
        }
        return macro $a{entries};
    }

}
