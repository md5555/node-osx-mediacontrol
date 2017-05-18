#import "iTunes.h"

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

@interface NotificationCallback : NSObject

- (void)startMonitor;
- (void)stopMonitor;
- (void)callbackWithNotification:(NSNotification *)myNotification;

@end

@implementation NotificationCallback

Persistent<Function> * callback = 0;

+(id)newNotificationCallback {
    NSLog(@"Created iTunes Observer");
    return [[super alloc] init];
}

-(void)dealloc {
    [super dealloc];
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
}

- (void)callbackWithNotification:(NSNotification *)myNotification {

    iTunesApplication *iTunes = (iTunesApplication*)[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];

    iTunesEPlS state = [iTunes playerState]; 

    NSLog(@"Got iTunes state: %i", state);

    [iTunes release];

    if (!callback) {
	return;
    }

    TryCatch try_catch(Isolate::GetCurrent());
 
    // prepare arguments for the callback
    Local<Value> argv[1];
    argv[0] = Integer::New(Isolate::GetCurrent(), (int)state);
 
    // call the callback and handle possible exception
    callback->Get(Isolate::GetCurrent())->Call(v8::Object::New(Isolate::GetCurrent()), 1, argv);
 
    if (try_catch.HasCaught()) {
        FatalException(Isolate::GetCurrent(), try_catch);
    }
}

@end

NotificationCallback * noti;

void Stop(const v8::FunctionCallbackInfo<v8::Value>& args) {

    if (!noti) {
	return;
    } 

    [noti stopMonitor];
    [noti release];
}

void Start(const v8::FunctionCallbackInfo<v8::Value>& args) {

    Local<Function> cb = Local<Function>::Cast(args[0]);
    callback = new Persistent<Function>(Isolate::GetCurrent(), cb);

    noti = [NotificationCallback newNotificationCallback];

    [noti startMonitor];

    CFRunLoopRun();
} 

Handle<Value> Initialize(Handle<Object> target)
{
    target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "observe"),
        FunctionTemplate::New(Isolate::GetCurrent(), Start)->GetFunction());

    target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "ignore"),
        FunctionTemplate::New(Isolate::GetCurrent(), Stop)->GetFunction());

    return True(Isolate::GetCurrent());
}

NODE_MODULE(node_itunes, Initialize);
