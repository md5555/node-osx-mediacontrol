#import "Spotify.h"

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <queue>

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <ScriptingBridge/SBApplication.h>
 
// node headers
#include <v8.h>
#include <node.h>
#include <unistd.h>
#include <string.h>

using namespace node;
using namespace v8;

@interface SpotifyNotificationCallback : NSObject

- (void)startMonitor;
- (void)stopMonitor;
- (void)callbackWithNotification:(NSNotification *)myNotification;

@end

namespace Spotify {
    Persistent<Function> * callback = nil;
    SpotifyNotificationCallback * noti = nil;

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

@implementation SpotifyNotificationCallback


+(id)newSpotifyNotificationCallback {
    NSLog(@"Created Spotify Observer");
    return [[super alloc] init];
}

- (void)stopMonitor {

    NSString * observed = @"com.spotify.client.playerInfo";

    NSDistributedNotificationCenter *center =
		[NSDistributedNotificationCenter defaultCenter];

    [center removeObserver: self
	    name: observed 
	    object: nil];
}

- (void)startMonitor {

    NSString * observed = @"com.spotify.client.playerInfo";

    NSDistributedNotificationCenter *center =
		[NSDistributedNotificationCenter defaultCenter];

    [center addObserver: self
		selector: @selector(Spotify::callbackWithNotification:)
		name: observed 
		object: nil];
}

- (void) pushSpotifyState {

    SpotifyApplication *spotify = (SpotifyApplication*)[SBApplication applicationWithBundleIdentifier:@"com.spotify.client"];
    OSType state = [spotify playerState]; 
    NSLog(@"Got Spotify state: %i", state);

    if (!Spotify::callback) {
	return;
    }

    TryCatch try_catch(Isolate::GetCurrent());
 
    // prepare arguments for the Spotify::callback
    Local<Value> argv[1];
    argv[0] = Integer::New(Isolate::GetCurrent(), (int)state);
 
    // call the Spotify::callback and handle possible exception
    Spotify::callback->Get(Isolate::GetCurrent())->Call(v8::Object::New(Isolate::GetCurrent()), 1, argv);
 
    if (try_catch.HasCaught()) {
        FatalException(Isolate::GetCurrent(), try_catch);
    }
}

- (void)callbackWithNotification:(NSNotification *)myNotification {

    Spotify::runOnMainQueueWithoutDeadlocking(^{
	[self pushSpotifyState];
    });
}

@end

static void Stop(const v8::FunctionCallbackInfo<v8::Value>& args) {

    if (!Spotify::noti) {
	return;
    } 

    [Spotify::noti stopMonitor];
    Spotify::noti = nil;
}

static void Start(const v8::FunctionCallbackInfo<v8::Value>& args) {

    Local<Function> cb = Local<Function>::Cast(args[0]);
    Spotify::callback = new Persistent<Function>(Isolate::GetCurrent(), cb);

    Spotify::noti = [SpotifyNotificationCallback newSpotifyNotificationCallback];
    [Spotify::noti startMonitor];
} 

namespace McSpotify {
    Handle<Value> Initialize(Handle<Object> target)
    {
	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "observe"),
	    FunctionTemplate::New(Isolate::GetCurrent(), Start)->GetFunction());

	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "ignore"),
	    FunctionTemplate::New(Isolate::GetCurrent(), Stop)->GetFunction());

	return True(Isolate::GetCurrent());
    }
}

NODE_MODULE(osx_mediacontrol_spotify, McSpotify::Initialize);
