//
//  PullToRefreshView.m
//  Grant Paul (chpwn)
//
//  (based on EGORefreshTableHeaderView)
//
//  Created by Devin Doty on 10/14/09October14.
//  Copyright 2009 enormego. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "PullToRefreshView.h"
#import <math.h>

#define SUBTITLE_TEXT_COLOR UIColorFromRGB(0x787878)
#define TEXT_COLOR   UIColorFromRGB(0x4f4f4f);
#define FLIP_ANIMATION_DURATION 0.18f
#define PullToRefreshTriggerOffset -65.0f
#define kTimeoutSeconds 30

@interface PullToRefreshView (Private)

@property (nonatomic, assign) PullToRefreshViewState state;

- (void)setShowsSubtitle:(BOOL)shouldShow;
- (void)handleNetworkStateChange:(NSNotification *)note;
- (void)feedDidFailToLoad;

@end

@implementation PullToRefreshView
@synthesize delegate, scrollView;

- (void)hideArrow:(BOOL)hidden {
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.1f];
	arrowImage.hidden = hidden;
	[UIView commitAnimations];
}

- (void)hideOfflineImage:(BOOL)hidden {
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.1f];
	offlineImage.hidden = hidden;
	[UIView commitAnimations];
}

- (id)initWithScrollView:(UIScrollView *)scroll {
	CGRect frame = CGRectMake(0.0f, 0.0f - scroll.bounds.size.height, scroll.bounds.size.width, scroll.bounds.size.height);

	if ((self = [super initWithFrame:frame])) {
		scrollView = [scroll retain];
		[scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];

		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pull_to_refresh_bg.png"]];

		CALayer *backgroundShadow = [[CALayer alloc] init];
		backgroundShadow.frame = CGRectMake(0, scroll.bounds.size.height - 14.f, scroll.bounds.size.width, 14.f);
		backgroundShadow.contents = (id)[UIImage imageNamed:@"pull_to_refresh_shadow.png"].CGImage;
		[self.layer addSublayer:backgroundShadow];
		[backgroundShadow release];

		subtitleLabel = [[UILabel alloc] init];
		subtitleLabel.frame = CGRectMake(0.0f, frame.size.height - 30.0f, self.frame.size.width, 20.0f);
		subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		subtitleLabel.font = [UIFont systemFontOfSize:12.f];
		subtitleLabel.textColor = SUBTITLE_TEXT_COLOR;
		subtitleLabel.shadowColor = [UIColor whiteColor];
		subtitleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
		subtitleLabel.backgroundColor = [UIColor clearColor];
		subtitleLabel.textAlignment = UITextAlignmentCenter;
		[self addSubview:subtitleLabel];

		statusLabel = [[UILabel alloc] init];
		statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		statusLabel.font = [UIFont systemFontOfSize:12.f];
		statusLabel.textColor = TEXT_COLOR;
		statusLabel.shadowColor = [UIColor whiteColor];
		statusLabel.shadowOffset = CGSizeMake(0.f, 1.f);
		statusLabel.backgroundColor = [UIColor clearColor];
		statusLabel.textAlignment = UITextAlignmentCenter;
		[self addSubview:statusLabel];

		arrowImage = [[CALayer alloc] init];
		arrowImage.frame = CGRectMake(25.0f, frame.size.height - 60.0f, 24.0f, 60.0f);
		arrowImage.contentsGravity = kCAGravityResizeAspect;
		arrowImage.contents = (id)[UIImage imageNamed:@"pull_to_refresh_spinner.png"].CGImage;

		offlineImage = [[CALayer alloc] init];
		offlineImage.frame = CGRectMake(32.0f, frame.size.height - 60.0f, 28.0f, 60.0f);
		offlineImage.contentsGravity = kCAGravityResizeAspect;
		offlineImage.contents = (id)[UIImage imageNamed:@"pull_to_refresh_offline.png"].CGImage;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
		if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
			arrowImage.contentsScale = [[UIScreen mainScreen] scale];
		}
#endif

		[self.layer addSublayer:arrowImage];
		[self.layer addSublayer:offlineImage];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkStateChange:) name:AppDidChangeNetworkState object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedDidFailToLoad) name:APIGetFeedFailed object:nil];

		if ([(AppDelegate *)[[UIApplication sharedApplication] delegate] isOffline]) {
			[self setState:PullToRefreshViewStateOffline];
		} else {
			[self setState:PullToRefreshViewStateNormal];
		}
	}

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if(showsSubtitle) {
		statusLabel.frame = CGRectMake(0.0f, self.bounds.size.height - 48.0f, self.bounds.size.width, 20.0f);
	} else {
		statusLabel.frame = CGRectMake(0.0f, self.bounds.size.height - 39.0f, self.bounds.size.width, 20.0f);
	}
}

- (void)handleNetworkStateChange:(NSNotification *)note
{
	if ([(AppDelegate *)[[UIApplication sharedApplication] delegate] isOffline]) {
		[self setState:PullToRefreshViewStateOffline];
	} else {
		// only transition to normal if we're offline. we may be in a weird state otherwise.
		if (state == PullToRefreshViewStateOffline) {
			[self setState:PullToRefreshViewStateNormal];
		} else {
			NSLog(@"not in an offline state when we got an online network change, was in state %i", state);
		}
	}
}

- (void)feedDidFailToLoad
{
	[self didFinishLoading];
}

- (void)loadingTimeout
{
	NSLog(@"ERROR: PTR loading timeout.");
	[self didFinishLoading];
}

#pragma mark -
#pragma mark Setters

- (void)setShowsSubtitle:(BOOL)shouldShow {
	showsSubtitle = shouldShow;
	if(shouldShow) {
		[self addSubview:subtitleLabel];
		[self refreshLastUpdatedDate];
	}
	else [subtitleLabel removeFromSuperview];
	[self setNeedsLayout];
}

- (void)refreshLastUpdatedDate {
	if (!showsSubtitle) return;
	NSDate *date = [NSDate date];

	if ([delegate respondsToSelector:@selector(pullToRefreshViewLastUpdated:)])
		date = [delegate pullToRefreshViewLastUpdated:self];

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setAMSymbol:@"AM"];
	[formatter setPMSymbol:@"PM"];
	[formatter setDateFormat:@"MM/dd/yy hh:mm a"];
	subtitleLabel.text = [NSString stringWithFormat:@"Last Updated: %@", [formatter stringFromDate:date]];
	[formatter release];
}

- (void)showExplanation {
	[self addSubview:subtitleLabel];
	subtitleLabel.text = [NSString stringWithFormat:@"Try again in a minute."];
}

- (void)didStartLoading:(BOOL)scrollToReveal {
	NSLog(@"entering: in state %i", state);
	if (state == PullToRefreshViewStateLoading) {
		NSLog(@"we're already loading, exiting early");
		return;
	}
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3f];
	[self setState:PullToRefreshViewStateLoading];
	if (scrollToReveal) {
		// work around a possible UIKit bug: the scrollbar animates across the screen from the right side without a temporary scrollbar hide.
		scrollView.showsVerticalScrollIndicator = NO;
		double delayInSeconds = 0.3;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			scrollView.showsVerticalScrollIndicator = YES;
			});

			scrollView.contentInset = UIEdgeInsetsMake(-PullToRefreshTriggerOffset, 0, 0, 0);
			scrollView.contentOffset = (CGPoint){ scrollView.contentOffset.x, PullToRefreshTriggerOffset};
		}
	[UIView commitAnimations];

	timeoutTimer = [NSTimer timerWithTimeInterval:kTimeoutSeconds target:self selector:@selector(loadingTimeout) userInfo:nil repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
}

- (void)didFinishLoading {
	if (state == PullToRefreshViewStateLoading) {
		// remove the old infinite spin, and go back to normal.
		[arrowImage removeAnimationForKey:@"transform.rotation.z"];

		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.4f];
		[self setState:PullToRefreshViewStateNormal];
		[UIView commitAnimations];
	} else {
		NSLog(@"already not loading; in state %i", state);
	}
}

- (void)startInfiniteSpin {
	CALayer *layer = arrowImage;
	CAKeyframeAnimation *animation;
	animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
	animation.duration = 1.0f;
	animation.repeatCount = CGFLOAT_MAX;
	animation.values = [NSArray arrayWithObjects:
	[NSNumber numberWithFloat:0.0 * M_PI],
		[NSNumber numberWithFloat:1.0 * M_PI],
		[NSNumber numberWithFloat:2.0 * M_PI], nil];
	animation.keyTimes = [NSArray arrayWithObjects:
	[NSNumber numberWithFloat:0],
		[NSNumber numberWithFloat:.5],
		[NSNumber numberWithFloat:1.0], nil];
	animation.cumulative = YES;
	animation.removedOnCompletion = NO;

	[layer addAnimation:animation forKey:@"transform.rotation.z"];
}

- (void)setState:(PullToRefreshViewState)state_ {
	if (timeoutTimer) {
		[timeoutTimer invalidate];
		timeoutTimer = nil;
	}

	if (state_ == state) {
		NSLog(@"already in state %i", state_);
		return;
	}

	state = state_;

	switch (state) {
		case PullToRefreshViewStateReady:
		statusLabel.text = @"Release to refresh…";
		[self refreshLastUpdatedDate];
		[self hideArrow:NO];
		[self hideOfflineImage:YES];
		[self setShowsSubtitle:NO];
		scrollView.contentInset = UIEdgeInsetsZero;
		break;

		case PullToRefreshViewStateNormal:			
		statusLabel.text = @"Pull down to refresh…";
		[self refreshLastUpdatedDate];
		[self hideArrow:NO];
		[self hideOfflineImage:YES];
		[self setShowsSubtitle:NO];
		scrollView.contentInset = UIEdgeInsetsZero;
		break;

		case PullToRefreshViewStateLoading:
		statusLabel.text = @"Loading…";
		[self hideArrow:NO];
		[self hideOfflineImage:YES];
		[self setShowsSubtitle:NO];
		scrollView.contentInset = UIEdgeInsetsMake(fminf(-scrollView.contentOffset.y, -PullToRefreshTriggerOffset), 0, 0, 0);
		[self startInfiniteSpin];
		break;

		case PullToRefreshViewStateOffline:
		statusLabel.text = @"Uh oh, bad connection :(";
		[self hideArrow:YES];
		[self hideOfflineImage:NO];
		[self showExplanation];
		[self setShowsSubtitle:YES];
		scrollView.contentInset = UIEdgeInsetsZero;
		break;

		default:
		break;
	}

	[self setNeedsLayout];
}

#pragma mark -
#pragma mark UIScrollView

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"contentOffset"]) {
		if (scrollView.isDragging) {
			// spin the spinner!
			if (scrollView.contentOffset.y < 0) {
				[CATransaction begin];
				[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
				CGFloat percent = scrollView.contentOffset.y / PullToRefreshTriggerOffset;
				arrowImage.transform = CATransform3DMakeRotation(M_PI * percent * -1, 0.0f, 0.0f, 1.0f);
				[CATransaction commit];
			}

			// if we were in a refresh state
			if (state == PullToRefreshViewStateReady) {
				// but now we're in between the "trigger" offset and 0
				if (scrollView.contentOffset.y > PullToRefreshTriggerOffset && scrollView.contentOffset.y < 0.0f) {
					// reset to "pull me to refresh!"
					[self setState:PullToRefreshViewStateNormal];
				}
			} else if (state == PullToRefreshViewStateNormal) {
				// if we're in a normal state and we're above the top of the scrollView and we pass the max
				if (scrollView.contentOffset.y < PullToRefreshTriggerOffset) {
					// go to the ready state.
					[self setState:PullToRefreshViewStateReady];
				}
			} else if (state == PullToRefreshViewStateLoading) {
				// if the user scrolls the view down while we're loading, make sure the loading screen is visible if they scroll to the top:

				if (scrollView.contentOffset.y >= 0) {
					// this lets the table headers float to the top
					scrollView.contentInset = UIEdgeInsetsZero;
				} else {
					// but show loading if they go past the top of the tableview
					scrollView.contentInset = UIEdgeInsetsMake(fminf(-scrollView.contentOffset.y, -PullToRefreshTriggerOffset), 0, 0, 0);
				}
			}
		} else {
			if (state == PullToRefreshViewStateReady) {
				// if we're in state ready and a drag stops, then transition to loading.

				[UIView beginAnimations:nil context:NULL];
				[UIView setAnimationDuration:0.2f];
				[self setState:PullToRefreshViewStateLoading];
				[UIView commitAnimations];

				if ([delegate respondsToSelector:@selector(pullToRefreshViewShouldRefresh:)])
					[delegate pullToRefreshViewShouldRefresh:self];
			}
		}
	}
}

#pragma mark -
#pragma mark Memory management

- (void)containingViewDidUnload {
	[scrollView removeObserver:self forKeyPath:@"contentOffset"];
	[scrollView release];
	scrollView = nil;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (scrollView) { // probably leaking the scrollView
		NSLog(@"Leaking a scrollView?");
		[scrollView release];
	}

	[arrowImage release];
	[statusLabel release];
	[subtitleLabel release];

	[super dealloc];
}

@end
