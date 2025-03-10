//
//  CDChatRoomController.m
//  LeanChat
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 LeanCloud. All rights reserved.
//

#import <CommonCrypto/CommonCrypto.h>

#import "CDChatRoomVC.h"

#import "XHDisplayTextViewController.h"
#import "XHDisplayMediaViewController.h"
#import "XHDisplayLocationViewController.h"
#import "XHAudioPlayerHelper.h"

#import "LZStatusView.h"
#import "CDEmotionUtils.h"
#import "AVIMConversation+Custom.h"
#import "CDSoundManager.h"
#import "CDConversationStore.h"
#import "CDFailedMessageStore.h"
#import "AVIMEmotionMessage.h"

static NSInteger const kOnePageSize = 10;

@interface CDChatRoomVC ()

@property (nonatomic, strong, readwrite) AVIMConversation *conv;
@property (atomic, assign) BOOL isLoadingMsg;
@property (nonatomic, strong, readwrite) NSMutableArray *msgs;
@property (nonatomic, strong) XHMessageTableViewCell *currentSelectedCell;
@property (nonatomic, strong) NSArray *emotionManagers;
@property (nonatomic, strong) LZStatusView *clientStatusView;

@end

@implementation CDChatRoomVC

#pragma mark - life cycle

- (instancetype)init {
    self = [super init];
    if (self) {
        // 配置输入框UI的样式
        //self.allowsSendVoice = NO;
        //self.allowsSendFace = NO;
        //self.allowsSendMultiMedia = NO;
        _isLoadingMsg = NO;
        self.msgs = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithConv:(AVIMConversation *)conv {
    self = [self init];
    self.conv = conv;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initBarButton];
    [self initBottomMenuAndEmotionView];
    [self.view addSubview:self.clientStatusView];
    // 设置自身用户名
    id<CDUserModel> selfUser = [[CDChatManager manager].userDelegate getUserById:[CDChatManager manager].selfId];
    self.messageSender = [selfUser username];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveMessage:) name:kCDNotificationMessageReceived object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMessageDelivered:) name:kCDNotificationMessageDelivered object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshConv) name:kCDNotificationConversationUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatusView) name:kCDNotificationConnectivityUpdated object:nil];
    [self refreshConv];
    [self loadMessagesWhenInit];
    [self updateStatusView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [CDChatManager manager].chattingConversationId = self.conv.conversationId;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [CDChatManager manager].chattingConversationId = nil;
    if (self.msgs.count > 0) {
        [self updateConversationAsRead];
    }
    [[XHAudioPlayerHelper shareInstance] stopAudio];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCDNotificationMessageReceived object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCDNotificationMessageDelivered object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCDNotificationConversationUpdated object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCDNotificationConnectivityUpdated object:nil];
    [[XHAudioPlayerHelper shareInstance] setDelegate:nil];
}

#pragma mark - ui init

- (void)initBarButton {
    UIBarButtonItem *backBtn = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:nil action:nil];
    [self.navigationItem setBackBarButtonItem:backBtn];
    //    self.navigationItem.backBarButtonItem.title
}

- (void)initBottomMenuAndEmotionView {
    NSMutableArray *shareMenuItems = [NSMutableArray array];
    NSArray *plugIcons = @[@"sharemore_pic", @"sharemore_video"];
    NSArray *plugTitle = @[@"照片", @"拍摄"];
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

- (void)refreshConv {
    self.title = self.conv.title;
}

#pragma mark - connect status view

- (LZStatusView *)clientStatusView {
    if (_clientStatusView == nil) {
        _clientStatusView = [[LZStatusView alloc] initWithFrame:CGRectMake(0, 64, self.messageTableView.frame.size.width, kLZStatusViewHight)];
        _clientStatusView.hidden = YES;
    }
    return _clientStatusView;
}

- (void)updateStatusView {
    if ([CDChatManager manager].connect) {
        self.clientStatusView.hidden = YES;
    } else {
        self.clientStatusView.hidden = NO;
    }
}

#pragma mark - XHMessageTableViewCell delegate

- (void)multiMediaMessageDidSelectedOnMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath onMessageTableViewCell:(XHMessageTableViewCell *)messageTableViewCell {
    UIViewController *disPlayViewController;
    switch (message.messageMediaType) {
        case XHBubbleMessageMediaTypeVideo:
        case XHBubbleMessageMediaTypePhoto: {
            XHDisplayMediaViewController *messageDisplayTextView = [[XHDisplayMediaViewController alloc] init];
            messageDisplayTextView.message = message;
            disPlayViewController = messageDisplayTextView;
            break;
        }
            break;
            
        case XHBubbleMessageMediaTypeVoice: {
            // Mark the voice as read and hide the red dot.
            //message.isRead = YES;
            //messageTableViewCell.messageBubbleView.voiceUnreadDotImageView.hidden = YES;
            [[XHAudioPlayerHelper shareInstance] setDelegate:self];
            if (_currentSelectedCell) {
                [_currentSelectedCell.messageBubbleView.animationVoiceImageView stopAnimating];
            }
            if (_currentSelectedCell == messageTableViewCell) {
                [messageTableViewCell.messageBubbleView.animationVoiceImageView stopAnimating];
                [[XHAudioPlayerHelper shareInstance] stopAudio];
                self.currentSelectedCell = nil;
            }
            else {
                self.currentSelectedCell = messageTableViewCell;
                [messageTableViewCell.messageBubbleView.animationVoiceImageView startAnimating];
                [[XHAudioPlayerHelper shareInstance] managerAudioWithFileName:message.voicePath toPlay:YES];
            }
            break;
        }
            
        case XHBubbleMessageMediaTypeEmotion:
            DLog(@"facePath : %@", message.emotionPath);
            break;
            
        case XHBubbleMessageMediaTypeLocalPosition: {
            DLog(@"facePath : %@", message.localPositionPhoto);
            XHDisplayLocationViewController *displayLocationViewController = [[XHDisplayLocationViewController alloc] init];
            displayLocationViewController.message = message;
            disPlayViewController = displayLocationViewController;
            break;
        }
        default:
            break;
    }
    if (disPlayViewController) {
        [self.navigationController pushViewController:disPlayViewController animated:YES];
    }
}

- (void)didDoubleSelectedOnTextMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath {
    DLog(@"text : %@", message.text);
    XHDisplayTextViewController *displayTextViewController = [[XHDisplayTextViewController alloc] init];
    displayTextViewController.message = message;
    [self.navigationController pushViewController:displayTextViewController animated:YES];
}

- (void)didSelectedAvatorOnMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath {
    DLog(@"indexPath : %@", indexPath);
}

- (void)menuDidSelectedAtBubbleMessageMenuSelecteType:(XHBubbleMessageMenuSelecteType)bubbleMessageMenuSelecteType {
}

- (void)didRetrySendMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath {
    [self resendMessageAtIndexPath:indexPath discardIfFailed:false];
}

#pragma mark - XHAudioPlayerHelper Delegate

- (void)didAudioPlayerStopPlay:(AVAudioPlayer *)audioPlayer {
    if (!_currentSelectedCell) {
        return;
    }
    [_currentSelectedCell.messageBubbleView.animationVoiceImageView stopAnimating];
    self.currentSelectedCell = nil;
}

#pragma mark - XHEmotionManagerView DataSource

- (NSInteger)numberOfEmotionManagers {
    return self.emotionManagers.count;
}

- (XHEmotionManager *)emotionManagerForColumn:(NSInteger)column {
    return [self.emotionManagers objectAtIndex:column];
}

- (NSArray *)emotionManagersAtManager {
    return self.emotionManagers;
}

#pragma mark - XHMessageTableViewController Delegate

- (BOOL)shouldLoadMoreMessagesScrollToTop {
    return YES;
}

- (void)loadMoreMessagesScrollTotop {
    [self loadOldMessages];
}

#pragma mark - didSend delegate

//发送文本消息的回调方法
- (void)didSendText:(NSString *)text fromSender:(NSString *)sender onDate:(NSDate *)date {
    if ([text length] > 0) {
        AVIMTextMessage *msg = [AVIMTextMessage messageWithText:[CDEmotionUtils plainStringFromEmojiString:text] attributes:nil];
        [self sendMsg:msg];
        [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeText];
    }
}

//发送图片消息的回调方法
- (void)didSendPhoto:(UIImage *)photo fromSender:(NSString *)sender onDate:(NSDate *)date {
    [self sendImage:photo];
    [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypePhoto];
}

// 发送视频消息的回调方法
- (void)didSendVideoConverPhoto:(UIImage *)videoConverPhoto videoPath:(NSString *)videoPath fromSender:(NSString *)sender onDate:(NSDate *)date {
    AVIMVideoMessage* sendVideoMessage = [AVIMVideoMessage messageWithText:nil attachedFilePath:videoPath attributes:nil];
    [self sendMsg:sendVideoMessage];
}

// 发送语音消息的回调方法
- (void)didSendVoice:(NSString *)voicePath voiceDuration:(NSString *)voiceDuration fromSender:(NSString *)sender onDate:(NSDate *)date {
    AVIMTypedMessage *msg = [AVIMAudioMessage messageWithText:nil attachedFilePath:voicePath attributes:nil];
    [self sendMsg:msg];
}

// 发送表情消息的回调方法
- (void)didSendEmotion:(NSString *)emotion fromSender:(NSString *)sender onDate:(NSDate *)date {
    if ([emotion hasPrefix:@":"]) {
        // 普通表情
        UITextView *textView = self.messageInputView.inputTextView;
        NSRange range = [textView selectedRange];
        NSMutableString *str = [[NSMutableString alloc] initWithString:textView.text];
        [str deleteCharactersInRange:range];
        [str insertString:emotion atIndex:range.location];
        textView.text = [CDEmotionUtils emojiStringFromString:str];
        textView.selectedRange = NSMakeRange(range.location + emotion.length, 0);
        [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeEmotion];
    } else {
        AVIMEmotionMessage *msg = [AVIMEmotionMessage messageWithEmotionPath:emotion];
        [self sendMsg:msg];
        [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeEmotion];
    }
}
// 发送地图位置的回调方法
- (void)didSendGeoLocationsPhoto:(UIImage *)geoLocationsPhoto geolocations:(NSString *)geolocations location:(CLLocation *)location fromSender:(NSString *)sender onDate:(NSDate *)date {
    
    [self sendLocationWithLatitude:location.coordinate.latitude longitude:location.coordinate.longitude address:geolocations];
    NSLog(@"-----%@",geolocations);
    [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeLocalPosition];
 
}

#pragma mark -  ui config

// 是否显示时间轴Label的回调方法
- (BOOL)shouldDisplayTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        return YES;
    }
    else {
        XHMessage *msg = [self.messages objectAtIndex:indexPath.row];
        XHMessage *lastMsg = [self.messages objectAtIndex:indexPath.row - 1];
        int interval = [msg.timestamp timeIntervalSinceDate:lastMsg.timestamp];
        if (interval > 60 * 3) {
            return YES;
        }
        else {
            return NO;
        }
    }
}

// 配置Cell的样式或者字体
- (void)configureCell:(XHMessageTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    XHMessage *msg = [self.messages objectAtIndex:indexPath.row];
    if ([self shouldDisplayTimestampForRowAtIndexPath:indexPath]) {
        NSDate *ts = msg.timestamp;
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"MM-dd HH:mm"];
        NSString *str = [dateFormatter stringFromDate:ts];
        cell.timestampLabel.text = str;
    }
    SETextView *textView = cell.messageBubbleView.displayTextView;
    if (msg.bubbleMessageType == XHBubbleMessageTypeSending) {
        [textView setTextColor:[UIColor whiteColor]];
    }
    else {
        [textView setTextColor:[UIColor blackColor]];
    }
}

// 协议回掉是否支持用户手动滚动
- (BOOL)shouldPreventScrollToBottomWhileUserScrolling {
    return YES;
}

- (void)didSelecteShareMenuItem:(XHShareMenuItem *)shareMenuItem atIndex:(NSInteger)index {
    [super didSelecteShareMenuItem:shareMenuItem atIndex:index];
}

#pragma mark - @ reference other

- (void)didInputAtSignOnMessageTextView:(XHMessageTextView *)messageInputTextView {
    
}

#pragma mark - alert and async utils

- (void)alert:(NSString *)msg {
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:nil message:msg delegate:nil
                              cancelButtonTitle   :@"确定" otherButtonTitles:nil];
    [alertView show];
}

- (BOOL)alertError:(NSError *)error {
    if (error) {
        if (error.code == kAVIMErrorConnectionLost) {
            [self alert:@"未能连接聊天服务"];
        }
        else if ([error.domain isEqualToString:NSURLErrorDomain]) {
            [self alert:@"网络连接发生错误"];
        }
        else {
            [self alert:[NSString stringWithFormat:@"%@", error]];
        }
        return YES;
    }
    return NO;
}

- (BOOL)filterError:(NSError *)error {
    return [self alertError:error] == NO;
}


- (void)runInMainQueue:(void (^)())queue {
    dispatch_async(dispatch_get_main_queue(), queue);
}

- (void)runInGlobalQueue:(void (^)())queue {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), queue);
}

#pragma mark - LeanCloud

#pragma mark - conversations store

- (void)updateConversationAsRead {
    [[CDConversationStore store] insertConversation:self.conv];
    [[CDConversationStore store] updateUnreadCountToZeroWithConversation:self.conv];
    [[CDConversationStore store] updateMentioned:NO conversation:self.conv];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCDNotificationUnreadsUpdated object:nil];
}

#pragma mark - send message

- (void)sendImage:(UIImage *)image {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.6);
    NSString *path = [[CDChatManager manager] tmpPath];
    NSError *error;
    [imageData writeToFile:path options:NSDataWritingAtomic error:&error];
    if (error == nil) {
        AVIMImageMessage *msg = [AVIMImageMessage messageWithText:nil attachedFilePath:path attributes:nil];
        [self sendMsg:msg];
    }
    else {
        [self alert:@"write image to file error"];
    }
}

- (void)sendLocationWithLatitude:(double)latitude longitude:(double)longitude address:(NSString *)address {
    AVIMLocationMessage *locMsg = [AVIMLocationMessage messageWithText:address latitude:latitude longitude:longitude attributes:nil];
    [self sendMsg:locMsg];
}

- (void)sendMsg:(AVIMTypedMessage *)msg {
    [[CDChatManager manager] sendMessage:msg conversation:self.conv callback:^(BOOL succeeded, NSError *error) {
        if (error) {
            // 伪造一个 messageId，重发的成功的时候，根据这个伪造的id把数据库中的改过来
            msg.messageId = [[CDChatManager manager] uuid];
            msg.sendTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
            if (msg.conversationId == nil) {
                //文件没有保存上会导致 conversationId 为空
                msg.clientId = [CDChatManager manager].selfId;
                msg.conversationId = self.conv.conversationId;
            }
            [[CDFailedMessageStore store] insertFailedMessage:msg];
            [[CDSoundManager manager] playSendSoundIfNeed];
            [self insertMessage:msg];
        } else {
            [[CDSoundManager manager] playSendSoundIfNeed];
            [self insertMessage:msg];
        }
    }];
}

- (void)replaceMesssage:(AVIMTypedMessage *)message atIndexPath:(NSIndexPath *)indexPath {
    self.msgs[indexPath.row] = message;
    XHMessage *xhMessage = [self getXHMessageByMsg:message];
    self.messages[indexPath.row] = xhMessage;
    [self.messageTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)resendMessageAtIndexPath:(NSIndexPath *)indexPath discardIfFailed:(BOOL)discardIfFailed {
    AVIMTypedMessage *msg = self.msgs[indexPath.row];
    msg.status = AVIMMessageStatusSending;
    [self replaceMesssage:msg atIndexPath:indexPath];
    NSString *recordId = msg.messageId;
    [[CDChatManager manager] sendMessage:msg conversation:self.conv callback:^(BOOL succeeded, NSError *error) {
        if (error) {
            if (discardIfFailed) {
                // 服务器连通的情况下重发依然失败，说明消息有问题，如音频文件不存在，删掉这条消息
                [[CDFailedMessageStore store] deleteFailedMessageByRecordId:recordId];
                // 显示失败状态。列表里就让它存在吧，反正也重发不出去
                [self replaceMesssage:msg atIndexPath:indexPath];
            } else {
                [self alertError:error];
                [self replaceMesssage:msg atIndexPath:indexPath];
            }
        }
        else {
            [[CDFailedMessageStore store] deleteFailedMessageByRecordId:recordId];
            [self replaceMesssage:msg atIndexPath:indexPath];
        }
    }];
}

#pragma mark - receive and delivered

- (void)receiveMessage:(NSNotification *)notification {
    AVIMTypedMessage *message = notification.object;
    if ([message.conversationId isEqualToString:self.conv.conversationId]) {
        if (self.conv.muted == NO) {
            [[CDSoundManager manager] playReceiveSoundIfNeed];
        }
        [self insertMessage:message];
        //        [[CDChatManager manager] setZeroUnreadWithConversationId:self.conv.conversationId];
        //        [[NSNotificationCenter defaultCenter] postNotificationName:kCDNotificationMessageReceived object:nil];
    }
}

- (void)onMessageDelivered:(NSNotification *)notification {
    AVIMTypedMessage *message = notification.object;
    if ([message.conversationId isEqualToString:self.conv.conversationId]) {
        AVIMTypedMessage *foundMessage;
        NSInteger pos;
        for (pos = 0; pos < self.msgs.count; pos++) {
            AVIMTypedMessage *msg = self.msgs[pos];
            if ([msg.messageId isEqualToString:message.messageId]) {
                foundMessage = msg;
                break;
            }
        }
        if (foundMessage !=nil) {
            foundMessage.status = AVIMMessageStatusDelivered;
            XHMessage *xhMsg = [self getXHMessageByMsg:foundMessage];
            [self.messages setObject:xhMsg atIndexedSubscript:pos];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:pos inSection:0];
            [self.messageTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [self scrollToBottomAnimated:YES];
        }
    }
}

#pragma mark - modal convert

- (NSDate *)getTimestampDate:(int64_t)timestamp {
    return [NSDate dateWithTimeIntervalSince1970:timestamp / 1000];
}

- (XHMessage *)getXHMessageByMsg:(AVIMTypedMessage *)msg {
    id <CDUserModel> fromUser = [[CDChatManager manager].userDelegate getUserById:msg.clientId];
    XHMessage *xhMessage;
    NSDate *time = [self getTimestampDate:msg.sendTimestamp];
    if (msg.mediaType == kAVIMMessageMediaTypeText) {
        AVIMTextMessage *textMsg = (AVIMTextMessage *)msg;
        xhMessage = [[XHMessage alloc] initWithText:[CDEmotionUtils emojiStringFromString:textMsg.text] sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeAudio) {
        AVIMAudioMessage *audioMsg = (AVIMAudioMessage *)msg;
        NSString *duration = [NSString stringWithFormat:@"%.0f", audioMsg.duration];
        xhMessage = [[XHMessage alloc] initWithVoicePath:audioMsg.file.localPath voiceUrl:nil voiceDuration:duration sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeLocation) {
        AVIMLocationMessage *locationMsg = (AVIMLocationMessage *)msg;
        xhMessage = [[XHMessage alloc] initWithLocalPositionPhoto:[UIImage imageNamed:@"Fav_Cell_Loc"] geolocations:locationMsg.text location:[[CLLocation alloc] initWithLatitude:locationMsg.latitude longitude:locationMsg.longitude] sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeImage) {
        AVIMImageMessage *imageMsg = (AVIMImageMessage *)msg;
        UIImage *image;
        NSError *error;
        NSData *data = [imageMsg.file getData:&error];
        if (error) {
            DLog(@"get Data error: %@", error);
        } else {
            image = [UIImage imageWithData:data];
        }
        xhMessage = [[XHMessage alloc] initWithPhoto:image thumbnailUrl:nil originPhotoUrl:nil sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeEmotion) {
        AVIMEmotionMessage *emotionMsg = (AVIMEmotionMessage *)msg;
        NSString *path = [[NSBundle mainBundle] pathForResource:emotionMsg.emotionPath ofType:@"gif"];
        xhMessage = [[XHMessage alloc] initWithEmotionPath:path sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeVideo) {
        AVIMVideoMessage *videoMsg = (AVIMVideoMessage *)msg;
        NSString *path = [[CDChatManager manager] videoPathOfMessag:videoMsg];
        xhMessage = [[XHMessage alloc] initWithVideoConverPhoto:[XHMessageVideoConverPhotoFactory videoConverPhotoWithVideoPath:path] videoPath:path videoUrl:nil sender:fromUser.username timestamp:time];
    } else {
        xhMessage = [[XHMessage alloc] initWithText:@"未知消息" sender:fromUser.username timestamp:time];
        DLog("unkonwMessage");
    }
    
    xhMessage.avator = nil;
    xhMessage.avatorUrl = [fromUser avatarUrl];
    
    if ([[CDChatManager manager].selfId isEqualToString:msg.clientId]) {
        xhMessage.bubbleMessageType = XHBubbleMessageTypeSending;
    }
    else {
        xhMessage.bubbleMessageType = XHBubbleMessageTypeReceiving;
    }
    NSInteger msgStatuses[4] = { AVIMMessageStatusSending, AVIMMessageStatusSent, AVIMMessageStatusDelivered, AVIMMessageStatusFailed };
    NSInteger xhMessageStatuses[4] = { XHMessageStatusSending, XHMessageStatusSent, XHMessageStatusReceived, XHMessageStatusFailed };
    
    if (self.conv.type == CDConvTypeGroup) {
        if (msg.status == AVIMMessageStatusSent) {
            msg.status = AVIMMessageStatusDelivered;
        }
    }
    if (xhMessage.bubbleMessageType == XHBubbleMessageTypeSending) {
        XHMessageStatus status = XHMessageStatusReceived;
        int i;
        for (i = 0; i < 4; i++) {
            if (msgStatuses[i] == msg.status) {
                status = xhMessageStatuses[i];
                break;
            }
        }
        xhMessage.status = status;
    }
    else {
        xhMessage.status = XHMessageStatusReceived;
    }
    return xhMessage;
}

- (NSMutableArray *)getXHMessages:(NSArray *)msgs {
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    for (AVIMTypedMessage *msg in msgs) {
        XHMessage *xhMsg = [self getXHMessageByMsg:msg];
        if (xhMsg) {
            [messages addObject:xhMsg];
        }
    }
    return messages;
}

#pragma mark - query messages

- (void)queryAndCacheMessagesWithTimestamp:(int64_t)timestamp block:(AVIMArrayResultBlock)block {
    [[CDChatManager manager] queryTypedMessagesWithConversation:self.conv timestamp:timestamp limit:kOnePageSize block:^(NSArray *msgs, NSError *error) {
        if (error) {
            block(msgs, error);
        } else {
            [self cacheMsgs:msgs callback:^(BOOL succeeded, NSError *error) {
                block (msgs, error);
            }];
        }
    }];
}

- (void)loadMessagesWhenInit {
    if (self.isLoadingMsg) {
        return;
    } else {
        self.isLoadingMsg = YES;
        [self queryAndCacheMessagesWithTimestamp:0 block:^(NSArray *msgs, NSError *error) {
            if ([self filterError:error]) {
                // 失败消息加到末尾，因为 SDK 缓存不保存它们
                NSArray *failedMessages = [[CDFailedMessageStore store] selectFailedMessagesByConversationId:self.conv.conversationId];
                NSMutableArray *allMessages = [NSMutableArray arrayWithArray:msgs];
                [allMessages addObjectsFromArray:failedMessages];
                
                NSMutableArray *xhMsgs = [self getXHMessages:allMessages];
                self.messages = xhMsgs;
                self.msgs = allMessages;
                [self.messageTableView reloadData];
                [self scrollToBottomAnimated:NO];
                
                if (self.msgs.count > 0) {
                    [self updateConversationAsRead];
                }
                
                // 如果连接上，则重发所有的失败消息。若夹杂在历史消息中间不好处理
                if ([CDChatManager manager].connect) {
                    for (NSInteger row = msgs.count;row < allMessages.count; row ++) {
                        [self resendMessageAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] discardIfFailed:YES];
                    }
                }
            }
            self.isLoadingMsg = NO;
        }];
    }
}

- (void)loadOldMessages{
    if (self.messages.count == 0 || self.isLoadingMsg) {
        return;
    } else {
        self.isLoadingMsg = YES;
        AVIMTypedMessage *msg = [self.msgs objectAtIndex:0];
        int64_t timestamp = msg.sendTimestamp;
        [self queryAndCacheMessagesWithTimestamp:timestamp block:^(NSArray *msgs, NSError *error) {
            if ([self filterError:error]) {
                NSMutableArray *xhMsgs = [[self getXHMessages:msgs] mutableCopy];
                NSMutableArray *newMsgs = [NSMutableArray arrayWithArray:msgs];
                [newMsgs addObjectsFromArray:self.msgs];
                self.msgs = newMsgs;
                [self insertOldMessages:xhMsgs completion: ^{
                    self.isLoadingMsg = NO;
                }];
            } else {
                self.isLoadingMsg = NO;
            }
        }];
    }
}

- (void)cacheMsgs:(NSArray *)msgs callback:(AVBooleanResultBlock)callback {
    [self runInGlobalQueue:^{
        NSMutableSet *userIds = [[NSMutableSet alloc] init];
        for (AVIMTypedMessage *msg in msgs) {
            [userIds addObject:msg.clientId];
            if (msg.mediaType == kAVIMMessageMediaTypeImage || msg.mediaType == kAVIMMessageMediaTypeAudio) {
                AVFile *file = msg.file;
                if (file && file.isDataAvailable == NO) {
                    NSError *error;
                    // 下载到本地
                    NSData *data = [file getData:&error];
                    if (error || data == nil) {
                        DLog(@"download file error : %@", error);
                    }
                }
            } else if (msg.mediaType == kAVIMMessageMediaTypeVideo) {
                NSString *path = [[CDChatManager manager] videoPathOfMessag:(AVIMVideoMessage *)msg];
                if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                    NSError *error;
                    NSData *data = [msg.file getData:&error];
                    if (error) {
                        DLog(@"download file error : %@", error);
                    } else {
                        [data writeToFile:path atomically:YES];
                    }
                }
            }
        }
        if ([[CDChatManager manager].userDelegate respondsToSelector:@selector(cacheUserByIds:block:)]) {
            [[CDChatManager manager].userDelegate cacheUserByIds:userIds block:^(BOOL succeeded, NSError *error) {
                [self runInMainQueue:^{
                    callback(succeeded, error);
                }];
            }];
        } else {
            [self runInMainQueue:^{
                callback(YES, nil);
            }];
        }
    }];
}

- (void)insertMessage:(AVIMTypedMessage *)message {
    if (self.isLoadingMsg) {
        [self performSelector:@selector(insertMessage:) withObject:message afterDelay:1];
        return;
    }
    self.isLoadingMsg = YES;
    [self cacheMsgs:@[message] callback:^(BOOL succeeded, NSError *error) {
        if ([self filterError:error]) {
            XHMessage *xhMessage = [self getXHMessageByMsg:message];
            [self.msgs addObject:message];
            [self.messages addObject:xhMessage];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.msgs.count -1 inSection:0];
            [self.messageTableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [self scrollToBottomAnimated:YES];
        }
        self.isLoadingMsg = NO;
    }];
}

@end
