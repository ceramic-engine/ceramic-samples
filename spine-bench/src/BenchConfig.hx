package;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Build configuration seen by the compiler, printed in the BENCH CONFIG line
 * so that two benchmark binaries can be checked for identical flags.
 */
class BenchConfig {

    /** Defines that change the generated code or the GC behaviour */
    macro public static function relevantDefines():Expr {

        var defines = Context.getDefines();
        var keys = [for (key in defines.keys()) key];
        keys.sort(Reflect.compare);
        var result = [];
        for (key in keys) {
            var lower = key.toLowerCase();
            if (lower.indexOf('hxcpp') != -1 || lower.indexOf('gc') != -1 || lower.indexOf('spine') != -1
                || lower.indexOf('simd') != -1 || lower.indexOf('inline') != -1 || lower.indexOf('debug') != -1
                || lower.indexOf('check') != -1 || lower == 'cppia' || lower == 'dce' || lower.indexOf('optim') != -1
                || lower.indexOf('safe') != -1 || lower == 'analyzer_optimize' || lower == 'no_traces') {
                var value = defines.get(key);
                result.push(value != null && value != '' && value != '1' ? key + '=' + value : key);
            }
        }
        return macro $v{result.join(' ')};

    }

}
