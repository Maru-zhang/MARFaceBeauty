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
#define kRecordW 87

#define kRecordCenter CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 50)

#define kFaceUColor [UIColor colorWithRed:66 / 255.0 green:222 / 255.0 blue:182 / 255.0 alpha:1]

#define kWeakSelf __weak typeof(self) weakSelf = self;

#define RMDefaultVideoPath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Movie.mov"]

@interface MARFaceBeautyController () <CAAnimationDelegate> {
    CGFloat _allTime;
    UIImage *_tempImg;
    AVPlayerLayer *_avplayer;
}
//******** UIKit Property *************
@property (nonatomic, strong) UISlider *sliderView;
@property (nonatomic, strong) UIButton *flashSwitch;
@property (nonatomic, strong) UIButton *filterSwitch;
@property (nonatomic, strong) UIButton *cameraSwitch;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *downButton;
@property (nonatomic, strong) UIButton *recaptureButton;
@property (nonatomic, strong) GPUImageView *cameraView;
@property (nonatomic, strong) UIImageView *imageView;

//******** Animation Property **********
@property (nonatomic, strong) CAShapeLayer *cycleLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) CAShapeLayer *ballLayer;
@property (nonatomic, strong) CALayer *focusLayer;
@property (nonatomic, strong) CADisplayLink *timer;

//******** Media Property **************
@property (nonatomic, copy) NSString *moviePath;
@property (nonatomic, strong) NSDictionary *audioSettings;
@property (nonatomic, strong) NSMutableDictionary *videoSettings;

//******** GPUImage Property ***********
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
        [b setBackgroundImage:[UIImage imageNamed:@"camera_btn_camera_normal_87x87_"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"camera_btn_camera_normal_87x87_"] forState:UIControlStateHighlighted];
        [b addTarget:self action:@selector(beginRecord) forControlEvents:UIControlEventTouchDown];
        [b addTarget:self action:@selector(endRecord) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.view addSubview:b];
        b;
    });
    
    self.downButton = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.alpha = 0.0;
        [b addTarget:self action:@selector(saveAction) forControlEvents:UIControlEventTouchUpInside];
        [b setBackgroundImage:[UIImage imageNamed:@"camera_btn_download_normal_55x55_"] forState:UIControlStateNormal];
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
    
    self.cycleLayer = ({
        CAShapeLayer *l = [CAShapeLayer layer];
        l.lineWidth = 5.0f;
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:kRecordCenter radius:kRecordW / 2 startAngle:0 endAngle:2 * M_PI clockwise:YES];
        l.path = path.CGPath;
        l.fillColor = nil;
        l.strokeColor = [UIColor whiteColor].CGColor;
        l;
    });
    
    self.progressLayer = ({
        CAShapeLayer *l = [CAShapeLayer layer];
        l.lineWidth = 5.0f;
        l.fillColor = nil;
        l.strokeColor = kFaceUColor.CGColor;
        l.lineCap = kCALineCapRound;
        l;
    });
    
    self.ballLayer = ({
        CAShapeLayer *l = [CAShapeLayer layer];
        l.lineWidth = 1.0f;
        l.fillColor = kFaceUColor.CGColor;
        l.strokeColor = kFaceUColor.CGColor;
        l.lineCap = kCALineCapRound;
        l;
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
    self.recordButton.bounds = CGRectMake(0, 0, kRecordW, kRecordW);
    self.recordButton.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 50);
    self.downButton.center = self.recordButton.center;
    self.downButton.bounds = CGRectMake(0, 0, 55, 55);
    self.recaptureButton.center = CGPointMake(60, self.downButton.center.y);
    self.recaptureButton.bounds = CGRectMake(0, 0, 55, 55);
}

#pragma mark - Logic Method

- (void)beginRecord {
    
    unlink([self.moviePath UTF8String]);
    
    [self.view.layer addSublayer:self.cycleLayer];
    [self.view.layer addSublayer:self.progressLayer];
    [self.view.layer addSublayer:self.ballLayer];
    
    [self hideAllFunctionButton];
    
    [(self.filterSwitch.selected ? self.leveBeautyFilter : self.normalFilter) addTarget:self.movieWriter];
    
    [self.movieWriter startRecording];
    
    _timer = [CADisplayLink displayLinkWithTarget:self
                                            selector:@selector(timerupdating)];
    _timer.frameInterval = 3;
    [_timer addToRunLoop:[NSRunLoop currentRunLoop]
                    forMode:NSDefaultRunLoopMode];
    _allTime = 0;
}


- (void)endRecord {
    
    [_timer invalidate];
    _timer = nil;
    
    CABasicAnimation *animation = [CABasicAnimation animation];
    animation.keyPath = @"translate.scale";
    animation.fromValue = [NSNumber numberWithFloat:1.0];
    animation.toValue = [NSNumber numberWithFloat:0.5];
    [self.cycleLayer addAnimation:animation forKey:@"sa"];
    
    [self.cycleLayer removeFromSuperlayer];
    [self.progressLayer removeFromSuperlayer];
    [self.ballLayer removeFromSuperlayer];
    
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
                weakSelf.downButton.alpha = 1.0;
                [UIView animateWithDuration:0.5 animations:^{
                    weakSelf.recordButton.frame = weakSelf.downButton.frame;
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
                [self.view.layer insertSublayer:_avplayer above:self.cameraView.layer];
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
    [self updateProgress:_allTime / kLimitRecLen];
}

- (void)createNewWritter {
    
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
    /// 如果不加上这一句，会出现第一帧闪现黑屏
    [_videoCamera addAudioInputsAndOutputs];
    _videoCamera.audioEncodingTarget = _movieWriter;
}


- (void)hideAllFunctionButton {

    self.recordButton.hidden = YES;
    
    [UIView animateWithDuration:0.5 animations:^{
        self.filterSwitch.alpha = 0;
        self.cameraSwitch.alpha = 0;
        self.flashSwitch.alpha = 0;
    }];
}

- (void)showAllFunctionButton {
    
    self.recordButton.hidden = NO;
    
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
    self.recordButton.bounds = CGRectMake(0, 0, kRecordW, kRecordW);
    self.recordButton.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 50);
    self.recordButton.alpha = 1.0;
    self.downButton.alpha = 0.0;
    self.recaptureButton.alpha = 0.0;
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

- (void)updateProgress:(CGFloat)value {
    NSAssert(value <= 1.0 && value >= 0.0, @"Progress could't accept invail number .");
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:kRecordCenter radius:kRecordW / 2 startAngle:- M_PI_2 endAngle:2 * M_PI * (value) - M_PI_2 clockwise:YES];
    if (value - 0.1 <= CGFLOAT_MIN) {
        CGFloat val = value / 0.1;
        UIBezierPath *ballpath = [UIBezierPath bezierPathWithArcCenter:kRecordCenter radius:(kRecordW / 2  - 10) *val startAngle:0 endAngle:2 * M_PI clockwise:YES];
        self.ballLayer.path = ballpath.CGPath;
    }
    self.progressLayer.path = path.CGPath;
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
