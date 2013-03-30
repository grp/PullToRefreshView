PullToRefreshView
==
Created by @chpwn (Grant Paul)<br>
Reengineered by @natesymer (Nathaniel Symer)

**It is:**

 - a pull-to-refresh implementation
 - very easy to implement
 - doesn't suck

**To implement it:**

*Setup:*

 - Add the four files (PullToRefreshView.{h,m}, arrow.png and arrow@2x.png) to your project
 - Link against QuartzCore.framework
 - `#import "PullToRefreshView.h"`

**Example implementation:**

	- (void)viewDidLoad {
		... viewDidLoad by you ...
		PullToRefreshView *pull = [[PullToRefreshView alloc]initWithScrollView:aScrollView];
   		[pull setDelegate:self];
  		[aScrollView addSubview:pull];
    	[pull release];
	}
	
    - (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)aPull {
    	... your code ...
    	[aPull finishedLoading]; // Use common sense with placement of this line
    }
	
	- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view {
		... your code ...
		return someDate;
	}




    
