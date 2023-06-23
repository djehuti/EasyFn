//
//  EasyFn.h
//  EasyFn
//
//  Created by Ben Cox on 8/10/10.
//  Copyright 2010 Ben Cox. All rights reserved.
//  Released into the public domain 2023.
//

#import <Cocoa/Cocoa.h>
@class NSStatusBarItem;


@interface EasyFn : NSObject {
  IBOutlet NSMenuItem *fnKeyMenuItem_;
  IBOutlet NSMenu *dockMenu_;
  IBOutlet NSMenuItem *useAltIconsMenuItem_;
  IBOutlet NSMenuItem *showStatusItemMenuItem_;
  IBOutlet NSMenuItem *showDockIconMenuItem_;
  NSMenuItem *quitItem_;
  NSStatusItem *statusItem_;
}

- (IBAction) toggleFnKeySetting:(id)sender;
- (IBAction) setUseAltIcons:(id)sender;
- (IBAction) setStatusItem:(id)sender;
- (IBAction) setShowDockIcon:(id)sender;

@end
