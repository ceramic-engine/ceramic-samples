#import "hxcpp.h"
#import "linc_Objc.h"
#import <Foundation/Foundation.h>
#import "linc_Http.h"
#import "objc_Http.h"

namespace ceramic {

    namespace ios {

        void Http_sendHTTPRequest(::Dynamic params, ::Dynamic done) {
            NSDictionary* params_objc_ = ::bind::objc::HxcppToObjcId((Dynamic)params);
            BindObjcHaxeWrapperClass *done_objc_wrapper_ = [[BindObjcHaxeWrapperClass alloc] init:done.mPtr];
            void (^done_objc_)(NSDictionary* response) = ^(NSDictionary* response) {
                ::Dynamic response_hxcpp_ = ::bind::objc::ObjcIdToHxcpp(response);
                done_objc_wrapper_->haxeObject->__run(response_hxcpp_);
            };
            [Http sendHTTPRequest:params_objc_ done:done_objc_];
        }

        void Http_download(::Dynamic params, ::String targetPath, ::Dynamic done) {
            NSDictionary* params_objc_ = ::bind::objc::HxcppToObjcId((Dynamic)params);
            NSString* targetPath_objc_ = ::bind::objc::HxcppToNSString(targetPath);
            BindObjcHaxeWrapperClass *done_objc_wrapper_ = [[BindObjcHaxeWrapperClass alloc] init:done.mPtr];
            void (^done_objc_)(NSString* fullPath) = ^(NSString* fullPath) {
                ::String fullPath_hxcpp_ = ::bind::objc::NSStringToHxcpp(fullPath);
                done_objc_wrapper_->haxeObject->__run(fullPath_hxcpp_);
            };
            [Http download:params_objc_ targetPath:targetPath_objc_ done:done_objc_];
        }

        ::Dynamic Http_init() {
            Http* return_objc_ = [[Http alloc] init];
            ::Dynamic return_hxcpp_ = ::bind::objc::WrappedObjcIdToHxcpp(return_objc_);
            return return_hxcpp_;
        }

    }

}

