//
//  RtmpClient.m
//  SayHey
//
//  Created by Mingliang Chen on 13-12-11.
//  Copyright (c) 2013 Mingliang Chen. All rights reserved.
//

#import "RtmpClient.h"


@implementation RtmpClient


void send_pkt(RTMP* pRtmp,char* buf, int buflen, int type, unsigned int timestamp)
{
    int ret;
    RTMPPacket rtmp_pakt;
    RTMPPacket_Reset(&rtmp_pakt);
    RTMPPacket_Alloc(&rtmp_pakt, buflen);
    rtmp_pakt.m_packetType = type;
    rtmp_pakt.m_nBodySize = buflen;
    rtmp_pakt.m_nTimeStamp = timestamp;
    rtmp_pakt.m_nChannel = 4;
    rtmp_pakt.m_headerType = RTMP_PACKET_SIZE_LARGE;
    rtmp_pakt.m_nInfoField2 = pRtmp->m_stream_id;
    memcpy(rtmp_pakt.m_body, buf, buflen);
    ret = RTMP_SendPacket(pRtmp, &rtmp_pakt, 0);
    RTMPPacket_Free(&rtmp_pakt);
}

- (void)audioSessionRouteChange:(NSNotification *)notification {
    NSInteger routeChangeReason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue];
    NSString *log = nil;
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonCategoryChange:
            log = @"AVAudioSessionRouteChangeReasonCategoryChange";
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            log = @"AVAudioSessionRouteChangeReasonNewDeviceAvailable";
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            log = @"AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory";
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            log = @"AVAudioSessionRouteChangeReasonOldDeviceUnavailable";
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            log = @"AVAudioSessionRouteChangeReasonOverride";
            break;
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
            log = @"AVAudioSessionRouteChangeReasonRouteConfigurationChange";
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
            log = @"AVAudioSessionRouteChangeReasonUnknown";
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            log = @"AVAudioSessionRouteChangeReasonWakeFromSleep";
            break;
    }
    NSLog(@"audioSessionRouteChange [%@]",log);
}

- (void)audioSessionInterruption:(NSNotification *)notification {
    NSLog(@"audioSessionInterruption");
}

-(id)initWithSampleRate:(int)sampleRate withEncoder:(int)audioEncoder
{
    self = [super init];
    if(self){
        mAudioRecord = [[AudioRecoder alloc] initWIthSampleRate:sampleRate];
        [mAudioRecord setAudioRecordDelegate:self];
        mAudioPlayer = [[AudioPlayer alloc] initWithSampleRate:sampleRate];
        condition = [[NSCondition alloc] init];

        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *sessionError;
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        if(session == nil)
        {
            NSLog(@"Error creating session: %@", [sessionError description]);
        }
        else
        {
            [session setActive:YES error:nil];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
    }
    return self;
}

-(void)setOutDelegate:(id<RtmpClientDelegate>)delegate
{
    outDelegate = delegate;
}

-(void)startPublishWithUrl:(NSString*) rtmpURL
{
    if(isStartPub) return;
    NSThread *thread = [[NSThread alloc]initWithTarget:self selector:@selector(openPublishThread:) object:rtmpURL];
    [thread start];
}

-(void)stopPublish
{
    [condition lock];
    [condition signal];
    [condition unlock];
}

-(void)startPlayWithUrl:(NSString*) rtmpURL
{
    if(isStartPlay) return;
    NSThread *thread = [[NSThread alloc]initWithTarget:self selector:@selector(openPlayThread:) object:rtmpURL];
    [thread start];
}

-(void)stopPlay
{
    isStartPlay = NO;
}

-(void)openPublishThread:(NSString*) rtmpUrl
{
    int quality = 6,sample_rate,vad=1;
    do {
        isStartPub = YES;
        if(outDelegate)
        {
            [outDelegate EventCallback:1000];
        }
        //1 init speex encoder
#ifdef SPEEX
        speex_bits_init(&ebits);
        enc_state = speex_encoder_init(&speex_wb_mode);
        speex_encoder_ctl(enc_state, SPEEX_SET_QUALITY, &quality);
        speex_encoder_ctl(enc_state, SPEEX_GET_FRAME_SIZE, &enc_frame_size);
        speex_encoder_ctl(enc_state, SPEEX_GET_SAMPLING_RATE, &sample_rate);
        speex_encoder_ctl(enc_state, SPEEX_SET_VAD,&vad);
        pcm_buffer = malloc(enc_frame_size * sizeof(short));
        output_buffer = malloc(enc_frame_size * sizeof(char));
        NSLog(@"Speex Encoder init,enc_frame_size:%d sample_rate:%d vad:%d\n", enc_frame_size, sample_rate,vad);
#endif
        //2 init rtmp
        pPubRtmp = RTMP_Alloc();
        RTMP_Init(pPubRtmp);
        if(!RTMP_SetupURL(pPubRtmp, (char*)[rtmpUrl UTF8String]))
        {
            NSLog(@"RTMP_SetupURL error");
            isStartPub = NO;
            if(outDelegate)
            {
                [outDelegate EventCallback:1002];
            }
            break; 
        }
        RTMP_EnableWrite(pPubRtmp);
        NSLog(@"RTMP_EnableWrite");
        if (!RTMP_Connect(pPubRtmp, NULL) || !RTMP_ConnectStream(pPubRtmp, 0)) {
            NSLog(@"RTMP_Connect or RTMP_ConnectStream error!");
            isStartPub = NO;
            if(outDelegate)
            {
                [outDelegate EventCallback:1002];
            }
            break;
        }
        NSLog(@"Publisher RTMP_Connected");
#ifndef SPEEX
        [self sendAACSpec];
#endif
        [mAudioRecord startRecord];
        if(outDelegate)
        {
            [outDelegate EventCallback:1001];
        }
        
    } while (0);
    [condition lock];
    [condition wait];
    [condition unlock];
    isStartPub = NO;
    NSLog(@"Stop Publish start release");
    [mAudioRecord stopRecord];
    if (RTMP_IsConnected(pPubRtmp)) {
        RTMP_Close(pPubRtmp);
    }
    RTMP_Free(pPubRtmp);
#ifdef SPEEX
    free(pcm_buffer);
    free(output_buffer);
    speex_bits_destroy(&ebits);
    speex_encoder_destroy(enc_state);
#endif
    if(outDelegate)
    {
        [outDelegate EventCallback:1004];
    }
}

//  FIXME
-(void)openPlayThread:(NSString*) rtmpUrl
{
    spx_int16_t *input_buffer;
    do {
        
        if(outDelegate)
        {
            [outDelegate EventCallback:2000];
        }
        //1. init speex decoder
#ifdef SPEEX
        speex_bits_init(&dbits);
        dec_state = speex_decoder_init(&speex_wb_mode);
        speex_decoder_ctl(dec_state, SPEEX_GET_FRAME_SIZE, &dec_frame_size);
        input_buffer = malloc(dec_frame_size * sizeof(short));
        NSLog(@"Init Speex decoder success frame_size = %d",dec_frame_size);
#endif
        
        //2. init rtmp
        pPlayRtmp = RTMP_Alloc();
        RTMP_Init(pPlayRtmp);
        NSLog(@"Play RTMP_Init %@\n", rtmpUrl);
        if (!RTMP_SetupURL(pPlayRtmp, (char*)[rtmpUrl UTF8String])) {
            NSLog(@"Play RTMP_SetupURL error\n");
            if(outDelegate)
            {
                [outDelegate EventCallback:2002];
            }
            break;
        }
        if (!RTMP_Connect(pPlayRtmp, NULL) || !RTMP_ConnectStream(pPlayRtmp, 0)) {
            NSLog(@"Play RTMP_Connect or RTMP_ConnectStream error\n");
            if(outDelegate)
            {
                [outDelegate EventCallback:2002];
            }
            break;
        }
        if(outDelegate)
        {
            [outDelegate EventCallback:2001];
        }
        NSLog(@"Player RTMP_Connected \n");
        
        //3. init AudioPlayer
        
        [mAudioPlayer startPlayWithBufferByteSize:dec_frame_size*2];
        RTMPPacket rtmp_pakt = { 0 };
        isStartPlay = YES;
        while (isStartPlay && RTMP_ReadPacket(pPlayRtmp, &rtmp_pakt)) {
            if (RTMPPacket_IsReady(&rtmp_pakt)) {
                if (!rtmp_pakt.m_nBodySize)
                    continue;
                if (rtmp_pakt.m_packetType == RTMP_PACKET_TYPE_AUDIO) {
                    // process audio packet
                   // NSLog(@"AUDIO audio size:%d  head:%d  time:%d\n", rtmp_pakt.m_nBodySize, rtmp_pakt.m_body[0], rtmp_pakt.m_nTimeStamp);
                    speex_bits_read_from(&dbits, rtmp_pakt.m_body + 1, rtmp_pakt.m_nBodySize - 1);
                    speex_decode_int(dec_state, &dbits, input_buffer);
               //     putAudioQueue(output_buffer,dec_frame_size);
                    [mAudioPlayer putAudioData:input_buffer];
                } else if (rtmp_pakt.m_packetType == RTMP_PACKET_TYPE_VIDEO) {
                    // process video packet
                } else if (rtmp_pakt.m_packetType == RTMP_PACKET_TYPE_INVOKE) {
                    // process invoke packet
                    NSLog(@"RTMP_PACKET_TYPE_INVOKE");
                    RTMP_ClientPacket(pPlayRtmp,&rtmp_pakt);
                } else if (rtmp_pakt.m_packetType == RTMP_PACKET_TYPE_INFO) {
                    // process info packet
                    //NSLog(@"RTMP_PACKET_TYPE_INFO");
                } else if (rtmp_pakt.m_packetType == RTMP_PACKET_TYPE_FLASH_VIDEO) {
                    // process other packet
                    int index = 0;
                    while (1) {
                        int StreamType; //1-byte
                        int MediaSize; //3-byte
                        int TiMMER; //3-byte
                        int Reserve; //4-byte
                        char* MediaData; //MediaSize-byte
                        int TagLen; //4-byte
                        
                        StreamType = rtmp_pakt.m_body[index];
                        index += 1;
                        MediaSize = AMF_DecodeInt24(rtmp_pakt.m_body + index);
                        index += 3;
                        TiMMER = AMF_DecodeInt24(rtmp_pakt.m_body + index);
                        index += 3;
                        Reserve = AMF_DecodeInt32(rtmp_pakt.m_body + index);
                        index += 4;
                        MediaData = rtmp_pakt.m_body + index;
                        index += MediaSize;
                        TagLen = AMF_DecodeInt32(rtmp_pakt.m_body + index);
                        index += 4;
                        //NSLog(@"bodySize:%d   index:%d",rtmp_pakt.m_nBodySize,index);
                        //LOGI("StreamType:%d MediaSize:%d  TiMMER:%d TagLen:%d\n", StreamType, MediaSize, TiMMER, TagLen);
                        if (StreamType == 0x08) {
                            // audio packet
                            //int MediaSize = bigThreeByteToInt(rtmp_pakt.m_body+1);
                            //  LOGI("FLASH audio size:%d  head:%d time:%d\n", MediaSize, MediaData[0], TiMMER);
                            speex_bits_read_from(&dbits, MediaData + 1, MediaSize - 1);
                            speex_decode_int(dec_state, &dbits, input_buffer);
                            [mAudioPlayer putAudioData:input_buffer];
                          //  putAudioQueue(output_buffer,dec_frame_size);
                        } else if (StreamType == 0x09) {
                            // video packet
                            //  LOGI( "video size:%d  head:%d\n", MediaSize, MediaData[0]);
                        }
                        if (rtmp_pakt.m_nBodySize == index) {
                            //     LOGI("one pakt over\n");
                            break;
                        }
                    }
                }
                //  LOGI( "rtmp_pakt size:%d  type:%d\n", rtmp_pakt.m_nBodySize, rtmp_pakt.m_packetType);
                RTMPPacket_Free(&rtmp_pakt);
            }
        }
        if (isStartPlay) {
            if(outDelegate)
            {
                [outDelegate EventCallback:2005];
            }
            isStartPlay = NO;
        }
    } while (0);
    [mAudioPlayer stopPlay];
    if(outDelegate)
    {
        [outDelegate EventCallback:2004];
    }
    if (RTMP_IsConnected(pPlayRtmp)) {
        RTMP_Close(pPlayRtmp);
    }
    RTMP_Free(pPlayRtmp);
#ifdef SPEEX
    free(input_buffer);
    speex_bits_destroy(&dbits);
    speex_decoder_destroy(dec_state);
#endif
}

- (void)sendAACSpec {
    /*
     AudioTagHeader
     [UB4]:10,soundformat:aac
     [UB2]:3,sample reate,44k
     [UB1]:1,bitspersample,16bit
     [UB1]:1,channel,2
     => AF

     aac sequence header => 00
     aac raw data        => 01

     AAC sequence header
     [UB5]:2,aac-lc
     [UB4]:4,sample reate,44k
     [UB4]:2,channel
     [UB1]:1,0
     [UB1]:1,0
     [UB1]:1,0
     => 12 10
     */
    char *aac_head = malloc(4);
    aac_head[0] = '\xAF';
    aac_head[1] = '\x00';
    aac_head[2] = '\x12';
    aac_head[3] = '\x10';

    char *send_buf = malloc(4);
    memcpy(send_buf, aac_head, 4);
    send_pkt(pPubRtmp,send_buf, 4, RTMP_PACKET_TYPE_AUDIO, 0);
    free(send_buf);
}

-(void)AudioDataOutputBuffer:(char *)audioBuffer bufferSize:(int)size
{
    if (isStartPub) {
#ifdef SPEEX
        const char speex_head = '\xB6';
        speex_bits_reset(&ebits);
        memcpy(pcm_buffer, audioBuffer, enc_frame_size * sizeof(short));
        speex_encode_int(enc_state, pcm_buffer, &ebits);
        int enc_size = speex_bits_write(&ebits, output_buffer, enc_frame_size);
        //NSLog(@"AudioDataOutputBuffer size=%d  encSize=%d",size,enc_size);
        char* send_buf = malloc(enc_size + 1);
        memcpy(send_buf, &speex_head, 1);
        memcpy(send_buf + 1, output_buffer, enc_size);
        send_pkt(pPubRtmp,send_buf, enc_size + 1, RTMP_PACKET_TYPE_AUDIO, pubTs += 20);
        free(send_buf);
#else
        unsigned char *aac_head = malloc(2);
        aac_head[0] = '\xAF';
        aac_head[1] = '\x01';

        char* send_buf = malloc(size + 2);
        memcpy(send_buf, aac_head, 2);
        memcpy(send_buf + 2, audioBuffer, size);
        send_pkt(pPubRtmp,send_buf, size + 2, RTMP_PACKET_TYPE_AUDIO, pubTs += 20);
        free(send_buf);
#endif
    }
}
@end
