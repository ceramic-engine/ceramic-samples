package;

import tracker.Model;

/**
 * The settings of the application: a tracker model.
 *
 * Every `@observe` field is tracked: a component that reads one during its
 * `render` is drawn again when the field changes. There is no event to wire
 * and nothing to notify, assigning the field is enough.
 */
class Settings extends Model {

    // General

    @observe public var displayName:String = 'Jane Doe';

    @observe public var language:String = 'en';

    @observe public var theme:String = 'dark';

    @observe public var autosave:Bool = true;

    /** Minutes between two automatic saves (only used when `autosave` is on). */
    @observe public var autosaveInterval:Int = 5;

    // Editor

    @observe public var fontSize:Float = 14;

    @observe public var tabSize:Int = 4;

    @observe public var wordWrap:Bool = true;

    /** Extra spaces in front of wrapped lines (only used when `wordWrap` is on). */
    @observe public var wrapIndent:Int = 2;

    @observe public var lineNumbers:Bool = true;

    // Advanced

    @observe public var hardwareAcceleration:Bool = true;

    @observe public var telemetry:Bool = false;

    @observe public var cacheSize:Int = 512;

    @observe public var logLevel:String = 'warning';

    /** The default values, for `changedCount` and `restoreDefaults()` (created on first use: a model needs the app to be ready). */
    static var DEFAULTS(get, null):Settings;

    static function get_DEFAULTS():Settings {
        if (DEFAULTS == null) DEFAULTS = new Settings();
        return DEFAULTS;
    }

    public function new() {
        super();
    }

    /**
     * How many settings differ from their default.
     *
     * A `@compute` function is read as a property (`settings.changedCount`): it is cached and recomputed only when one of the
     * observables it reads changes; reading it in a `render` tracks it like
     * a field.
     */
    @compute public function changedCount():Int {
        var count = 0;
        if (displayName != DEFAULTS.displayName) count++;
        if (language != DEFAULTS.language) count++;
        if (theme != DEFAULTS.theme) count++;
        if (autosave != DEFAULTS.autosave) count++;
        if (autosaveInterval != DEFAULTS.autosaveInterval) count++;
        if (fontSize != DEFAULTS.fontSize) count++;
        if (tabSize != DEFAULTS.tabSize) count++;
        if (wordWrap != DEFAULTS.wordWrap) count++;
        if (wrapIndent != DEFAULTS.wrapIndent) count++;
        if (lineNumbers != DEFAULTS.lineNumbers) count++;
        if (hardwareAcceleration != DEFAULTS.hardwareAcceleration) count++;
        if (telemetry != DEFAULTS.telemetry) count++;
        if (cacheSize != DEFAULTS.cacheSize) count++;
        if (logLevel != DEFAULTS.logLevel) count++;
        return count;
    }

    public function restoreDefaults():Void {
        displayName = DEFAULTS.displayName;
        language = DEFAULTS.language;
        theme = DEFAULTS.theme;
        autosave = DEFAULTS.autosave;
        autosaveInterval = DEFAULTS.autosaveInterval;
        fontSize = DEFAULTS.fontSize;
        tabSize = DEFAULTS.tabSize;
        wordWrap = DEFAULTS.wordWrap;
        wrapIndent = DEFAULTS.wrapIndent;
        lineNumbers = DEFAULTS.lineNumbers;
        hardwareAcceleration = DEFAULTS.hardwareAcceleration;
        telemetry = DEFAULTS.telemetry;
        cacheSize = DEFAULTS.cacheSize;
        logLevel = DEFAULTS.logLevel;
    }

}
