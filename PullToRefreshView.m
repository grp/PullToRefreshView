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

- (BOOL)isScrolledToVisible;
- (BOOL)isScrolledToLimit;
- (void)parkVisible;
- (void)handleDragWhileLoading;
- (void)updatePosition;

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
    arrowImage.transform = (flipped ^ isBottom ? CATransform3DMakeRotation(M_PI * 2, 0.0f, 0.0f, 1.0f) : CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 1.0f));
    [UIView commitAnimations];
}

- (id)initWithScrollView:(UIScrollView *)scroll atBottom:(BOOL)bottom {
    CGFloat bottomOffset = (scroll.contentSize.height < scroll.bounds.size.height) ? scroll.bounds.size.height : scroll.contentSize.height;
    CGFloat offset = bottom ? bottomOffset : 0.0f - scroll.bounds.size.height;
    CGRect frame = CGRectMake(0.0f, offset, scroll.bounds.size.width, scroll.bounds.size.height);

	if ((self = [super initWithFrame:frame])) {
        CGFloat visibleBottom = bottom ? -kPullToRefreshViewTriggerOffset : self.frame.size.height;
        isBottom = bottom;
        
#if __has_feature(objc_arc)
        // ARC is On
        scrollView = SAFE_ARC_RETAIN(scroll);
#else
        // ARC is Off
        scrollView = [scroll retain];
#endif
        
		
		[scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];

		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = kPullToRefreshViewBackgroundColor;

		statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, visibleBottom - 48.0f, self.frame.size.width, 20.0f)];
		subtitleLabel.frame = CGRectMake(0.0f, visibleBottom - 30.0f, self.frame.size.width, 20.0f);
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
        UIImage *arrow = [UIImage imageNamed:@"arrow"];
        arrowImage.contents = (id)arrow.CGImage;
        arrowImage.frame = CGRectMake(25.0f, visibleBottom + kPullToRefreshViewTriggerOffset + 5.0f, arrow.size.width, arrow.size.height);
		arrowImage.contentsGravity = kCAGravityResizeAspect;
        [self setImageFlipped:NO];

        activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.frame = CGRectMake(30.0f, visibleBottom - 38.0f, 20.0f, 20.0f);
        [self addSubview:activityView];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
		if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
			arrowImage.contentsScale = [[UIScreen mainScreen] scale];
		}
#endif

		[self.layer addSublayer:arrowImage];
        [self setState:kPullToRefreshViewStateNormal];
	}

	return self;
}

- (id)initWithScrollView:(UIScrollView *)scroll {
    return [self initWithScrollView:scroll atBottom:NO];
}


#pragma mark -
#pragma mark Setters

- (void)setStatusLabelText:(NSString *)text {
    [statusLabel setText:text];
}

- (void)refreshLastUpdatedDate {
    NSDate *date = [NSDate date];

	if ([delegate respondsToSelector:@selector(pullToRefreshViewLastUpdated:)]) {
		date = [delegate pullToRefreshViewLastUpdated:self];
    }

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setAMSymbol:@"AM"];
	[formatter setPMSymbol:@"PM"];
	[formatter setDateFormat:@"MM/dd/yy hh:mm a"];
	subtitleLabel.text = [NSString stringWithFormat:@"Last Updated: %@", [formatter stringFromDate:date]];
    
#if __has_feature(objc_arc)
    // ARC is On
    SAFE_ARC_RELEASE(formatter);
#else
    // ARC is Off
    [formatter release];
#endif
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
		    statusLabel.text = [NSString stringWithFormat:@"Pull %@ to refresh...", isBottom ? @"up" : @"down"];
            [self showActivity:NO animated:NO];
            [self setImageFlipped:NO];
            scrollView.contentInset = UIEdgeInsetsZero;
		    break;
		case kPullToRefreshViewStateLoading:
        case kPullToRefreshViewStateProgrammaticRefresh:
		    statusLabel.text = @"Loading…";
            [self showActivity:YES animated:YES];
            [self setImageFlipped:NO];
            if ([delegate respondsToSelector:@selector(pullToRefreshViewShouldRefresh:)]) {
                [delegate pullToRefreshViewShouldRefresh:self];
            }
		    //scrollView.contentInset = UIEdgeInsetsMake(fminf(-scrollView.contentOffset.y, -kPullToRefreshViewTriggerOffset), 0, 0, 0);
            [self parkVisible];
		    break;
		default:
		    break;
	}

	[self setNeedsLayout];
}

- (BOOL)isScrolledToVisible {
    if (isBottom) {
        BOOL scrolledBelowContent;
        if (scrollView.contentSize.height < scrollView.frame.size.height) {
            scrolledBelowContent = scrollView.contentOffset.y > 0.0f;
        } else {
            scrolledBelowContent = scrollView.contentOffset.y > (scrollView.contentSize.height - scrollView.frame.size.height);
        }
        return scrolledBelowContent && ![self isScrolledToLimit];
    } else {
        BOOL scrolledAboveContent = scrollView.contentOffset.y < 0.0f;
        return scrolledAboveContent && ![self isScrolledToLimit];
    }
}

- (BOOL)isScrolledToLimit {
    if (isBottom) {
        if (scrollView.contentSize.height < scrollView.frame.size.height) {
            return scrollView.contentOffset.y >= -kPullToRefreshViewTriggerOffset;
        } else {
            return scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height) - kPullToRefreshViewTriggerOffset;
        }
    } else {
        return scrollView.contentOffset.y <= kPullToRefreshViewTriggerOffset;
    }
}

- (void)parkVisible {
    if (isBottom) {
        CGFloat extra = (scrollView.frame.size.height - scrollView.contentSize.height);
        if (extra < 0.0f) {
            extra = 0.0f;
            scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, -kPullToRefreshViewTriggerOffset + extra, 0.0f);
        } else {	
            scrollView.contentInset = UIEdgeInsetsMake(-kPullToRefreshViewTriggerOffset, 0.0f, 0.0f, 0.0f);
        }
    }
}

- (void)handleDragWhileLoading {
    if ([self isScrolledToLimit] || [self isScrolledToVisible]) {
        if (isBottom) {	
            CGFloat extra = (scrollView.frame.size.height - scrollView.contentSize.height);
            if (extra < 0.0f) {
                extra = 0.0f;
                CGFloat visiblePortion = scrollView.contentOffset.y - (scrollView.contentSize.height - scrollView.frame.size.height);	
                scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, fminf(visiblePortion, -kPullToRefreshViewTriggerOffset + extra), 0.0f);
            }
        } else {
            scrollView.contentInset = UIEdgeInsetsMake(fminf(-scrollView.contentOffset.y, -kPullToRefreshViewTriggerOffset), 0.0f, 0.0f, 0.0f);
        }
    }
}

- (void)updatePosition {
    if (isBottom) {
        CGFloat bottomOffset = (scrollView.contentSize.height < scrollView.bounds.size.height) ? scrollView.bounds.size.height : scrollView.contentSize.height;
        self.frame = CGRectMake(0.0f, bottomOffset, scrollView.bounds.size.width, scrollView.bounds.size.height);
    }
}

#pragma mark -
#pragma mark UIScrollView

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"contentOffset"]) {
		if (scrollView.isDragging) {
			// if we were in a refresh state
			if (state == kPullToRefreshViewStateReady) {
				// but now we're in between the "trigger" offset and 0
				if ([self isScrolledToVisible]) {
					// reset to "pull me to refresh!"
					[self setState:kPullToRefreshViewStateNormal];
				}
			} else if (state == kPullToRefreshViewStateNormal) {
				// if we're in a normal state and we're above the top of the scrollView and we pass the max
				if ([self isScrolledToLimit]) {
					// go to the ready state.
					[self setState:kPullToRefreshViewStateReady];
				}
			} else if (state == kPullToRefreshViewStateLoading || state == kPullToRefreshViewStateProgrammaticRefresh) {
				// if the user scrolls the view down while we're loading, make sure the loading screen is visible if they scroll to the top:
                [self handleDragWhileLoading];
			}
		} else {
			if (state == kPullToRefreshViewStateReady) {
				// if we're in state ready and a drag stops, then transition to loading.

				[UIView beginAnimations:nil context:NULL];
				[UIView setAnimationDuration:kPullToRefreshViewAnimationDuration];
				[self setState:kPullToRefreshViewStateLoading];
				[UIView commitAnimations];
			}
		}

        // Fix for view moving laterally with webView
        self.frame = CGRectMake(scrollView.contentOffset.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
	} else if ([keyPath isEqualToString:@"contentSize"]) {
        [self updatePosition];
    }
}

#pragma mark -
#pragma mark Memory management

- (void)containingViewDidUnload {
	[scrollView removeObserver:self forKeyPath:@"contentOffset"];
	[scrollView removeObserver:self forKeyPath:@"contentSize"];
    
#if __has_feature(objc_arc)
    SAFE_ARC_RELEASE(scrollView);
#else
    [scrollView release];
#endif
	scrollView = nil;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (scrollView != nil) {
		NSLog(@"PullToRefreshView: Leaking a scrollView?");
#if __has_feature(objc_arc)
        SAFE_ARC_RELEASE(scrollView);
#else
		[scrollView release];
#endif
	}

#if __has_feature(objc_arc)
    SAFE_ARC_RELEASE(arrowImage);
    SAFE_ARC_RELEASE(statusLabel);
    SAFE_ARC_RELEASE(subtitleLabel);
     SAFE_ARC_SUPER_DEALLOC();
#else
    [arrowImage release];
	[statusLabel release];
	[subtitleLabel release];
    [super dealloc];
#endif  
}

@end
