//Copyright © 2018 Kiet Ha
#ifdef DEBUG
  #define debug(fmt, ...) NSLog((@"[FastForwardTime(%d)]:: " fmt), __LINE__, ##__VA_ARGS__)
#else
  #define debug(s, ...)
#endif

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>

@interface SBUILegibilityLabel : UIView
@property (nonatomic,copy) NSString *string;
@property (nonatomic,retain) UIFont *font;
-(void)setNumberOfLines:(long long)arg1;
-(void)setString:(NSString *)arg1;
-(void)setFrame:(CGRect)arg1;
@end

@interface SBFLockScreenDateSubtitleView : UIView
@property (copy) UIFont *font;
@end

@interface SBFLockScreenDateView : UIView
-(float)expectedLabelWidth:(SBUILegibilityLabel *)label;
-(void)updateSeconds;
@end

@interface SBLockStateAggregator : NSObject {
        unsigned long long _lockState;
}
+(id)sharedInstance;
@end

//@interface SBLockScreenManager : NSObject
//+(id)sharedInstance;
//-(BOOL)isUILocked;
//@end

#define kIdentifier @"com.kaitouiet.fastforwardtime"
#define kSettingsChangedNotification (CFStringRef)@"com.kaitouiet.fastforwardtime/ReloadPrefs"
#define kSettingsPath @"/var/mobile/Library/Preferences/com.kaitouiet.fastforwardtime.plist"

static NSTimer *secondsTimer = nil;
static BOOL enabled;
static NSInteger timeType = 1;
static CGFloat changeTimeSize = 0;
static CGFloat changeDateSize = 0;
static CGFloat notiUpOrDown = 0;
static CGFloat yTimeDate = 0;
static CGFloat yDateOnly = 0;

%hook SBFLockScreenDateView

-(void)setDateToTimeStretch:(double)arg1 {
	  %orig(0); // fixes the scroll lag
	//	debug("%f", arg1);
}

- (CGRect)_subtitleViewFrameForView:(id)arg1 alignmentPercent:(double)arg2 {

//SBUILegibilityLabel *timeLabel = MSHookIvar<SBUILegibilityLabel *>(self, "_timeLabel");
  CGRect origRect = %orig;
  return CGRectMake(origRect.origin.x, origRect.origin.y + yDateOnly /*(changeTimeSize + changeTimeSize/8)*/, origRect.size.width, origRect.size.height);

}

-(CGRect)_timeLabelFrameForAlignmentPercent:(double)arg1 {

  SBUILegibilityLabel *timeLabel = MSHookIvar<SBUILegibilityLabel *>(self, "_timeLabel");
  CGRect timing = %orig;
  return CGRectMake (timing.origin.x, timing.origin.y + yTimeDate, [self expectedLabelWidth:timeLabel], timing.size.height);

}

-(void)layoutSubviews {

  if (enabled) {
    [self updateSeconds];
    if (secondsTimer == nil && ![secondsTimer isValid]) {
        secondsTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateSeconds) userInfo:nil repeats:YES];
    }
  }
    %orig;
}


%new
-(void)updateSeconds {

  if (enabled) {

	// Check if phone unlocked and secondsTimer isnt nil/isValid, if so, invalidate and set to nil
	if (!(MSHookIvar<NSUInteger>([objc_getClass("SBLockStateAggregator") sharedInstance], "_lockState") == 3)  && secondsTimer != nil && [secondsTimer isValid]) {
		[secondsTimer invalidate];
		secondsTimer = nil;
	}
}

	// Hook the time label
	SBUILegibilityLabel *timeLabel = MSHookIvar<SBUILegibilityLabel *>(self, "_timeLabel");
  // Hook the date view
	SBFLockScreenDateSubtitleView *dateSubtitleView = MSHookIvar<SBFLockScreenDateSubtitleView *>(self, "_dateSubtitleView");
  //SBFLockScreenDateSubtitleView* customSubtitleView = MSHookIvar<SBFLockScreenDateSubtitleView*>(self, "_customSubtitleView");

  if (enabled) {

        if (timeLabel != nil) { // Extra check just to be sure
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init]; // Set the date formatter to hour:minute:second (like stock just extra second)
        if (timeType == 2) {
            [dateFormatter setDateFormat:@"HH:mm:ss"]; // 24hr
        } else if (timeType == 1) {
            [dateFormatter setDateFormat:@"h:mm:ss"]; // 12hr
        }
		// Get NSString from date and format it using dateFormater then set the time label
		NSString *currentTimeString = [dateFormatter stringFromDate:[NSDate date]];
	   	[timeLabel setString:currentTimeString];
		[timeLabel setFrame:CGRectMake(timeLabel.frame.origin.x, timeLabel.frame.origin.y, [self expectedLabelWidth:timeLabel], timeLabel.frame.size.height)];
    }
  }

  if (changeTimeSize != 0) {
    [timeLabel setFont:[UIFont systemFontOfSize:changeTimeSize]];
  }

//[dateSubtitleView setFrame:CGRectMake(dateSubtitleView.frame.origin.x, dateSubtitleView.frame.origin.y + yDateOnly, dateSubtitleView.frame.size.width, dateSubtitleView.frame.size.height)];
//[customSubtitleView setFrame:CGRectMake(customSubtitleView.frame.origin.x, customSubtitleView.frame.origin.y + yDateOnly, customSubtitleView.frame.size.width, customSubtitleView.frame.size.height)];
  if (changeDateSize != 0) {
	   [dateSubtitleView setFont:[UIFont systemFontOfSize:changeDateSize]];
  }
}

-(void)_updateLabels {
  %orig;

  SBUILegibilityLabel *timeLabel = MSHookIvar<SBUILegibilityLabel *>(self, "_timeLabel");
  if (changeTimeSize != 0) {
    [timeLabel setFont:[UIFont systemFontOfSize:changeTimeSize]];
  }

  SBFLockScreenDateSubtitleView *dateSubtitleView = MSHookIvar<SBFLockScreenDateSubtitleView *>(self, "_dateSubtitleView");
  if (changeDateSize != 0) {
  	[dateSubtitleView setFont:[UIFont systemFontOfSize:changeDateSize]];
  }

}


%new

// calculate needed width
-(float)expectedLabelWidth:(SBUILegibilityLabel *)label {
    [label setNumberOfLines:1];
    CGSize expectedLabelSize = [[label string] sizeWithAttributes:@{NSFontAttributeName:label.font}];
    return expectedLabelSize.width + 2; // just added a tiny bit extra just in case otherwise sometimes it would just be ".."
}


%end


%hook NCNotificationListCollectionView
- (void)setFrame:(CGRect)arg1 {
	arg1.origin.y = arg1.origin.y + notiUpOrDown;
	%orig(arg1);
}
%end


static void reloadPrefs() {
	CFPreferencesAppSynchronize((CFStringRef)kIdentifier);

	NSDictionary *prefs = nil;
	if ([NSHomeDirectory() isEqualToString:@"/var/mobile"]) {
		CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		if (keyList != nil) {
			prefs = (NSDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, (CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
			if (prefs == nil)
				prefs = [NSDictionary dictionary];
			CFRelease(keyList);
		}
	} else {
		prefs = [NSDictionary dictionaryWithContentsOfFile:kSettingsPath];
	}

	enabled = [prefs objectForKey:@"enabled"] ? [(NSNumber *)[prefs objectForKey:@"enabled"] boolValue] : true;
	timeType = [prefs objectForKey:@"timeType"] ? [(NSNumber *)[prefs objectForKey:@"timeType"] intValue] : 1;
  	changeTimeSize = [prefs objectForKey:@"changeTimeSize"] ? [[prefs objectForKey:@"changeTimeSize"] floatValue] : changeTimeSize;
 	changeDateSize = [prefs objectForKey:@"changeDateSize"] ? [[prefs objectForKey:@"changeDateSize"] floatValue] : changeDateSize;
  	notiUpOrDown = [prefs objectForKey:@"notiUpOrDown"] ? [[prefs objectForKey:@"notiUpOrDown"] floatValue] : notiUpOrDown;
  	yTimeDate = [prefs objectForKey:@"yTimeDate"] ? [[prefs objectForKey:@"yTimeDate"] floatValue] : yTimeDate;
  	yDateOnly = [prefs objectForKey:@"yDateOnly"] ? [[prefs objectForKey:@"yDateOnly"] floatValue] : yDateOnly;

	}


  %ctor {
  	reloadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, kSettingsChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
  }

//love you Tonyk7🖤
