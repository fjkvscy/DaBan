//
//  LCEChatRoomVC.m
//  LeanChatExample
//
//  Created by lzw on 15/4/7.
//  Copyright (c) 2015年 avoscloud. All rights reserved.
//

#import "LCEChatRoomVC.h"
#import "MSChatHeadView.h"
#import "MSChatModel.h"

@interface LCEChatRoomVC ()
{
    UIImageView *iv;
    UISwipeGestureRecognizer *swipe;
    UISwipeGestureRecognizer *swipe2;
    BOOL isSwipe;
}

@property (nonatomic, strong) MSChatHeadView  *headView;

@property (nonatomic, strong) MSChatModel    *model;

@property (nonatomic, strong) NSArray *emotionManagers;

@property (nonatomic, strong) UIButton  *displayBtn;//最上面的隐藏按钮
@end

@implementation LCEChatRoomVC

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initBottomMenuAndEmotionView];
    UIImage *_peopleImage = [UIImage imageNamed:@"chat_menu_people"];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:_peopleImage style:UIBarButtonItemStyleDone target:self action:@selector(goChatGroupDetail:)];
    self.navigationItem.rightBarButtonItem = item;
    
//    [self request];
    [self drawHeadView];
}

#pragma -mark
#pragma -mark HeadView
-(void)drawHeadView{
    self.displayBtn = [[UIButton alloc]initWithFrame:CGRectMake(SCREEN_WIDTH/2-20, 0, 60, 40)];
    self.displayBtn.backgroundColor = [UIColor clearColor
                                       
                                       ];
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.displayBtn.bounds      byRoundingCorners:UIRectCornerBottomLeft | UIRectCornerBottomRight    cornerRadii:CGSizeMake(2, 2)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.displayBtn.bounds;
    maskLayer.path = maskPath.CGPath;
    self.displayBtn.layer.mask = maskLayer;
    [self.displayBtn addTarget:self action:@selector(displayBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.displayBtn];
    
//    [self addSwipe];
    
    UIImageView *disIV = [[UIImageView alloc]initWithFrame:CGRectMake(10, 0, 40, 20)];
    disIV.backgroundColor = [UIColor whiteColor];
    [self.displayBtn addSubview:disIV];
    
    iv = [[UIImageView alloc]initWithFrame:CGRectMake(12.5, 5, 15, 10)];
    iv.backgroundColor = [UIColor clearColor];
    iv.image = [UIImage imageNamed:@"chat_pull"];
    [disIV addSubview:iv];
    
    self.model = [[MSChatModel alloc]init];
    
    self.headView = [[MSChatHeadView alloc]initWithFrame:CGRectMake(0, -133, SCREEN_WIDTH, 133)];
    self.headView.backgroundColor = [UIColor whiteColor];
    self.model.time = @"今天8:00出发";
    self.model.end = @"南山";
    self.model.start = @"翰林喹非机动车枯井";
    self.model.money = @"99999";
    self.model.headImgs = @[@"http://ac-qgsi8evy.clouddn.com/MqHCKWPS350ux5CkfWdKRKiJddsK2geYIMnsY4lM.jpg",@"http://ac-qgsi8evy.clouddn.com/MqHCKWPS350ux5CkfWdKRKiJddsK2geYIMnsY4lM.jpg",@"http://ac-qgsi8evy.clouddn.com/MqHCKWPS350ux5CkfWdKRKiJddsK2geYIMnsY4lM.jpg"];
    if ([ROLELAB isEqualToString:@"我是车主"]) {
        self.model.type = 1;
    }else{
        self.model.carNumber = @"湘A56452";
        self.model.type = 2;
    }
    self.headView.model = self.model;
    [self.view addSubview:self.headView];
}

-(void)addSwipe{
    //滑动手势感觉有问题
    swipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handleSwipeForm:)];
    [swipe setDirection:UISwipeGestureRecognizerDirectionDown];
    
    swipe2 = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handleSwipeForm:)];
    [swipe2 setDirection:UISwipeGestureRecognizerDirectionUp];
    
    if (isSwipe == NO) {
        [self.displayBtn addGestureRecognizer:swipe];
    }else{
        [self.displayBtn addGestureRecognizer:swipe2];
    }


}

-(void)handleSwipeForm:(UISwipeGestureRecognizer *)recognizer{
    
    if (recognizer.direction == UISwipeGestureRecognizerDirectionDown) {
        [UIView animateWithDuration:0.8 animations:^{
            self.headView.frame = CGRectMake(self.headView.frame.origin.x, self.headView.frame.origin.y+133, self.headView.frame.size.width, self.headView.frame.size.height);
            self.displayBtn.frame = CGRectMake(self.displayBtn.frame.origin.x,self.displayBtn.frame.origin.y+133, self.displayBtn.frame.size.width, self.displayBtn.frame.size.height);
            iv.image = [UIImage imageNamed:@"chat_pull"];
        }];
        isSwipe = YES;
        NSLog(@"111");
    }else if (recognizer.direction == UISwipeGestureRecognizerDirectionUp){
        [UIView animateWithDuration:0.5 animations:^{
            self.headView.frame = CGRectMake(self.headView.frame.origin.x, self.headView.frame.origin.y-133, self.headView.frame.size.width, self.headView.frame.size.height);
            self.displayBtn.frame = CGRectMake(self.displayBtn.frame.origin.x,self.displayBtn.frame.origin.y-133, self.displayBtn.frame.size.width, self.displayBtn.frame.size.height);
            iv.image = [UIImage imageNamed:@"chat_down"];
        }];
        isSwipe = NO;
         NSLog(@"222");
    }
    [self addSwipe];
}

-(void)displayBtnClick:(UIButton *)sender{
    sender.selected = !sender.selected;
    isSwipe = sender.selected;
    if (sender.selected) {
        [UIView animateWithDuration:0.8 animations:^{
            self.headView.frame = CGRectMake(self.headView.frame.origin.x, self.headView.frame.origin.y+133, self.headView.frame.size.width, self.headView.frame.size.height);
            self.displayBtn.frame = CGRectMake(self.displayBtn.frame.origin.x,self.displayBtn.frame.origin.y+133, self.displayBtn.frame.size.width, self.displayBtn.frame.size.height);
            iv.image = [UIImage imageNamed:@"chat_pull"];
        }];
    }else{
        [UIView animateWithDuration:0.5 animations:^{
            self.headView.frame = CGRectMake(self.headView.frame.origin.x, self.headView.frame.origin.y-133, self.headView.frame.size.width, self.headView.frame.size.height);
            self.displayBtn.frame = CGRectMake(self.displayBtn.frame.origin.x,self.displayBtn.frame.origin.y-133, self.displayBtn.frame.size.width, self.displayBtn.frame.size.height);
            iv.image = [UIImage imageNamed:@"chat_down"];
        }];
    }
}


- (void)initBottomMenuAndEmotionView {
    NSMutableArray *shareMenuItems = [NSMutableArray array];
    NSArray *plugIcons = @[@"chat_more_photo", @"chat_more_cam",@"chat_more_speak",@"chat_more_loa"];
    NSArray *plugTitle = @[@"照片", @"拍摄",@"温馨话",@"位置"];
    for (NSString *plugIcon in plugIcons) {
        XHShareMenuItem *shareMenuItem = [[XHShareMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:plugIcon] title:[plugTitle objectAtIndex:[plugIcons indexOfObject:plugIcon]]];
        [shareMenuItems addObject:shareMenuItem];
    }
    self.shareMenuItems = shareMenuItems;
    [self.shareMenuView reloadData];
    
    _emotionManagers = [CDEmotionUtils emotionManagers];
    self.emotionManagerView.isShowEmotionStoreButton = YES;
    [self.emotionManagerView reloadData];
}


- (void)goChatGroupDetail:(id)sender {
    DLog(@"click");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
