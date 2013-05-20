/*
     File: InspectorWindowController.m 
 Abstract: The main Inspector window controller.
  
  Version: 1.4 
  
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple 
 Inc. ("Apple") in consideration of your agreement to the following 
 terms, and your use, installation, modification or redistribution of 
 this Apple software constitutes acceptance of these terms.  If you do 
 not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software. 
  
 In consideration of your agreement to abide by the following terms, and 
 subject to these terms, Apple grants you a personal, non-exclusive 
 license, under Apple's copyrights in this original Apple software (the 
 "Apple Software"), to use, reproduce, modify and redistribute the Apple 
 Software, with or without modifications, in source and/or binary forms; 
 provided that if you redistribute the Apple Software in its entirety and 
 without modifications, you must retain this notice and the following 
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. may 
 be used to endorse or promote products derived from the Apple Software 
 without specific prior written permission from Apple.  Except as 
 expressly stated in this notice, no other rights or licenses, express or 
 implied, are granted by Apple herein, including but not limited to any 
 patent rights that may be infringed by your derivative works or by other 
 works in which the Apple Software may be incorporated. 
  
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE 
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION 
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS 
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND 
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
  
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL 
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED 
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), 
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE. 
  
 Copyright (C) 2010 Apple Inc. All Rights Reserved. 
  
 */

#import "InspectorWindowController.h"

#import "UIElementUtilities.h"

#import "AppDelegate.h"

@implementation InspectorWindowController

NSArray * apps;
int appPid;
NSArray * appWins;

- (void)awakeFromNib {
    [self readRunningApps];
    [_browser setColumnResizingType:NSBrowserAutoColumnResizing];
    [_browser setMaxVisibleColumns:2];
	[_browser setTakesTitleFromPreviousColumn:NO];
	[_browser setTitled:YES];
}



- (void) readRunningApps {
    if (apps != NULL) [apps release];
    apps = [[[NSWorkspace sharedWorkspace] runningApplications] retain];
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(NSInteger)row column:(NSInteger)column {
    NSRunningApplication * app;
    CFStringRef windowTitle;
   // NSLog(@"All Apps: %@", apps);
    switch(column) {
        case 0:
            //NSLog(@"row: %d", row);
            app = [apps objectAtIndex:(NSUInteger)row];
            NSString *locName = [app localizedName];
            if (locName == NULL) return;
            [cell setTitle: [app localizedName]];
            //[cell setTag: [app processIdentifier]];
            [cell setLeaf:NO];
            break;
        case 1:
            AXUIElementCopyAttributeValue((AXUIElementRef)[appWins objectAtIndex:row], kAXTitleAttribute, (CFTypeRef*)&windowTitle);
            if (windowTitle == NULL) windowTitle = (CFStringRef)@"< no title >";
            [cell setLeaf:YES];
            [cell setTitle: (NSString *)windowTitle];
            
            break;
    }
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column {
    switch(column) {
        case 0:
            return [apps count];
        case 1:
            [self readAppWindows];
            return [appWins count];
        default:
            return 0;
    }
}

- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(NSInteger)column {
    switch(column) {
        case 0: return @"Apps";
        case 1: return @"Windows";
        default: return @"";
    }
}

- (void) readAppWindows {
    appWins = [NSArray array];
    int row = [_browser selectedRowInColumn:0];
    
    NSLog(@"readAppWindows: sel row=%d", row);
    if (row < 0) {
        return;
    }
    appPid = [((NSRunningApplication*)[apps objectAtIndex:row]) processIdentifier];
    AXUIElementRef app = AXUIElementCreateApplication(appPid);
    AXUIElementCopyAttributeValues(
                                   (AXUIElementRef) app,
                                   kAXWindowsAttribute,
                                   0,
                                   99999,
                                   (CFArrayRef *) &appWins
                                   );
    //CFRelease(app);
}

- (IBAction)onBringWindowHome:(id)sender {
    /*AppDelegate * ad = [[NSApplication sharedApplication]delegate];
    AXUIElementRef selectedWindow = [ad currentUIElement];*/
    
    // Obtain selected window as AXUIElementRef
    int row = [_browser selectedRowInColumn:1];
    NSLog(@"onBringWindowHome: sel row=%d", row);
    if (row < 0) {
        return;
    }
    AXUIElementRef selectedWindow = (AXUIElementRef)[appWins objectAtIndex:row];
    
    // Move to {50,50}
    AXValueRef temp;
    CGPoint windowPosition;
    windowPosition.x = 50; windowPosition.y = 50;
    temp = AXValueCreate(kAXValueCGPointType, &windowPosition);
    AXUIElementSetAttributeValue(selectedWindow, kAXPositionAttribute, temp);
    CFRelease(temp);
    
    // Bring to front
    ProcessSerialNumber psn;
    GetProcessForPID(appPid, &psn);
    
    SetFrontProcessWithOptions (&psn, kSetFrontProcessFrontWindowOnly);
    AXUIElementPerformAction (selectedWindow, kAXRaiseAction);
}

- (IBAction)onDoRefresh:(id)sender {
    [self readRunningApps];
    NSRunningApplication * app = [apps objectAtIndex:0];
    [_browser reloadColumn:0];
    [_browser sizeToFit];
}

- (IBAction)onBrowserSelector:(id)sender {
    int row = [_browser selectedRowInColumn:1];
    
    NSLog(@"onBrowserSelector: sel row=%d", row);
    if (row < 0) {
        return;
    }
    
    //AXUIElementCopyAttributeValue((AXUIElementRef)[appWins objectAtIndex:row], kAXTitleAttribute, (CFTypeRef*)&windowTitle);
    
    AXUIElementRef selectedWindow = (AXUIElementRef)[appWins objectAtIndex:row];
    
    AppDelegate * ad = [[NSApplication sharedApplication]delegate];
    
    [ad lockCurrentUIElement:NULL];
    [ad setCurrentUIElement:selectedWindow];
    [ad updateUIElementInfoWithAnimation:NO];
    
}

- (void)updateInfoForUIElement:(AXUIElementRef)element
{
    [_consoleView setString:[UIElementUtilities stringDescriptionOfUIElement:element]];
}


// -------------------------------------------------------------------------------
//	fontSizeSelected:sender
//
//	The use chose a new font size from the font size popup.  In turn change the
//	console view's font size.
// -------------------------------------------------------------------------------
- (IBAction)fontSizeSelected:(id)sender
{
	[_consoleView setFont:[NSFont userFontOfSize:[[sender titleOfSelectedItem] floatValue]]];
}

// -------------------------------------------------------------------------------
//	indicateUIElementIsLocked:flag
//
//	To show that we are locked into a uiElement, draw the console view's text in red.
// -------------------------------------------------------------------------------
- (void)indicateUIElementIsLocked:(BOOL)flag
{
	[_consoleView setTextColor:(flag)?[NSColor redColor]:[NSColor blackColor]];
}

/* Since all of our windows are NSPanels, we can't use the regular 'app should terminated when all windows are closed' delegate, since it will ask the delegate if all that is left onscreen are NSPanels.  So, let the window close, then terminate.
Probably should move this up to the App controller, and register for the notification there.
*/
- (void)windowWillClose:(NSNotification *)note {
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0];
}

@end
