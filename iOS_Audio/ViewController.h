//
//  ViewController.h
//  iOS_Audio
//
//  Created by JimmyJeng on 2016/3/31.
//  Copyright © 2016年 JimmyJeng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>

static const int kNumberBuffers = 3;

typedef struct {
    AudioStreamBasicDescription  mDataFormat;
    AudioQueueRef                mQueue;
    AudioQueueBufferRef          mBuffers[kNumberBuffers];
    AudioFileID                  mAudioFile;
    UInt32                       bufferByteSize;
    SInt64                       mCurrentPacket;
    bool                         mIsRunning;
}AQRecorderState;

typedef struct {
    AudioStreamBasicDescription   mDataFormat;
    AudioQueueRef                 mQueue;
    AudioQueueBufferRef           mBuffers[kNumberBuffers];
    AudioFileID                   mAudioFile;
    UInt32                        bufferByteSize;
    SInt64                        mCurrentPacket;
    UInt32                        mNumPacketsToRead;
    AudioStreamPacketDescription  *mPacketDescs;
    bool                          mIsRunning;                     
}AQPlayerState;

static void HandleInputBuffer (void                                *aqData,
                               AudioQueueRef                       inAQ,
                               AudioQueueBufferRef                 inBuffer,
                               const AudioTimeStamp                *inStartTime,
                               UInt32                              inNumPackets,
                               const AudioStreamPacketDescription  *inPacketDesc);

static void HandleOutputBuffer (void                 *aqData,
                                AudioQueueRef        inAQ,
                                AudioQueueBufferRef  inBuffer);


@interface ViewController : UIViewController


@end

