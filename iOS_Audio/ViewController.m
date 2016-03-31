//
//  ViewController.m
//  iOS_Audio
//
//  Created by JimmyJeng on 2016/3/31.
//  Copyright © 2016年 JimmyJeng. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelState;
@property AQRecorderState recordState;
@property AQPlayerState playState;
@property CFURLRef fileURL;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _recordState.mIsRunning = false;
    _playState.mIsRunning = false;

    char path[256];
    [self getFilename:path maxLenth:sizeof path];
    _fileURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8*)path, strlen(path), false);
    NSLog(@"fileURL :%@",_fileURL);

}

static void HandleInputBuffer (void                                *aqData,
                               AudioQueueRef                       inAQ,
                               AudioQueueBufferRef                 inBuffer,
                               const AudioTimeStamp                *inStartTime,
                               UInt32                              inNumPackets,
                               const AudioStreamPacketDescription  *inPacketDesc)
{

    AQRecorderState *recordState = (AQRecorderState*)aqData;
    if (!recordState->mIsRunning)
    {
        NSLog(@"Not recording, returning\n");
    }

    // if (inNumberPacketDescriptions == 0 && recordState->dataFormat.mBytesPerPacket != 0)
    // {
    //     inNumberPacketDescriptions = inBuffer->mAudioDataByteSize / recordState->dataFormat.mBytesPerPacket;
    // }

    NSLog(@"Writing buffer %lld\n", recordState->mCurrentPacket);

    OSStatus status = AudioFileWritePackets(recordState->mAudioFile,
                                            false,
                                            inBuffer->mAudioDataByteSize,
                                            inPacketDesc,
                                            recordState->mCurrentPacket,
                                            &inNumPackets,
                                            inBuffer->mAudioData);
    if (status == 0)
    {
        recordState->mCurrentPacket += inNumPackets;
    }

    AudioQueueEnqueueBuffer(recordState->mQueue, inBuffer, 0, NULL);

}

static void HandleOutputBuffer (void                 *aqData,
                                AudioQueueRef        inAQ,
                                AudioQueueBufferRef  inBuffer)
{

    AQPlayerState* playState = (AQPlayerState*)aqData;
    if(!playState->mIsRunning)
    {
        NSLog(@"Not playing, returning\n");
        return;
    }

    NSLog(@"Queuing buffer %lld for playback\n", playState->mCurrentPacket);

    AudioStreamPacketDescription* packetDescs;

    UInt32 bytesRead;
    UInt32 numPackets = 8000;
    OSStatus status;
    status = AudioFileReadPackets(playState->mAudioFile,
                                  false,
                                  &bytesRead,
                                  packetDescs,
                                  playState->mCurrentPacket,
                                  &numPackets,
                                  inBuffer->mAudioData);

    if (numPackets)
    {
        inBuffer->mAudioDataByteSize = bytesRead;
        status = AudioQueueEnqueueBuffer(playState->mQueue,
                                         inBuffer,
                                         0,
                                         packetDescs);

        playState->mCurrentPacket += numPackets;
    }
    else
    {
        if (playState->mIsRunning)
        {
            AudioQueueStop(playState->mQueue, false);
            AudioFileClose(playState->mAudioFile);
            playState->mIsRunning = false;
        }

        AudioQueueFreeBuffer(playState->mQueue, inBuffer);
    }
}

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
    format->mSampleRate = 8000.0;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFramesPerPacket = 1;
    format->mChannelsPerFrame = 1;
    format->mBytesPerFrame = 2;
    format->mBytesPerPacket = 2;
    format->mBitsPerChannel = 16;
    format->mReserved = 0;
    format->mFormatFlags = kLinearPCMFormatFlagIsBigEndian     |
    kLinearPCMFormatFlagIsSignedInteger |
    kLinearPCMFormatFlagIsPacked;
}

- (void)startRecording {
    NSLog(@"startRecording");
    [self setupAudioFormat:&_recordState.mDataFormat];
    _recordState.mCurrentPacket = 0;

    OSStatus status;
    status = AudioQueueNewInput(&_recordState.mDataFormat,
                                HandleInputBuffer,
                                &_recordState,
                                CFRunLoopGetCurrent(),
                                kCFRunLoopCommonModes,
                                0,
                                &_recordState.mQueue);

    if (status == 0) {
        for (int i = 0; i < kNumberBuffers; i++)
        {
            AudioQueueAllocateBuffer(_recordState.mQueue, 16000, &_recordState.mBuffers[i]);
            AudioQueueEnqueueBuffer (_recordState.mQueue, _recordState.mBuffers[i], 0, NULL);
        }

        status = AudioFileCreateWithURL(_fileURL,
                                        kAudioFileAIFFType,
                                        &_recordState.mDataFormat,
                                        kAudioFileFlags_EraseFile,
                                        &_recordState.mAudioFile);
        if (status == 0)
        {
            _recordState.mIsRunning = true;
            status = AudioQueueStart(_recordState.mQueue, NULL);
            if (status == 0)
            {
                self.labelState.text = @"Recording";
            }
        }
    }
    else {
        [self stopRecording];
        self.labelState.text = @"Record Failed";
    }
}

- (void)stopRecording {
    NSLog(@"stopRecording");
    _recordState.mIsRunning = false;

    AudioQueueStop(_recordState.mQueue, true);
    for(int i = 0; i < kNumberBuffers; i++)
    {
        AudioQueueFreeBuffer(_recordState.mQueue, _recordState.mBuffers[i]);
    }

    AudioQueueDispose(_recordState.mQueue, true);
    AudioFileClose(_recordState.mAudioFile);
    self.labelState.text = @"Idle";
}

- (void)startPlayback {
    NSLog(@"startPlayback");
    _playState.mCurrentPacket = 0;

    [self setupAudioFormat:&_playState.mDataFormat];

    OSStatus status;
    status = AudioFileOpenURL(_fileURL, kAudioFileReadPermission, kAudioFileAIFFType, &_playState.mAudioFile);
    if (status == 0)
    {
        status = AudioQueueNewOutput(&_playState.mDataFormat,
                                     HandleOutputBuffer,
                                     &_playState,
                                     CFRunLoopGetCurrent(),
                                     kCFRunLoopCommonModes,
                                     0,
                                     &_playState.mQueue);

        if (status == 0)
        {
            // Allocate and prime playback buffers
            _playState.mIsRunning = true;
            for (int i = 0; i < kNumberBuffers && _playState.mIsRunning; i++)
            {
                AudioQueueAllocateBuffer(_playState.mQueue, 16000, &_playState.mBuffers[i]);
                HandleOutputBuffer(&_playState, _playState.mQueue, _playState.mBuffers[i]);
            }

            status = AudioQueueStart(_playState.mQueue, NULL);
            if (status == 0)
            {
                self.labelState.text = @"Playing";
            }
        }
    }
    else{
        [self stopPlayback];
        self.labelState.text = @"Play failed";
    }
}

- (void)stopPlayback {
    NSLog(@"stopPlayback");
    _playState.mIsRunning = false;

    for(int i = 0; i < kNumberBuffers; i++)
    {
        AudioQueueFreeBuffer(_playState.mQueue, _playState.mBuffers[i]);
    }

    AudioQueueDispose(_playState.mQueue, true);
    AudioFileClose(_playState.mAudioFile);
}

- (BOOL)getFilename:(char*)buffer maxLenth:(int)maxBufferLength
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString* docDir = [paths objectAtIndex:0];

    NSString* file = [docDir stringByAppendingString:@"/recording.aif"];
    return [file getCString:buffer maxLength:maxBufferLength encoding:NSUTF8StringEncoding];
}

- (IBAction)pressRecord:(id)sender {
    if (!self.playState.mIsRunning) {
        if (!self.recordState.mIsRunning) {
            [self startRecording];
        }
        else {
            NSLog(@"Error , alread recording.");
        }
    }
    else {
        NSLog(@"Error , playing can't record.");
    }
}

- (IBAction)pressPlay:(id)sender {
    if (!self.recordState.mIsRunning) {
        if (!self.playState.mIsRunning) {
            [self startPlayback];
        }
        else {
            NSLog(@"Error , alread playing.");
        }
    }
    else {
        NSLog(@"Error , recording can't play.");
    }
}

- (IBAction)pressStop:(id)sender {
    if (self.recordState.mIsRunning) {
        [self stopRecording];
    }
    else if (self.playState.mIsRunning) {
        [self stopPlayback];
    }
    self.labelState.text = @"Idle";

}
@end
