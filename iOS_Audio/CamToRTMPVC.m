//
//  CamToRTMPVC.m
//  iOS_Audio
//
//  Created by JimmyJeng on 2016/4/6.
//  Copyright © 2016 JimmyJeng. All rights reserved.
//

#import "CamToRTMPVC.h"
#import "RtmpClient.h"

@interface CamToRTMPVC () <RtmpClientDelegate>
@property (weak, nonatomic) IBOutlet UITextField *textFieldStream;
@property RtmpClient *mRtmpClient;
@property BOOL isStartRecord;
@property (weak, nonatomic) IBOutlet UIButton *btnRecord;
@property (weak, nonatomic) IBOutlet UITextView *logView;
@end

@implementation CamToRTMPVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.mRtmpClient = [[RtmpClient alloc] initWithSampleRate:16000 withEncoder:0];
    [self.mRtmpClient setOutDelegate:self];

    self.isStartRecord = NO;
}


- (IBAction)pressStart:(id)sender {
    if(self.isStartRecord){
        [self.mRtmpClient stopPublish];
        NSLog(@"Stop publish");
    }else {
        NSString* rtmpUrl = [[NSString alloc] initWithFormat:@"%@",self.textFieldStream.text];

        [self.mRtmpClient startPublishWithUrl:rtmpUrl];
        NSLog(@"Start publish with url %@",rtmpUrl);

    }

}

-(void)EventCallback:(int)event{
    NSLog(@"EventCallback %d",event);
    NSString* viewText = _logView.text;
    switch (event) {
        case 1000:
            viewText =  [viewText stringByAppendingString:@"Start Publish\r\n"];
            break;
        case 1001:
            viewText = [viewText stringByAppendingString:@"Publish Success\r\n"];
            [self.btnRecord setTitle:@"Stop" forState:UIControlStateNormal];
            self.isStartRecord = YES;
            break;
        case 1002:
            viewText = [viewText stringByAppendingString:@"Publish Fail\r\n"];
            break;
        case 1004:
            viewText = [viewText stringByAppendingString:@"Publish Done\r\n"];
            [self.btnRecord setTitle:@"Publish" forState:UIControlStateNormal];
            self.isStartRecord = NO;
            break;
        case 2000:
            viewText =  [viewText stringByAppendingString:@"Start Play\r\n"];
            break;
        case 2001:
            viewText = [viewText stringByAppendingString:@"Play Success\r\n"];
//            [self performSelectorOnMainThread:@selector(updatePlayBtn:) withObject:@"Stop" waitUntilDone:YES];
//            isStartPlay = YES;
            break;
        case 2002:
            viewText = [viewText stringByAppendingString:@"Play Fail\r\n"];
            break;
        case 2004:
            viewText = [viewText stringByAppendingString:@"Play done\r\n"];
//            [self performSelectorOnMainThread:@selector(updatePlayBtn:) withObject:@"Play" waitUntilDone:YES];
//            isStartPlay = NO;
            break;
        case 2005:
            viewText = [viewText stringByAppendingString:@"Error or Publish shutdown\r\n"];
            break;
        default:
            break;
    }
    [self performSelectorOnMainThread:@selector(updateLogs:) withObject:viewText waitUntilDone:YES];
}

-(void)updateLogs:(NSString*)text
{
    self.logView.text = text;
}

@end
