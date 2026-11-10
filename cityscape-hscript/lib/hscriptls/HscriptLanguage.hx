package hscriptls;

import cityscape.Cityscape;
import cityscape.base.common.RegExp;
import cityscape.common.languages.LanguageConfiguration;

/**
 * Registers the language `hscript` on a Cityscape context, like
 * `monaco.languages.register` + `setLanguageConfiguration` and a TextMate
 * grammar: the language id and extensions, the grammar of
 * `res/hscript.tmLanguage.json` (scopes named like the Haxe grammar's, so
 * VS Code's themes color it like Haxe), and the language configuration
 * (comments, brackets, auto closing pairs, indentation, on enter rules for
 * doc comments, folding markers).
 */
class HscriptLanguage {

    public static inline final LANGUAGE_ID = 'hscript';

    public static function grammar():String {
        return Embed.resource('hscript.tmLanguage.json');
    }

    public static function register(context:Cityscape):Void {
        if (context.languageService.isRegisteredLanguageId(LANGUAGE_ID)) {
            return;
        }
        context.languageService.registerLanguage({id: LANGUAGE_ID, extensions: ['.hscript', '.hxs'], aliases: ['hscript', 'HScript']});
        context.textMate.registerGrammar({languageId: LANGUAGE_ID, grammar: grammar(), path: 'hscript.tmLanguage.json'});
        context.languageConfigurationService.register(LANGUAGE_ID, configuration());
    }

    /**
     * The language configuration: Monaco's TypeScript one, which fits a
     * language with C-like syntax (hscript is a subset of Haxe), without
     * template strings.
     */
    public static function configuration():LanguageConfiguration {
        return {
            wordPattern: new RegExp("(-?\\d*\\.\\d\\w*)|([^`~!@#%^&*()\\-=+\\[{\\]}\\\\|;:'\",.<>/?\\s]+)", 'g'),
            comments: {
                lineComment: '//',
                blockComment: ['/*', '*/']
            },
            brackets: [['{', '}'], ['[', ']'], ['(', ')']],
            autoClosingPairs: [
                {open: '{', close: '}'},
                {open: '[', close: ']'},
                {open: '(', close: ')'},
                {open: '"', close: '"', notIn: ['string']},
                {open: "'", close: "'", notIn: ['string', 'comment']},
                {open: '/**', close: ' */', notIn: ['string']}
            ],
            surroundingPairs: [
                {open: '{', close: '}'},
                {open: '[', close: ']'},
                {open: '(', close: ')'},
                {open: '"', close: '"'},
                {open: "'", close: "'"}
            ],
            autoCloseBefore: ';:.,=}])> \n\t',
            indentationRules: {
                increaseIndentPattern: new RegExp("^((?!\\/\\/).)*(\\{([^}\"'`/]*|(\\t|[ ])*\\/\\/.*)|\\([^)\"'`/]*|\\[[^\\]\"'`/]*)$"),
                decreaseIndentPattern: new RegExp("^((?!.*?\\/\\*).*\\*\\/)?\\s*[\\}\\]].*$")
            },
            onEnterRules: [
                // `/** |*/` and `/**|`: a doc comment line
                {beforeText: new RegExp("^\\s*\\/\\*\\*(?!\\/)([^\\*]|\\*(?!\\/))*$"), afterText: new RegExp("^\\s*\\*\\/$"), action: {indentAction: IndentOutdent, appendText: ' * '}},
                {beforeText: new RegExp("^\\s*\\/\\*\\*(?!\\/)([^\\*]|\\*(?!\\/))*$"), action: {indentAction: None, appendText: ' * '}},
                // ` * |`: the next line of the comment
                {beforeText: new RegExp("^(\\t|[ ])*[ ]\\*([ ]([^\\*]|\\*(?!\\/))*)?$"), previousLineText: new RegExp("(?=^(\\s*(\\/\\*\\*|\\*)).*)(?=(?!(\\s*\\*\\/)))"), action: {indentAction: None, appendText: '* '}},
                // ` */|`: back to the code's indentation
                {beforeText: new RegExp("^(\\t|[ ])*[ ]\\*\\/\\s*$"), action: {indentAction: None, removeText: 1}}
            ],
            folding: {
                markers: {
                    start: new RegExp("^\\s*//\\s*#?region\\b"),
                    end: new RegExp("^\\s*//\\s*#?endregion\\b")
                }
            }
        };
    }

}
