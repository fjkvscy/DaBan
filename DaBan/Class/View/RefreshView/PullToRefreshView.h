//
//  PullToRefreshView.h
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

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "RefreshViewDefinds.h"

typedef enum {
	kPullToRefreshViewStateUninitialized = 0,
	kPullToRefreshViewStateNormal,
	kPullToRefreshViewStateReady,
	kPullToRefreshViewStateLoading,
    kPullToRefreshViewStateProgrammaticRefresh,
	kPullToRefreshViewStateOffline
} PullToRefreshViewState;

@protocol PullToRefreshViewDelegate;

@interface PullToRefreshView : UIView {
	UIScrollView *scrollView;
	PullToRefreshViewState state;

	UILabel *subtitleLabel;
	UILabel *statusLabel;
	CALayer *arrowImage;
	CALayer *offlineImage;
	UIActivityIndicatorView *activityView;
}

@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, weak) id<PullToRefreshViewDelegate> delegate;

- (void)refreshLastUpdatedDate;

- (id)initWithScrollView:(UIScrollView *)scrollView;
- (void)finishedLoading;
- (void)readyForLoading;
- (void)beginLoading;
- (void)containingViewDidUnload;

@end

@protocol PullToRefreshViewDelegate <NSObject>

@optional
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view;
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view;

@end
