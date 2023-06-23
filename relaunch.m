//
// By Cédric Luthi.
//
// http://0xced.blogspot.com/2006/06/relaunch-your-cocoa-application-by.html
//  -> https://0xced.blogspot.com/2006/06/relaunch-your-cocoa-application-by.html?showComment=1161192720000#c116119273737925564
//
// > > Hello! This works great for me. Any distribution requirements?
// >
// > It would be nice to write a line in the read-me with a link to this page so that other developers
// > can use it too. Other than that, you're free to use it as you wish :-)
//
// gcc -Wall -arch i386 -arch ppc -mmacosx-version-min=10.4 -Os -framework AppKit -o relaunch relaunch.m

#import <AppKit/AppKit.h>

@interface TerminationListener : NSObject
{
  const char *executablePath;
  pid_t parentProcessId;
}

- (void) relaunch;

@end

@implementation TerminationListener

- (id) initWithExecutablePath:(const char *)execPath parentProcessId:(pid_t)ppid
{
  self = [super init];
  if (self != nil) {
    executablePath = execPath;
    parentProcessId = ppid;

    // This adds the input source required by the run loop
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(applicationDidTerminate:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    if (getppid() == 1) {
      // ppid is launchd (1) => parent terminated already
      [self relaunch];
    }
  }
  return self;
}

- (void) applicationDidTerminate:(NSNotification *)notification
{
  if (parentProcessId == [[[notification userInfo] valueForKey:@"NSApplicationProcessIdentifier"] intValue]) {
    // parent just terminated
    [self relaunch];
  }
}

- (void) relaunch
{
  [[NSWorkspace sharedWorkspace] launchApplication:[NSString stringWithUTF8String:executablePath]];
  exit(0);
}

@end

int main (int argc, const char * argv[])
{
  if (argc != 3) return EXIT_FAILURE;

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  [[[TerminationListener alloc] initWithExecutablePath:argv[1] parentProcessId:atoi(argv[2])] autorelease];
  [[NSApplication sharedApplication] run];

  [pool release];

  return EXIT_SUCCESS;
}
