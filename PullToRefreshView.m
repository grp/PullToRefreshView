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

#define kPullToRefreshViewBackgroundColor [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0]
#define kPullToRefreshViewTitleColor [UIColor colorWithRed:(87.0/255.0) green:(108.0/255.0) blue:(137.0/255.0) alpha:1.0]
#define kPullToRefreshViewSubtitleColor kPullToRefreshViewTitleColor
#define kPullToRefreshViewAnimationDuration 0.18f
#define kPullToRefreshViewTriggerOffset -65.0f

@interface PullToRefreshView (Private)

@property (nonatomic, assign) PullToRefreshViewState state;

@end

@implementation PullToRefreshView
@synthesize delegate, scrollView;

- (void)showActivity:(BOOL)show animated:(BOOL)animated {
    if (show) [activityView startAnimating];
    else [activityView stopAnimating];

    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:(animated ? kPullToRefreshViewAnimationDuration : 0.0)];
    arrowImage.opacity = (show ? 0.0 : 1.0);
    [UIView commitAnimations];
}

- (void)setImageFlipped:(BOOL)flipped {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kPullToRefreshViewAnimationDuration];
    arrowImage.transform = (flipped ? CATransform3DMakeRotation(M_PI * 2, 0.0f, 0.0f, 1.0f) : CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 1.0f));
    [UIView commitAnimations];
}

- (id)initWithScrollView:(UIScrollView *)scroll {
	CGRect frame = CGRectMake(0.0f, 0.0f - scroll.bounds.size.height, scroll.bounds.size.width, scroll.bounds.size.height);

	if ((self = [super initWithFrame:frame])) {
		scrollView = [scroll retain];
		[scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];

		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = kPullToRefreshViewBackgroundColor;

		subtitleLabel = [[UILabel alloc] init];
		subtitleLabel.frame = CGRectMake(0.0f, frame.size.height - 30.0f, self.frame.size.width, 20.0f);
		subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		subtitleLabel.font = [UIFont systemFontOfSize:12.0f];
		subtitleLabel.textColor = kPullToRefreshViewSubtitleColor;
        subtitleLabel.shadowColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
		subtitleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
		subtitleLabel.backgroundColor = [UIColor clearColor];
		subtitleLabel.textAlignment = UITextAlignmentCenter;
		[self addSubview:subtitleLabel];

		statusLabel = [[UILabel alloc] init];
		statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		statusLabel.font = [UIFont systemFontOfSize:12.f];
		statusLabel.textColor = kPullToRefreshViewTitleColor;
        statusLabel.shadowColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
        statusLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
		statusLabel.backgroundColor = [UIColor clearColor];
		statusLabel.textAlignment = UITextAlignmentCenter;
		[self addSubview:statusLabel];

		arrowImage = [[CALayer alloc] init];
        arrowImage.frame = CGRectMake(25.0f, frame.size.height - 60.0f, 24.0f, 52.0f);
		arrowImage.contentsGravity = kCAGravityResizeAspect;
        arrowImage.contents = (id) [UIImage imageNamed:@"arrow"].CGImage;

        activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.frame = CGRectMake(30.0f, frame.size.height - 38.0f, 20.0f, 20.0f);
        [self addSubview:activityView];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
		if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
			arrowImage.contentsScale = [[UIScreen mainScreen] scale];
		}
#endif

		[self.layer addSublayer:arrowImage];
	}

	return self;
}

#pragma mark -
#pragma mark Setters

- (void)refreshLastUpdatedDate {
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

- (void)beginLoading {
    [self setState:kPullToRefreshViewStateProgrammaticRefresh];
}

- (void)finishedLoading {
    if (state == kPullToRefreshViewStateLoading || state == kPullToRefreshViewStateProgrammaticRefresh) {
        [self refreshLastUpdatedDate];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3f];
        [self setState:kPullToRefreshViewStateNormal];
        [UIView commitAnimations];
    }
}

- (void)setState:(PullToRefreshViewState)state_ {
	if (state_ == state) return;
	state = state_;

	switch (state) {
		case kPullToRefreshViewStateReady:
		    statusLabel.text = @"Release to refresh…";
            [self showActivity:NO animated:NO];
            [self setImageFlipped:YES];
            scrollView.contentInset = UIEdgeInsetsZero;
		    break;
		case kPullToRefreshViewStateNormal:
		    statusLabel.text = @"Pull down to refresh…";
            [self showActivity:NO animated:NO];
            [self setImageFlipped:NO];
            scrollView.contentInset = UIEdgeInsetsZero;
		    break;
		case kPullToRefreshViewStateLoading:
        case kPullToRefreshViewStateProgrammaticRefresh:
		    statusLabel.text = @"Loading…";
            [self showActivity:YES animated:YES];
            [self setImageFlipped:NO];
		    scrollView.contentInset = UIEdgeInsetsMake(fminf(-scrollView.contentOffset.y, -kPullToRefreshViewTriggerOffset), 0, 0, 0);
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
			// if we were in a refresh state
			if (state == kPullToRefreshViewStateReady) {
				// but now we're in between the "trigger" offset and 0
				if (scrollView.contentOffset.y > kPullToRefreshViewTriggerOffset && scrollView.contentOffset.y < 0.0f) {
					// reset to "pull me to refresh!"
					[self setState:kPullToRefreshViewStateNormal];
				}
			} else if (state == kPullToRefreshViewStateNormal) {
				// if we're in a normal state and we're above the top of the scrollView and we pass the max
				if (scrollView.contentOffset.y < kPullToRefreshViewTriggerOffset) {
					// go to the ready state.
					[self setState:kPullToRefreshViewStateReady];
				}
			} else if (state == kPullToRefreshViewStateLoading || state == kPullToRefreshViewStateProgrammaticRefresh) {
				// if the user scrolls the view down while we're loading, make sure the loading screen is visible if they scroll to the top:

				if (scrollView.contentOffset.y >= 0) {
					// this lets the table headers float to the top
					scrollView.contentInset = UIEdgeInsetsZero;
				} else {
					// but show loading if they go past the top of the tableview
					scrollView.contentInset = UIEdgeInsetsMake(fminf(-scrollView.contentOffset.y, -kPullToRefreshViewTriggerOffset), 0, 0, 0);
				}
			}
		} else {
			if (state == kPullToRefreshViewStateReady) {
				// if we're in state ready and a drag stops, then transition to loading.

				[UIView beginAnimations:nil context:NULL];
				[UIView setAnimationDuration:kPullToRefreshViewAnimationDuration];
				[self setState:kPullToRefreshViewStateLoading];
				[UIView commitAnimations];

				if ([delegate respondsToSelector:@selector(pullToRefreshViewShouldRefresh:)])
					[delegate pullToRefreshViewShouldRefresh:self];
			}
		}

        // Fix for view moving laterally with webView
        self.frame = CGRectMake(scrollView.contentOffset.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
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

	if (scrollView != nil) { // probably leaking the scrollView
		NSLog(@"PullToRefreshView: Leaking a scrollView?");
		[scrollView release];
	}

	[arrowImage release];
	[statusLabel release];
	[subtitleLabel release];

	[super dealloc];
}

@end
