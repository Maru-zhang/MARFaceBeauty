//
//  MARFaceBeautyController.m
//  MARFaceBeauty
//
//  Created by Maru on 2016/11/12.
//  Copyright © 2016年 Maru. All rights reserved.
//

#import "MARFaceBeautyController.h"
#import "LFGPUImageBeautyFilter.h"
#import <GPUImage.h>

#define kMARGap 20.0
#define kMARSwitchW 30
#define kLimitRecLen 15.0f
#define kCameraWidth 540.0f
#define kCameraHeight 960.0f

#define kWeakSelf __weak typeof(self) weakSelf = self;

#define RMDefaultVideoPath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Movie.mov"]

@interface MARFaceBeautyController () <CAAnimationDelegate> {
    CGFloat _allTime;
    UIImage *_tempImg;
    AVPlayerLayer *_avplayer;
}

@property (nonatomic, strong) UISlider *sliderView;
@property (nonatomic, strong) UIButton *flashSwitch;
@property (nonatomic, strong) UIButton *filterSwitch;
@property (nonatomic, strong) UIButton *cameraSwitch;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *downButton;
@property (nonatomic, strong) UIButton *recaptureButton;
@property (nonatomic, strong) GPUImageView *cameraView;
@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) CALayer *focusLayer;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) NSString *moviePath;
@property (nonatomic, strong) NSDictionary *audioSettings;
@property (nonatomic, strong) NSMutableDictionary *videoSettings;

@property (nonatomic, strong) GPUImageStillCamera *videoCamera;
@property (nonatomic, strong) GPUImageFilterGroup *normalFilter;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic, strong) LFGPUImageBeautyFilter *leveBeautyFilter;


@end

@implementation MARFaceBeautyController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    
    [self setupNotification];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private Method

- (void)setupUI {
    
    self.view.backgroundColor = [UIColor grayColor];
    
    self.cameraView = ({
        GPUImageView *g = [[GPUImageView alloc] init];
        [g.layer addSublayer:self.focusLayer];
        [g addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusTap:)]];
        [g setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [self.view addSubview:g];
        g;
    });
    
    self.imageView = ({
        UIImageView *i = [[UIImageView alloc] init];
        i.hidden = YES;
        [self.view addSubview:i];
        i;
    });
    
    self.flashSwitch = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setBackgroundImage:[UIImage imageNamed:@"record_light_off"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"record_light_on"] forState:UIControlStateSelected];
        [b addTarget:self action:@selector(flashAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        b;
    });
    
    self.filterSwitch = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setBackgroundImage:[UIImage imageNamed:@"record_beauty_disable"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"record_beauty_enable"] forState:UIControlStateSelected];
        [b addTarget:self action:@selector(filterAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        b;
    });
    
    self.cameraSwitch = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setBackgroundImage:[UIImage imageNamed:@"record_changecamera_nomal"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"record_changecamera_selected"] forState:UIControlStateSelected];
        [b addTarget:self action:@selector(turnAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        b;
    });
    
    self.recordButton = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setBackgroundImage:[UIImage imageNamed:@"record_shutter_untouch"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"record_shutter_touching"] forState:UIControlStateHighlighted];
        [b addTarget:self action:@selector(beginRecord) forControlEvents:UIControlEventTouchDown];
        [b addTarget:self action:@selector(endRecord) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.view addSubview:b];
        b;
    });
    
    self.downButton = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.alpha = 0.0;
        [b addTarget:self action:@selector(saveAction) forControlEvents:UIControlEventTouchUpInside];
        [b setBackgroundImage:[UIImage imageNamed:@"ic_down_button_55x55_"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"ic_down_button_press_55x55_"] forState:UIControlStateHighlighted];
        [self.view addSubview:b];
        b;
    });
    
    self.recaptureButton = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.alpha = 0.0;
        [b setBackgroundImage:[UIImage imageNamed:@"camera_btn_return_normal_55x55_"] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(recaptureAction) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        b;
    });
    
    self.sliderView = ({
        UISlider *s = [[UISlider alloc] init];
        [s setThumbImage:[UIImage new] forState:UIControlStateNormal];
        s;
    });
    
    [self.flashSwitch setHidden:YES];
    self.filterSwitch.selected = YES;
    
    [self.videoCamera addTarget:self.leveBeautyFilter];
    [self.leveBeautyFilter addTarget:self.cameraView];
    
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
    self.videoCamera.audioEncodingTarget = _movieWriter;
    
    [self.videoCamera startCameraCapture];

}

- (void)setupNotification {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.cameraView.frame = self.view.bounds;
    self.imageView.frame = self.view.bounds;
    self.cameraSwitch.frame = CGRectMake(self.view.frame.size.width - kMARSwitchW - kMARGap, 30, kMARSwitchW, kMARSwitchW);
    self.filterSwitch.frame = CGRectMake(CGRectGetMinX(self.cameraSwitch.frame) - kMARSwitchW - kMARGap, 30, kMARSwitchW, kMARSwitchW);
    self.flashSwitch.frame = CGRectMake(CGRectGetMinX(self.filterSwitch.frame) - kMARSwitchW - kMARGap, 30, kMARSwitchW, kMARSwitchW);
    self.recordButton.bounds = CGRectMake(0, 0, 70, 70);
    self.recordButton.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 50);
    self.downButton.center = self.recordButton.center;
    self.downButton.bounds = CGRectMake(0, 0, 55, 55);
    self.recaptureButton.center = CGPointMake(60, self.downButton.center.y);
    self.recaptureButton.bounds = CGRectMake(0, 0, 55, 55);
}

#pragma mark - Logic Method

- (void)beginRecord {
    
    unlink([self.moviePath UTF8String]);
    
    [self hideAllFunctionButton];
    
    [(self.filterSwitch.selected ? self.leveBeautyFilter : self.normalFilter) addTarget:self.movieWriter];
    
    [self.movieWriter startRecording];
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(timerupdating) userInfo:nil repeats:YES];
    _allTime = 0;
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    [_timer fire];
}


- (void)endRecord {
    
    [_timer invalidate];
    _timer = nil;
    
    [self showAllFunctionButton];
    
    [(self.filterSwitch.selected ? self.leveBeautyFilter : self.normalFilter) removeTarget:self.movieWriter];
    
    if (_allTime < 0.5) {
        // 储存到图片库,并且设置回调.
        [self.movieWriter finishRecording];
        
        kWeakSelf
        [self.videoCamera capturePhotoAsImageProcessedUpToFilter:(self.filterSwitch.selected ? self.leveBeautyFilter : self.normalFilter) withCompletionHandler:^(UIImage *processedImage, NSError *error) {
            _tempImg = processedImage;
            [self createNewWritter];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.imageView setImage:processedImage];
                weakSelf.imageView.hidden = NO;
                [UIView animateWithDuration:0.5 animations:^{
                    weakSelf.downButton.alpha = 1.0;
                    weakSelf.recordButton.alpha = 0;
                    weakSelf.recaptureButton.alpha = 1.0;
                }];
            });
        }];
        
    }else {
        // 储存到图片库,并且设置回调.
        kWeakSelf
        [self.movieWriter finishRecordingWithCompletionHandler:^{
            [self createNewWritter];
            dispatch_async(dispatch_get_main_queue(), ^{
                _avplayer = [AVPlayerLayer playerLayerWithPlayer:[AVPlayer playerWithURL:[NSURL fileURLWithPath:RMDefaultVideoPath]]];
                _avplayer.frame = weakSelf.view.bounds;
                [self.view.layer insertSublayer:_avplayer atIndex:2];
                [_avplayer.player play];
                [UIView animateWithDuration:0.5 animations:^{
                    weakSelf.downButton.alpha = 1.0;
                    weakSelf.recordButton.alpha = 0;
                    weakSelf.recaptureButton.alpha = 1.0;
                }];
            });
        }];
    }

}

- (void)timerupdating {
    _allTime += 0.05;
}

- (void)createNewWritter {
    
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
    /// 如果不加上这一句，会出现第一帧闪现黑屏
    [_videoCamera addAudioInputsAndOutputs];
    _videoCamera.audioEncodingTarget = _movieWriter;
}


- (void)hideAllFunctionButton {
    
    [UIView animateWithDuration:0.5 animations:^{
        self.filterSwitch.alpha = 0;
        self.cameraSwitch.alpha = 0;
        self.flashSwitch.alpha = 0;
    }];
}

- (void)showAllFunctionButton {
    
    [UIView animateWithDuration:0.5 animations:^{
        self.filterSwitch.alpha = 1.0;
        self.cameraSwitch.alpha = 1.0;
        self.flashSwitch.alpha = 1.0;
    }];
}

#pragma mark - AnimationDelegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    [self performSelector:@selector(focusLayerNormal) withObject:self afterDelay:1.0f];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    if (_avplayer) {
        [_avplayer.player pause];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (_avplayer) {
        [_avplayer.player play];
    }
}

#pragma mark - User Action

- (void)saveAction {
    if (_tempImg) {
        UIImageWriteToSavedPhotosAlbum(_tempImg, self, nil, nil);
    }else {
        UISaveVideoAtPathToSavedPhotosAlbum(RMDefaultVideoPath, self, nil, nil);
    }
    [self recaptureAction];
}

- (void)recaptureAction {
    
    [_avplayer.player pause];
    [_avplayer removeFromSuperlayer];
    _avplayer = nil;
    _tempImg = nil;
    self.imageView.hidden = YES;
    [UIView animateWithDuration:0.5 animations:^{
        self.recordButton.alpha = 1.0;
        self.downButton.alpha = 0.0;
        self.recaptureButton.alpha = 0.0;
    }];
}

- (void)turnAction:(id)sender {
    
    [self.videoCamera pauseCameraCapture];
    
    if (self.videoCamera.cameraPosition == AVCaptureDevicePositionBack) {
        self.flashSwitch.hidden = YES;
    }else {
        self.flashSwitch.hidden = NO;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.videoCamera rotateCamera];
        [self.videoCamera resumeCameraCapture];
    });
    
    [self performSelector:@selector(animationCamera) withObject:self afterDelay:0.2f];
    
}

- (void)flashAction:(id)sender {
    
    if (self.flashSwitch.selected) {
        self.flashSwitch.selected = NO;
        if ([self.videoCamera.inputCamera lockForConfiguration:nil]) {
            [self.videoCamera.inputCamera setTorchMode:AVCaptureTorchModeOff];
            [self.videoCamera.inputCamera setFlashMode:AVCaptureFlashModeOff];
            [self.videoCamera.inputCamera unlockForConfiguration];
        }
    }else {
        self.flashSwitch.selected = YES;
        if ([self.videoCamera.inputCamera lockForConfiguration:nil]) {
            [self.videoCamera.inputCamera setTorchMode:AVCaptureTorchModeOn];
            [self.videoCamera.inputCamera setFlashMode:AVCaptureFlashModeOn];
            [self.videoCamera.inputCamera unlockForConfiguration];
            
        }
    }
}

- (void)filterAction:(id)sender {
    
    if (self.filterSwitch.selected) {
        self.filterSwitch.selected = NO;
        [self.videoCamera removeAllTargets];
        [self.videoCamera addTarget:self.normalFilter];
        [self.normalFilter addTarget:self.cameraView];
    }else {
        self.filterSwitch.selected = YES;
        [self.videoCamera removeAllTargets];
        [self.videoCamera addTarget:self.leveBeautyFilter];
        [self.leveBeautyFilter addTarget:self.cameraView];
    }
}

- (void)focusTap:(UITapGestureRecognizer *)tap {
    
    self.cameraView.userInteractionEnabled = NO;
    CGPoint touchPoint = [tap locationInView:tap.view];
    [self layerAnimationWithPoint:touchPoint];
    touchPoint = CGPointMake(touchPoint.x / tap.view.bounds.size.width, touchPoint.y / tap.view.bounds.size.height);
    
    if ([self.videoCamera.inputCamera isFocusPointOfInterestSupported] && [self.videoCamera.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([self.videoCamera.inputCamera lockForConfiguration:&error]) {
            [self.videoCamera.inputCamera setFocusPointOfInterest:touchPoint];
            [self.videoCamera.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
            
            if([self.videoCamera.inputCamera isExposurePointOfInterestSupported] && [self.videoCamera.inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            {
                [self.videoCamera.inputCamera setExposurePointOfInterest:touchPoint];
                [self.videoCamera.inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            
            [self.videoCamera.inputCamera unlockForConfiguration];
            
        } else {
            NSLog(@"ERROR = %@", error);
        }
    }
}

#pragma mark - Notification Action 

- (void)moviePlayDidEnd:(NSNotification *)notification {
    [_avplayer.player seekToTime:kCMTimeZero];
    [_avplayer.player play];
}

#pragma mark - Animation

- (void)animationCamera {
    
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = .5f;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = @"oglFlip";
    animation.subtype = kCATransitionFromRight;
    [self.cameraView.layer addAnimation:animation forKey:nil];
    
}

- (void)focusLayerNormal {
    self.cameraView.userInteractionEnabled = YES;
    _focusLayer.hidden = YES;
}

- (void)layerAnimationWithPoint:(CGPoint)point {
    if (_focusLayer) {
        CALayer *focusLayer = _focusLayer;
        focusLayer.hidden = NO;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [focusLayer setPosition:point];
        focusLayer.transform = CATransform3DMakeScale(2.0f,2.0f,1.0f);
        [CATransaction commit];
        
        CABasicAnimation *animation = [ CABasicAnimation animationWithKeyPath: @"transform" ];
        animation.toValue = [ NSValue valueWithCATransform3D: CATransform3DMakeScale(1.0f,1.0f,1.0f)];
        animation.delegate = self;
        animation.duration = 0.3f;
        animation.repeatCount = 1;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [focusLayer addAnimation: animation forKey:@"animation"];
    }
}

#pragma mark - Property

- (GPUImageStillCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    }
    return _videoCamera;
}

- (GPUImageFilterGroup *)normalFilter {
    if (!_normalFilter) {
        GPUImageFilter *filter = [[GPUImageFilter alloc] init]; //默认
        _normalFilter = [[GPUImageFilterGroup alloc] init];
        [(GPUImageFilterGroup *) _normalFilter setInitialFilters:[NSArray arrayWithObject: filter]];
        [(GPUImageFilterGroup *) _normalFilter setTerminalFilter:filter];
    }
    return _normalFilter;
}

- (CALayer *)focusLayer {
    if (!_focusLayer) {
        UIImage *focusImage = [UIImage imageNamed:@"touch_focus_x"];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, focusImage.size.width, focusImage.size.height)];
        imageView.image = focusImage;
        _focusLayer = imageView.layer;
        _focusLayer.hidden = YES;
    }
    return _focusLayer;
}

- (NSString *)moviePath {
    if (!_moviePath) {
        _moviePath = RMDefaultVideoPath;
        NSLog(@"maru: %@",_moviePath);
    }
    return _moviePath;
}

- (NSDictionary *)audioSettings {
    if (!_audioSettings) {
        // 音频设置
        AudioChannelLayout channelLayout;
        memset(&channelLayout, 0, sizeof(AudioChannelLayout));
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        _audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                          [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                          [ NSNumber numberWithInt: 2 ], AVNumberOfChannelsKey,
                          [ NSNumber numberWithFloat: 16000.0 ], AVSampleRateKey,
                          [ NSData dataWithBytes:&channelLayout length: sizeof( AudioChannelLayout ) ], AVChannelLayoutKey,
                          [ NSNumber numberWithInt: 32000 ], AVEncoderBitRateKey,
                          nil];
    }
    return _audioSettings;
}

- (NSMutableDictionary *)videoSettings {
    if (!_videoSettings) {
        _videoSettings = [[NSMutableDictionary alloc] init];
        [_videoSettings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:kCameraWidth] forKey:AVVideoWidthKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:kCameraHeight] forKey:AVVideoHeightKey];
    }
    return _videoSettings;
}

- (LFGPUImageBeautyFilter *)leveBeautyFilter {
    if (!_leveBeautyFilter) {
        _leveBeautyFilter = [[LFGPUImageBeautyFilter alloc] init];
    }
    return _leveBeautyFilter;
}

@end
