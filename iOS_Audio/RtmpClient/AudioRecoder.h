//
//  AudioRecoder.h
//  SayHey
//
//  Created by Mingliang Chen on 13-11-29.
//  Copyright (c) 2013 Mingliang Chen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kNumberRecordBuffers	3
// if not define then AAC
//#define SPEEX
@protocol AudioRecordDelegate

-(void)AudioDataOutputBuffer:(char*)audioBuffer bufferSize:(int)size;

@end

@interface AudioRecoder : NSObject
{
    
    AudioQueueRef                   mQueue;
    AudioQueueBufferRef             mBuffers[kNumberRecordBuffers];
    AudioStreamBasicDescription     mRecordFormat;
    AudioConverterRef               mAudioConverter;
    
}

@property (nonatomic, weak)id<AudioRecordDelegate> outDelegate;

-(id)initWIthSampleRate:(int)sampleRate;
-(void)setAudioRecordDelegate:(id<AudioRecordDelegate>)delegate;
-(void)startRecord;
-(void)stopRecord;
@end
