//
//  UDID.h
//  MyUDID
//
//  Created by Carson Mobile on 2/22/23.
//
#import <UIKit/UIKit.h>
#ifndef UDID_h
#define UDID_h

@interface UDID : UIResponder <UIApplicationDelegate>

+ (void) FetchUDID;
+ (NSString *) GetUDID;
+ (NSString *) GetDevicePlatform;
+ (NSString *) GetDevicePlatformInfo;

@end


#endif /* UDID_h */
