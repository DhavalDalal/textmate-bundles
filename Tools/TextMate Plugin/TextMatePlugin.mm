//
//  �PROJECTNAME�.mm
//  �PROJECTNAME�
//
//  Created by �FULLUSERNAME� on �DATE�.
//  Copyright �YEAR� �ORGANIZATIONNAME�. All rights reserved.
//

#import "�PROJECTNAME�.h"
#import "MethodSwizzle.h"

@implementation �PROJECTNAME�

- (id)initWithPlugInController:(id <TMPlugInController>)aController
{
	self = [self init];
	NSApp = [NSApplication sharedApplication];

	return self;
}
@end
