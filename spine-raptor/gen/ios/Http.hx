package ios;
// This file was generated with bind library

import bind.objc.Support;

class Http {

    private var _instance:Dynamic = null;

    public function new() {}

    public static function sendHTTPRequest(params:Dynamic, done:Dynamic->Void):Void {
        Http_Extern.sendHTTPRequest(params, done);
    }

    public static function download(params:Dynamic, targetPath:String, done:String->Void):Void {
        Http_Extern.download(params, targetPath, done);
    }

    public function init():Http {
        _instance = Http_Extern.init();
        return this;
    }

}

@:keep
@:include('linc_Http.h')
#if !display
@:build(bind.Linc.touch())
@:build(bind.Linc.xml('Http', './'))
#end
@:allow(ios.Http)
private extern class Http_Extern {

    @:native('ceramic::ios::Http_sendHTTPRequest')
    static function sendHTTPRequest(params:Dynamic, done:Dynamic->Void):Void;

    @:native('ceramic::ios::Http_download')
    static function download(params:Dynamic, targetPath:String, done:String->Void):Void;

    @:native('ceramic::ios::Http_init')
    static function init():Dynamic;

}

