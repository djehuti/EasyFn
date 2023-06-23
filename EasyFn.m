//
//  EasyFn.m
//  EasyFn
//
//  Created by Ben Cox on 8/10/10.
//  Copyright 2010 Ben Cox. All rights reserved.
//  Released into the public domain 2023.
//

#import "EasyFn.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/hidsystem/IOHIDShared.h>


#pragma mark Constants

static NSString * const kUseAltIconsKey = @"UseAltIcons";
static NSString * const kShowStatusItemKey = @"ShowStatusItem";
static NSString * const kShowDockIconKey = @"ShowDockIcon";
static NSString * const kFnStateKey = @"com.apple.keyboard.fnState";

static NSString * const kFnStateChangedNotificationName = @"com.apple.keyboard.fnstatedidchange";
static NSString * const kFnStateChangedUserInfoKey = @"state";

#pragma mark -
#pragma mark Private Interface

@interface EasyFn ()

- (BOOL) p_getSystemPrefFnKeySetting;
- (void) p_setSystemPrefFnKeySetting:(BOOL)setting;
- (BOOL) p_useAltIcons;
- (void) p_setUseAltIcons:(BOOL)useAltIcons;
- (BOOL) p_showStatusItem;
- (void) p_setShowStatusItem:(BOOL)showStatusItem;
- (void) p_setupStatusItem;
- (void) p_teardownStatusItem;
- (BOOL) p_showDockIcon;
- (void) p_setShowDockIcon:(BOOL)showDockIcon;
- (void) p_relaunch;
- (void) p_observeNotification:(NSNotification*)notification;
- (void) p_activateFnKeySetting;

- (NSImage*) p_itemImageForSetting:(BOOL)setting;
- (NSImage*) p_dockIconImageForSetting:(BOOL)setting;

- (IBAction) p_doQuit:(id)sender;
- (IBAction) p_statusItemClicked:(id)sender;

@end

#pragma mark -
#pragma mark EasyFn Implementation

@implementation EasyFn

+ (void) initialize
{
  NSMutableDictionary *defaultDict = [NSMutableDictionary dictionaryWithCapacity:3];
  [defaultDict setObject:[NSNumber numberWithBool:NO] forKey:kUseAltIconsKey];
  [defaultDict setObject:[NSNumber numberWithBool:YES] forKey:kShowStatusItemKey];
  [defaultDict setObject:[NSNumber numberWithBool:YES] forKey:kShowDockIconKey];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaultDict];
}

- (void) awakeFromNib
{
  BOOL setting = [self p_getSystemPrefFnKeySetting];
  fnKeyMenuItem_.state = setting ? NSOnState : NSOffState;

  useAltIconsMenuItem_.state = [self p_useAltIcons] ? NSOnState : NSOffState;

  BOOL showStatusItem = [self p_showStatusItem];
  showStatusItemMenuItem_.state = showStatusItem ? NSOnState : NSOffState;
  if (showStatusItem) {
    [self p_setupStatusItem];
  }

  BOOL showDockIcon = [self p_showDockIcon];
  showDockIconMenuItem_.state = showDockIcon ? NSOnState : NSOffState;
  if (showDockIcon) {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    [NSApp setApplicationIconImage:[self p_dockIconImageForSetting:setting]];
    [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivationOptions)0];
  } else {
    quitItem_ = [[NSMenuItem alloc] initWithTitle:@"Quit EasyFn" action:@selector(p_doQuit:) keyEquivalent:@""];
    [dockMenu_ addItem:quitItem_];
  }

  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                      selector:@selector(p_observeNotification:)
                                                          name:nil
                                                        object:nil];
}

- (void) dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  [self p_teardownStatusItem];
  [super dealloc];
}

#pragma mark -
#pragma mark Actions

- (IBAction) toggleFnKeySetting:(id)sender
{
  BOOL newSetting = ![self p_getSystemPrefFnKeySetting];
  [self p_setSystemPrefFnKeySetting:newSetting];
}

- (IBAction) setUseAltIcons:(id)sender
{
  [self p_setUseAltIcons:![self p_useAltIcons]];
}

- (IBAction) setStatusItem:(id)sender
{
  [self p_setShowStatusItem:![self p_showStatusItem]];
}

- (IBAction) setShowDockIcon:(id)sender
{
  [self p_setShowDockIcon:![self p_showDockIcon]];
}

#pragma mark -
#pragma mark Private Implementation

- (BOOL) p_getSystemPrefFnKeySetting
{
  BOOL setting = NO;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults synchronize];
  NSMutableDictionary *dict = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];
  id obj = [dict objectForKey:kFnStateKey];
  if (obj && [obj isKindOfClass:[NSNumber class]]) {
    NSNumber *num = (NSNumber*)obj;
    setting = [num boolValue];
  }
  return setting;
}

- (void) p_setSystemPrefFnKeySetting:(BOOL)setting
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *dict = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];
  [dict setObject:[NSNumber numberWithBool:setting] forKey:kFnStateKey];
  [defaults setPersistentDomain:dict forName:NSGlobalDomain];
  [defaults synchronize];
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:1];
  [userInfo setObject:[NSNumber numberWithBool:setting] forKey:kFnStateChangedUserInfoKey];
  [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kFnStateChangedNotificationName object:nil userInfo:userInfo];
  [self p_activateFnKeySetting];
  fnKeyMenuItem_.state = setting ? NSOnState : NSOffState;
  if (statusItem_) {
    statusItem_.image = [self p_itemImageForSetting:setting];
  }
  if ([self p_showDockIcon]) {
    [NSApp setApplicationIconImage:[self p_dockIconImageForSetting:setting]];
  }
}

- (BOOL) p_useAltIcons
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:kUseAltIconsKey];
}

- (void) p_setUseAltIcons:(BOOL)useAltIcons
{
  [[NSUserDefaults standardUserDefaults] setBool:useAltIcons forKey:kUseAltIconsKey];
  useAltIconsMenuItem_.state = useAltIcons ? NSOnState : NSOffState;
  if (statusItem_) {
    statusItem_.image = [self p_itemImageForSetting:[self p_getSystemPrefFnKeySetting]];
  }
}

- (BOOL) p_showStatusItem
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:kShowStatusItemKey];
}

- (void) p_setShowStatusItem:(BOOL)showStatusItem
{
  BOOL oldValue = [self p_showStatusItem];
  if (showStatusItem != oldValue) {
    [[NSUserDefaults standardUserDefaults] setBool:showStatusItem forKey:kShowStatusItemKey];
    if (showStatusItem) {
      NSAssert(statusItem_ == nil, @"Shouldn't already have a status item.");
      [self p_setupStatusItem];
    } else {
      NSAssert(statusItem_ != nil, @"Should have a status item.");
      [self p_teardownStatusItem];
      [self p_setShowDockIcon:YES];
    }
    showStatusItemMenuItem_.state = showStatusItem ? NSOnState : NSOffState;
  }
}

- (void) p_setupStatusItem
{
  if (!statusItem_) {
    statusItem_ = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    statusItem_.highlightMode = YES;
    statusItem_.image = [self p_itemImageForSetting:[self p_getSystemPrefFnKeySetting]];
    statusItem_.action = @selector(p_statusItemClicked:);
    statusItem_.target = self;
  }
}

- (void) p_teardownStatusItem
{
  if (statusItem_) {
    [[NSStatusBar systemStatusBar] removeStatusItem:statusItem_];
    [statusItem_ release];
    statusItem_ = nil;
  }
}

- (BOOL) p_showDockIcon
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:kShowDockIconKey];
}

- (void) p_setShowDockIcon:(BOOL)showDockItem
{
  BOOL currentState = [self p_showDockIcon];
  if (showDockItem != currentState) {
    [[NSUserDefaults standardUserDefaults] setBool:showDockItem forKey:kShowDockIconKey];
    showDockIconMenuItem_.state = showDockItem ? NSOnState : NSOffState;
    if (showDockItem) {
      [dockMenu_ removeItem:quitItem_];
      [quitItem_ release];
      quitItem_ = nil;
      ProcessSerialNumber psn = { 0, kCurrentProcess };
      TransformProcessType(&psn, kProcessTransformToForegroundApplication);
      [NSApp setApplicationIconImage:[self p_dockIconImageForSetting:[self p_getSystemPrefFnKeySetting]]];
      [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivationOptions)0];
    } else {
      [self p_setShowStatusItem:YES];
      [self p_relaunch];
    }
  }
}

- (void) p_relaunch
{
  NSString *pathToRelaunch = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"relaunch"];
  NSString *copiedRelaunch = [NSTemporaryDirectory() stringByAppendingPathComponent:[pathToRelaunch lastPathComponent]];
  [[NSFileManager defaultManager] removeItemAtPath:copiedRelaunch error:NULL];
  [[NSFileManager defaultManager] copyItemAtPath:pathToRelaunch toPath:copiedRelaunch error:NULL];
  NSString *me = [[NSBundle mainBundle] executablePath];
  NSString *mypid = [NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]];
  NSArray *args = [NSArray arrayWithObjects:me, mypid, nil];
  [NSTask launchedTaskWithLaunchPath:copiedRelaunch arguments:args];
  [NSApp terminate:nil];
}

- (void) p_observeNotification:(NSNotification*)notification
{
  if ([[notification name] isEqualToString:kFnStateChangedNotificationName]) {
    BOOL setting = NO;
    id obj = [[notification userInfo] objectForKey:kFnStateChangedUserInfoKey];
    if (obj && [obj isKindOfClass:[NSNumber class]]) {
      NSNumber *num = (NSNumber*)obj;
      setting = [num boolValue];
    }
    if (statusItem_) {
      statusItem_.image = [self p_itemImageForSetting:setting];
    }
    if ([self p_showDockIcon]) {
      [NSApp setApplicationIconImage:[self p_dockIconImageForSetting:setting]];
    }
  }
}

- (void) p_activateFnKeySetting
{
  io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(kIOHIDSystemClass));
  if (service != IO_OBJECT_NULL) {
    io_connect_t conn = IO_OBJECT_NULL;
    kern_return_t kerr = IOServiceOpen(service, mach_task_self(), kIOHIDParamConnectType, &conn);
    if (kerr == KERN_SUCCESS) {
      UInt32 val = [self p_getSystemPrefFnKeySetting] ? 1 : 0;
      IOHIDSetParameter(conn, CFSTR(kIOHIDFKeyModeKey), &val, sizeof(val));
      IOServiceClose(conn);
    }
    else {
      NSLog(@"Couldn't open service: err = %u", kerr);
    }
    IOObjectRelease(service);
  }
  else {
    NSLog(@"Couldn't find matching service");
  }
}

- (NSImage*) p_itemImageForSetting:(BOOL)setting
{
  NSString *alt = [self p_useAltIcons] ? @"Alt" : @"";
  NSString *state = setting ? @"On" : @"Off";
  NSString *imageName = [NSString stringWithFormat:@"EasyFnStatusItem%@%@", alt, state];
  NSImage *image = [NSImage imageNamed:imageName];
  return image;
}

- (NSImage*) p_dockIconImageForSetting:(BOOL)setting
{
  NSString *imageName = [NSString stringWithFormat:@"EasyFnAppIcon%@", setting ? @"On" : @"Off"];
  NSImage *image = [NSImage imageNamed:imageName];
  return image;
}

- (IBAction) p_doQuit:(id)sender
{
  [NSApp terminate:sender];
}

- (IBAction) p_statusItemClicked:(id)sender
{
  NSEvent *theEvent = [NSApp currentEvent];
  if ([theEvent modifierFlags] & NSCommandKeyMask) {
    [statusItem_ popUpStatusItemMenu:dockMenu_];
  } else {
    [self toggleFnKeySetting:sender];
  }
}

@end
