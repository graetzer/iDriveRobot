//
//  SGSource.m
//  iDriveRobot
//
//  Created by Simon Grätzer on 29.09.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGVideoSource.h"
#import "DDLog.h"

#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
#include <libavutil/audioconvert.h>
#include <libavutil/common.h>
#include <libavutil/imgutils.h>
#include <libavutil/mathematics.h>
#include <libavutil/samplefmt.h>
#include <libswscale/swscale.h>
#include <libavformat/avformat.h>




@implementation SGVideoSource  {
    NSMutableArray *_delegates;
    CMVideoDimensions _videoSize;
        
    AVOutputFormat *fmt;
    AVFormatContext *oc;
    AVStream *video_st;
    AVCodec *video_codec;
    AVFrame *frame;
    int got_packet;
    
    BOOL _recording;
    NSUInteger frameCount;
    
    time_t start;
}

+ (SGVideoSource *)shared {
    static id shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init {
    if (self = [super init]) {
        _delegates = [NSMutableArray arrayWithCapacity:5];
        [self initCapture];
    }
    
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)initCapture {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        DDLogError(@"Not running on a device with video camera!");
        exit(1);
    }
    
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput
                                          deviceInputWithDevice:device
                                          error:nil];
    /*We setupt the output*/
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    /*While a frame is processes in -captureOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
     If you don't want this behaviour set the property to NO */
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    /*We create a serial queue to handle the processing of our frames*/
    dispatch_queue_t queue = dispatch_queue_create("cameraQueue", DISPATCH_QUEUE_SERIAL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    
    // Set the video output to store frame in BGRA (It is supposed to be faster)
    NSDictionary* videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    [captureOutput setVideoSettings:videoSettings];
    
    /*And we create a capture session*/
    _captureSession = [[AVCaptureSession alloc] init];
    /*We add input and output*/
    [self.captureSession addInput:captureInput];
    [self.captureSession addOutput:captureOutput];
    [self.captureSession setSessionPreset:AVCaptureSessionPresetMedium];
    
    AVCaptureConnection *conn = [captureOutput connectionWithMediaType:AVMediaTypeVideo];    
    if (conn.isVideoMinFrameDurationSupported) conn.videoMinFrameDuration = CMTimeMake(1, 5);
    if (conn.isVideoMaxFrameDurationSupported) conn.videoMaxFrameDuration = CMTimeMake(1, 5);
    
    
    _videoSize.height = 0;
    for (AVCaptureInputPort *port in captureInput.ports) {
        if ([port mediaType] == AVMediaTypeVideo) {
            _videoSize = CMVideoFormatDescriptionGetDimensions([port formatDescription]);
            break;
        }
    }
    if (_videoSize.height == 0) {
        _videoSize.width = 480;
        _videoSize.height = 360;
    }
}

- (void)addDelegate:(id<SGVideoSourceDelegate>)delegate {
    [_delegates addObject:delegate];
    
    if (_delegates.count == 1)
        [self start];
}

- (void)removeDelegate:(id)delegate {
    [_delegates removeObject:delegate];
    
    if (_delegates.count == 0)
        [self stop];
}

- (void)start {
    if (!self.captureSession.running) {
        _recording = YES;
        [self setupEncoder];
        [self.captureSession startRunning];
        start = time(NULL);
    }
}

- (void)stop {
    if (self.captureSession.running) {
        _recording = NO;
        [self.captureSession stopRunning];
        float frames = (float)frameCount/(float)(time(NULL)-start);
        NSLog(@"Fps: %f", frames);
        [self finishEncoding];
    }
}

#pragma mark - AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    @autoreleasepool {
        if (!CMSampleBufferDataIsReady(sampleBuffer) || !_recording) {
            NSLog(@"Skip frame %d", frameCount);
            return;
        }
        
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        [self encodeImageBuffer:imageBuffer];
    }
}

#pragma mark Encoding

+ (void)initialize {
    av_register_all();
    //avcodec_register_all();
}

- (void)setupEncoder {
    int ret;
    const char *filename;
    
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [searchPaths lastObject];
    filename = [path stringByAppendingPathComponent:@"camera.mp4"].UTF8String;//argv[1];
    
    /* allocate the output media context */
    //avformat_alloc_output_context2(&oc, NULL, NULL, filename);
    //if (!oc) {
        //printf("Could not deduce output format from file extension: using MPEG.\n");
        avformat_alloc_output_context2(&oc, NULL, "mp4", NULL);
        //}
    if (!oc) {
        exit(1);
    }
    fmt = oc->oformat;
    
    /* Add the audio and video streams using the default format codecs
     * and initialize the codecs. */
    
    /* find the encoder */
    video_codec = avcodec_find_encoder(fmt->video_codec);
    if (!video_codec) {
        fprintf(stderr, "Could not find encoder for '%s'\n", avcodec_get_name(video_codec));
        exit(1);
    }
    
    video_st = avformat_new_stream(oc, video_codec);
    if (!video_st) {
        fprintf(stderr, "Could not allocate stream\n");
        exit(1);
    }
    video_st->id = oc->nb_streams-1;
    AVCodecContext *c = video_st->codec;
    
    c->codec_id = fmt->video_codec;
    
    c->bit_rate = 400000;
    /* Resolution must be a multiple of two. */
    c->width    = _videoSize.width;
    c->height   = _videoSize.height;
    /* timebase: This is the fundamental unit of time (in seconds) in terms
     * of which frame timestamps are represented. For fixed-fps content,
     * timebase should be 1/framerate and timestamp increments should be
     * identical to 1. */
    c->time_base.den = 5;
    c->time_base.num = 1;
    c->gop_size      = 12; /* emit one intra frame every twelve frames at most */
    c->pix_fmt       = AV_PIX_FMT_YUV420P;
    c->profile       = FF_PROFILE_H264_BASELINE;
    if (c->codec_id == AV_CODEC_ID_MPEG2VIDEO) {
        /* just for testing, we also add B frames */
        c->max_b_frames = 2;
    } else if (c->codec_id == AV_CODEC_ID_MPEG1VIDEO) {
        /* Needed to avoid using macroblocks in which some coeffs overflow.
         * This does not happen with normal video, it just happens here as
         * the motion of the chroma plane does not match the luma plane. */
        c->mb_decision = 2;
    } else if(c->codec_id == AV_CODEC_ID_H264) {
        av_opt_set(c->priv_data, "preset", "slow", 0);
    }
    
    /* Some formats want stream headers to be separate. */
    if (oc->oformat->flags & AVFMT_GLOBALHEADER)
        c->flags |= CODEC_FLAG_GLOBAL_HEADER;
    
    
    /* Now that all the parameters are set, we can open the audio and
     * video codecs and allocate the necessary encode buffers. */
    /* open the codec */
    ret = avcodec_open2(c, video_codec, NULL);
    if (ret < 0) {
        fprintf(stderr, "Could not open video codec: %s\n", av_err2str(ret));
        exit(1);
    }
    
    /* allocate and init a re-usable frame */
    frame = avcodec_alloc_frame();
    if (!frame) {
        fprintf(stderr, "Could not allocate video frame\n");
        exit(1);
    }
    frame->format = c->pix_fmt;
    frame->width = _videoSize.width;
    frame->height = _videoSize.height;
    ret = av_image_alloc(frame->data, frame->linesize, _videoSize.width, _videoSize.height,
                         c->pix_fmt, 32);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate raw picture buffer\n");
        exit(1);
    }

    av_dump_format(oc, 0, filename, 1);
    
    /* open the output file, if needed */
    ret = avio_open(&oc->pb, filename, AVIO_FLAG_WRITE);
    if (ret < 0) {
        fprintf(stderr, "Could not open '%s': %s\n", filename,
                av_err2str(ret));
        exit(1);
    }
    
    /* Write the stream header, if any. */
    ret = avformat_write_header(oc, NULL);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file: %s\n",
                av_err2str(ret));
        exit(1);
    }
    
    frame->pts = 0;
//    for (;;) {
//        /* Compute current audio and video time. */
//        //video_time = video_st ? video_st->pts.val * av_q2d(video_st->time_base) : 0.0;
//        write_video_frame(oc, video_st);
//        frame->pts += av_rescale_q(1, video_st->codec->time_base, video_st->time_base);
//    }
}

- (void)finishEncoding {
    AVPacket pkt = { 0 };
    av_init_packet(&pkt);
    /* get the delayed frames */
    got_packet = 1;
    while (got_packet) {
        int ret = avcodec_encode_video2(video_st->codec, &pkt, NULL, &got_packet);
        if (ret < 0) {
            fprintf(stderr, "Error encoding frame\n");
            exit(1);
        }
        
        if (got_packet) {
            ret = av_interleaved_write_frame(oc, &pkt);
            av_free_packet(&pkt);
        }
        frameCount++;
    }
    
    /* Write the trailer, if any. The trailer must be written before you
     * close the CodecContexts open when you wrote the header; otherwise
     * av_write_trailer() may try to use memory that was freed on
     * av_codec_close(). */
    av_write_trailer(oc);
    
    /* Close each codec. */
    avcodec_close(video_st->codec);
    av_freep(frame->data);
    av_free(frame);
    
    avio_close(oc->pb);
    
    /* free the stream */
    avformat_free_context(oc);
}

- (void)encodeImageBuffer:(CVImageBufferRef)pixelBuffer {
    if (CVPixelBufferLockBaseAddress( pixelBuffer, 0 ) != kCVReturnSuccess) return;
    
    int bufferWidth = 0;
    int bufferHeight = 0;
    uint8_t *base;
    
    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        //int planeCount = CVPixelBufferGetPlaneCount(pixelBuffer);
        int basePlane = 0;
        base = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, basePlane);
        bufferHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, basePlane);
        bufferWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, basePlane);
        
    } else {
        base = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
        bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
        bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    }
    
    //unsigned char y_pixel = pixel[0];
    
    /* Yr */
    for (int y = 0; y < bufferHeight; y++) {
        for (int x = 0; x < bufferWidth; x++) {
            frame->data[0][y * frame->linesize[0] + x] = base[0];
            base++;
        }
    }

    /* Cb and Cr */
    
    for (int y = 0; y < bufferHeight / 2; y++) {
        for (int x = 0; x < bufferWidth / 2; x++) {
            frame->data[1][y * frame->linesize[1] + x] = base[0];
            frame->data[2][y * frame->linesize[2] + x] = base[1];
            base+=2;
        }
    }
    
    AVPacket pkt = { 0 };
    av_init_packet(&pkt);
    
    /* encode the image */
    int ret = avcodec_encode_video2(video_st->codec, &pkt, frame, &got_packet);
    if (ret < 0) {
        fprintf(stderr, "Error encoding frame\n");
        exit(1);
    }
    
    if (!ret && got_packet && pkt.size) {
        pkt.stream_index = video_st->index;
        
        /* Write the compressed frame to the media file. */
        ret = av_interleaved_write_frame(oc, &pkt);
        if (ret != 0) {
            fprintf(stderr, "Error while writing video frame: %s\n", av_err2str(ret));
            exit(1);
        }
        frameCount++;
    }
    frame->pts += av_rescale_q(1, video_st->codec->time_base, video_st->time_base);
    
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}

@end
