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

@interface PullToRefreshView ()

@property (nonatomic, retain) UILabel *statusLabel;
@property (nonatomic, retain) UILabel *subtitleLabel;
@property (nonatomic, retain) UIActivityIndicatorView *activityView;
@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) CALayer *offlineImage;
@property (nonatomic, retain) CALayer *arrowImage;

@property (nonatomic, retain) NSDateFormatter *dateFormatter;

@property (nonatomic, assign, setter=setState:) PullToRefreshViewState state;

@end

@implementation PullToRefreshView

@synthesize statusLabel, subtitleLabel, activityView, scrollView, offlineImage, arrowImage, dateFormatter, state;

- (void)setStatusLabelText:(NSString *)text {
    [self.subtitleLabel setText:text];
}

- (void)beginLoading {
    [self setState:PullToRefreshViewStateProgrammaticRefresh];
}

- (void)refreshLastUpdatedDate {
    NSDate *date = [NSDate date];
    
	if ([self.delegate respondsToSelector:@selector(pullToRefreshViewLastUpdated:)]) {
		date = [self.delegate pullToRefreshViewLastUpdated:self];
    }
    
    self.subtitleLabel.text = [NSString stringWithFormat:@"Last Updated: %@", [self.dateFormatter stringFromDate:date]];
}

- (void)showActivity:(BOOL)shouldShow animated:(BOOL)animated {
    if (shouldShow) {
        [self.activityView startAnimating];
    } else {
        [self.activityView stopAnimating];
    }
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:(animated ? 0.1f : 0.0)];
    self.arrowImage.opacity = (shouldShow ? 0.0 : 1.0);
    [UIView commitAnimations];
}

- (void)setImageFlipped:(BOOL)flipped {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.1f];
    self.arrowImage.transform = (flipped ? CATransform3DMakeRotation(M_PI * 2, 0.0f, 0.0f, 1.0f) : CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 1.0f));
    [UIView commitAnimations];
}

- (id)initWithScrollView:(UIScrollView *)scroll {
    CGRect frame = CGRectMake(0.0f, 0.0f - scroll.bounds.size.height, scroll.bounds.size.width, scroll.bounds.size.height);
    
    if (self = [super initWithFrame:frame]) {
        
        self.dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
        [self.dateFormatter setAMSymbol:@"AM"];
        [self.dateFormatter setPMSymbol:@"PM"];
        [self.dateFormatter setDateFormat:@"MM/dd/yy hh:mm a"];
        
        self.scrollView = scroll;
        [self.scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
        
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = [UIColor clearColor];
        
        self.statusLabel = [[[UILabel alloc]initWithFrame:CGRectMake(0.0f, frame.size.height - 38.0f, self.frame.size.width, 20.0f)]autorelease];
		self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.statusLabel.font = [UIFont boldSystemFontOfSize:18.0f];
        } else {
            self.statusLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        }
        
		self.statusLabel.textColor = [UIColor whiteColor];
		self.statusLabel.shadowColor = [UIColor darkGrayColor];
		self.statusLabel.shadowOffset = CGSizeMake(-1, -1);
		self.statusLabel.backgroundColor = [UIColor clearColor];
		self.statusLabel.textAlignment = UITextAlignmentCenter;
		[self addSubview:self.statusLabel];
        
		self.arrowImage = [[[CALayer alloc]init]autorelease];
        self.arrowImage.frame = CGRectMake(25.0f, frame.size.height - 60.0f, 30.7f, 52.0f); // 30.7f was 24.0f
		self.arrowImage.contentsGravity = kCAGravityCenter;
        self.arrowImage.contentsScale = 2; // scale down the image regardless of retina. The image is by default the retina size.
        self.arrowImage.contents = (id)[UIImage imageNamed:@"arrow"].CGImage;
		[self.layer addSublayer:self.arrowImage];
        
        self.activityView = [[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite]autorelease];
		self.activityView.frame = CGRectMake(30.0f, frame.size.height - 38.0f, 20.0f, 20.0f);
		[self addSubview:self.activityView];
        
		[self setState:PullToRefreshViewStateNormal];
    }
    
    return self;
}

- (void)setState:(PullToRefreshViewState)aState {
    
    if (aState == self.state) {
        return;
    }
    
    state = aState;
    
	switch (self.state) {
		case PullToRefreshViewStateReady:
			self.statusLabel.text = @"Release to refresh...";
			[self showActivity:NO animated:NO];
            [self setImageFlipped:YES];
            self.scrollView.contentInset = UIEdgeInsetsZero;
			break;
            
		case PullToRefreshViewStateNormal:
			self.statusLabel.text = @"Pull down to refresh...";
			[self showActivity:NO animated:NO];
            [self setImageFlipped:NO];
            self.scrollView.contentInset = UIEdgeInsetsZero;
			break;
            
		case PullToRefreshViewStateLoading:
			self.statusLabel.text = @"Loading...";
			[self showActivity:YES animated:YES];
            [self setImageFlipped:NO];
            self.scrollView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
			break;
            
		default:
			break;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) {
        if (self.scrollView.isDragging) {
            if (self.state == PullToRefreshViewStateReady) {
                if (self.scrollView.contentOffset.y > -65.0f && self.scrollView.contentOffset.y < 0.0f)
                    [self setState:PullToRefreshViewStateNormal];
            } else if (self.state == PullToRefreshViewStateNormal) {
                if (self.scrollView.contentOffset.y < -65.0f)
                    [self setState:PullToRefreshViewStateReady];
            } else if (self.state == PullToRefreshViewStateLoading) {
                if (self.scrollView.contentOffset.y >= 0) {
                    self.scrollView.contentInset = UIEdgeInsetsZero;
                } else {
                    self.scrollView.contentInset = UIEdgeInsetsMake(MIN(-self.scrollView.contentOffset.y, 60.0f), 0, 0, 0);
                }
            }
        } else {
            if (self.state == PullToRefreshViewStateReady) {
                [UIView beginAnimations:nil context:NULL];
                [UIView setAnimationDuration:0.2f];
                [self setState:PullToRefreshViewStateLoading];
                [UIView commitAnimations];
                
                if ([self.delegate respondsToSelector:@selector(pullToRefreshViewShouldRefresh:)])
                    [self.delegate pullToRefreshViewShouldRefresh:self];
            }
        }
    }
}

- (void)finishedLoading {
    if (self.state == PullToRefreshViewStateLoading) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3f];
        [self setState:PullToRefreshViewStateNormal];
        [UIView commitAnimations];
    }
}

- (void)dealloc {
	[self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [self setDelegate:nil];
    [self setDateFormatter:nil];
    [super dealloc];
}

@end
