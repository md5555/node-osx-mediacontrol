#import "iTunes.h"

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <queue>

#import <Foundation/Foundation.h>
#import <ScriptingBridge/SBApplication.h>
#import <objc/runtime.h>
 
// node headers
#include <v8.h>
#include <node.h>
#include <unistd.h>
#include <string.h>

using namespace node;
using namespace v8;

@interface iTunesNotificationCallback : NSObject

- (void)startMonitor;
- (void)stopMonitor;
- (void)callbackWithNotification:(NSNotification *)myNotification;

@end

namespace iTunes {
    Persistent<Function> * callback = nil;
    iTunesNotificationCallback * noti = nil;

    void runOnMainQueueWithoutDeadlocking(void (^block)(void)) {

	if ([NSThread isMainThread])
	{
	    block();
	}
	else
	{
	    dispatch_sync(dispatch_get_main_queue(), block);
	}
    }
}

@implementation iTunesNotificationCallback

+(id)newiTunesNotificationCallback {
    NSLog(@"Created iTunes Observer");
    return [[super alloc] init];
}

- (void)stopMonitor {

    NSString * observed = @"com.apple.iTunes.playerInfo";

    NSDistributedNotificationCenter *center =
		[NSDistributedNotificationCenter defaultCenter];

    [center removeObserver: self
	    name: observed 
	    object: nil];
}

- (void)startMonitor {

    NSString * observed = @"com.apple.iTunes.playerInfo";

    NSDistributedNotificationCenter *center =
		[NSDistributedNotificationCenter defaultCenter];

    [center addObserver: self
		selector: @selector(callbackWithNotification:)
		name: observed 
		object: nil];

    [self pushItunesState];
}

- (void) pushItunesState {

    iTunesApplication *iTunes = (iTunesApplication*)[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    iTunesEPlS state = [iTunes playerState]; 
    NSLog(@"Got iTunes state: %i", state);

    if (!iTunes::callback) {
	return;
    }

    TryCatch try_catch(Isolate::GetCurrent());
 
    // prepare arguments for the callback
    Local<Value> argv[1];
    argv[0] = Integer::New(Isolate::GetCurrent(), (int)state);
 
    // call the callback and handle possible exception
    iTunes::callback->Get(Isolate::GetCurrent())->Call(v8::Object::New(Isolate::GetCurrent()), 1, argv);
 
    if (try_catch.HasCaught()) {
        FatalException(Isolate::GetCurrent(), try_catch);
    }
}

- (void)callbackWithNotification:(NSNotification *)myNotification {

    iTunes::runOnMainQueueWithoutDeadlocking(^{
	[self pushItunesState];
    });
}

@end

static void Stop(const v8::FunctionCallbackInfo<v8::Value>& args) {

    if (!iTunes::noti) {
	return;
    } 

    [iTunes::noti stopMonitor];
    iTunes::noti = nil;
}

static void Start(const v8::FunctionCallbackInfo<v8::Value>& args) {

    Local<Function> cb = Local<Function>::Cast(args[0]);
    iTunes::callback = new Persistent<Function>(Isolate::GetCurrent(), cb);

    iTunes::noti = [iTunesNotificationCallback newiTunesNotificationCallback];
    [iTunes::noti startMonitor];
} 

static void CtrlPause(const v8::FunctionCallbackInfo<v8::Value>& args) {

    iTunesApplication *iTunes = (iTunesApplication*)[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];

    [iTunes pause];
}

static void CtrlPlay(const v8::FunctionCallbackInfo<v8::Value>& args) {

    iTunesApplication *iTunes = (iTunesApplication*)[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];

    [iTunes playpause];
}


namespace McItunes {
    Handle<Value> Initialize(Handle<Object> target)
    {
	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "observe"),
	    FunctionTemplate::New(Isolate::GetCurrent(), Start)->GetFunction());

	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "ignore"),
	    FunctionTemplate::New(Isolate::GetCurrent(), Stop)->GetFunction());

	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "controlPause"),
	    FunctionTemplate::New(Isolate::GetCurrent(), CtrlPlay)->GetFunction());

	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "controlPlay"),
	    FunctionTemplate::New(Isolate::GetCurrent(), CtrlPlay)->GetFunction());

	return True(Isolate::GetCurrent());
    }
}

NODE_MODULE(node_osx_mediacontrol_itunes, McItunes::Initialize);
