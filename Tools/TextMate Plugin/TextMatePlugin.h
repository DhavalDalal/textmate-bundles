//
//  �PROJECTNAME�.h
//  �PROJECTNAME�
//
//  Created by �FULLUSERNAME� on �DATE�.
//  Copyright �YEAR� �ORGANIZATIONNAME�. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol TMPlugInController
- (float)version;
@end

@interface �PROJECTNAME� : NSObject
{
}
- (id)initWithPlugInController:(id <TMPlugInController>)aController;
@end