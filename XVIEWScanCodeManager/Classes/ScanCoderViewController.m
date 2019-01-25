//
//  ScanCoderViewController.m
//  XView
//
//  Created by yyj on 16/6/30.
//  Copyright © 2016年 XiaHeng. All rights reserved.
//

#import "ScanCoderViewController.h"
#import <AVFoundation/AVFoundation.h>
#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)

@interface ScanCoderViewController ()<UIAlertViewDelegate,AVCaptureMetadataOutputObjectsDelegate,UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, weak)   UIView *maskView;
@property (nonatomic, strong) UIView *scanWindow;
@property (nonatomic, strong) UIImageView *scanNetImageView;
@end

@implementation ScanCoderViewController

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.navigationController.viewControllers.count) {
        self.navigationController.navigationBar.hidden = YES;
    }
    [self resumeAnimation];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.navigationController.viewControllers.count) {
        self.navigationController.navigationBar.hidden = YES;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //这个属性必须打开否则返回的时候会出现黑边
    self.title = @"扫码";
    self.view.backgroundColor = [UIColor blackColor];
    self.view.clipsToBounds=YES;
    //1.遮罩
    [self setupMaskView];
    //3.提示文本
    [self setupTipTitleView];
    //4.顶部导航
    [self setupNavView];
    //5.扫描区域
    [self setupScanWindowView];
    
    //判断是否有使用相机的权限
    [self isJudgePhotoAuthorization];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeAnimation) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)isJudgePhotoAuthorization {
    // 在iOS7 时，只有部分地区要求授权才能打开相机
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        // Pre iOS 8 -- No camera auth required.
        //6.开始动画
        [self beginScanning];
    }
    else {
        // iOS 8 后，全部都要授权
        // Thanks: http://stackoverflow.com/a/24684021/2611971
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        switch (status) {
            case AVAuthorizationStatusNotDetermined:{
                // 许可对话没有出现，发起授权许可
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    if (granted) {
                        //第一次用户接受
                        //6.开始动画
                        [self beginScanning];
                    }else{
                        //用户拒绝
                        if (self.scanResult) {
                            self.scanResult(@{@"code":@"-1", @"message":@"扫码失败", @"data":@"用户不允许使用相机"});
                        }
                    }
                }];
                break;
            }
            case AVAuthorizationStatusAuthorized: {
                // 已经开启授权，可继续
                //6.开始动画
                [self beginScanning];
                break;
            }
            case AVAuthorizationStatusDenied:
            case AVAuthorizationStatusRestricted: {
                // 用户明确地拒绝授权，或者相机设备无法访问
                if (self.scanResult) {
                    self.scanResult(@{@"code":@"-1", @"message":@"扫码失败", @"data":@"用户不允许使用相机"});
                }
                break;
            }
            default:
                break;
        }
    }
}
//1.遮罩
- (void)setupMaskView {
    UIView *mask = [[UIView alloc] init];
    _maskView = mask;
    
    mask.layer.borderColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7].CGColor;
    mask.layer.borderWidth = (SCREEN_WIDTH - 240)/2;
    mask.bounds = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    mask.center = CGPointMake(SCREEN_WIDTH * 0.5, SCREEN_HEIGHT * 0.5);
    [self.view addSubview:mask];
    
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake((SCREEN_WIDTH - 240)/2, (SCREEN_WIDTH - 240)/2, 240, (SCREEN_HEIGHT - 240)/2 - (SCREEN_WIDTH - 240)/2)];
    topView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
    [self.view addSubview:topView];
    
    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake((SCREEN_WIDTH - 240)/2, CGRectGetMaxY(topView.frame) + 240, 240, (SCREEN_HEIGHT)/2 - 120 - (SCREEN_WIDTH - 240)/2)];
    bottomView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
    [self.view addSubview:bottomView];
}

//3.提示文本
-(void)setupTipTitleView {
    //2.操作提示
    UILabel * tipLabel = [[UILabel alloc] initWithFrame:CGRectMake((SCREEN_WIDTH - 320)/2, SCREEN_HEIGHT/2 - 120 - 40, 320, 20)];
    tipLabel.text = @"将取景框对准二维码，即可自动扫描";
    tipLabel.textColor = [UIColor whiteColor];
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.lineBreakMode = NSLineBreakByWordWrapping;
    tipLabel.numberOfLines = 2;
    tipLabel.font=[UIFont systemFontOfSize:20];
    tipLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:tipLabel];
}

//4.顶部导航
-(void)setupNavView {
    //1、返回
    UIButton * backBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(20, 44, 20, 20);
    
    [backBtn setBackgroundImage:[UIImage imageNamed:[self imagePath:@"qrcode_scan_titlebar_back_nor@2x.png"]] forState:UIControlStateNormal];
    backBtn.contentMode=UIViewContentModeScaleAspectFit;
    [backBtn addTarget:self action:@selector(disMiss) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backBtn];
    
    //2.相册
    UIButton * albumBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    albumBtn.frame = CGRectMake(SCREEN_WIDTH-55 - 50, 44 , 35, 49 );
    //    albumBtn.center=CGPointMake(SCREEN_WIDTH/2, 20+49/2.0);
    [albumBtn setBackgroundImage:[UIImage imageNamed:[self imagePath:@"qrcode_scan_btn_photo_down@2x.png"]] forState:UIControlStateNormal];
    albumBtn.contentMode=UIViewContentModeScaleAspectFit;
    [albumBtn addTarget:self action:@selector(myAlbum) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:albumBtn];
    
    //3.闪光灯
    UIButton * flashBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    flashBtn.frame = CGRectMake(SCREEN_WIDTH-55, 44, 35, 49);
    [flashBtn setBackgroundImage:[UIImage imageNamed:[self imagePath:@"qrcode_scan_btn_flash_nor@2x.png"]] forState:UIControlStateSelected];
    [flashBtn setBackgroundImage:[UIImage imageNamed:[self imagePath:@"qrcode_scan_btn_flash_down@2x.png"]] forState:UIControlStateNormal];
    flashBtn.contentMode=UIViewContentModeScaleAspectFit;
    [flashBtn addTarget:self action:@selector(openFlash:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:flashBtn];
    
}

//5.扫描区域
- (void)setupScanWindowView {
    CGFloat gap = SCREEN_HEIGHT/2 - 120 - (SCREEN_WIDTH - 240)/2;
    _scanNetImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[self imagePath:@"scan_net@2x.png"]]];
    CGFloat buttonWH = 19;
    
    _scanWindow = [[UIView alloc] initWithFrame:CGRectMake((SCREEN_WIDTH - 240)/2, (SCREEN_WIDTH - 240)/2 + gap - 1, 240, 240)];
    _scanWindow.clipsToBounds = YES;
    [self.view addSubview:_scanWindow];
    
    UIButton *topLeft = [[UIButton alloc] initWithFrame:CGRectMake((SCREEN_WIDTH - 240)/2 - 1 - 1, (SCREEN_WIDTH - 240)/2 + gap - 1, buttonWH, buttonWH)];
    [topLeft setImage:[UIImage imageNamed:[self imagePath:@"scan_1@2x.png"]] forState:UIControlStateNormal];
    [self.view addSubview:topLeft];
    
    UIButton *topRight = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH - (SCREEN_WIDTH - 240)/2 - 19 + 1, topLeft.frame.origin.y + 1, buttonWH, buttonWH)];
    [topRight setImage:[UIImage imageNamed:[self imagePath:@"scan_2@2x.png"]] forState:UIControlStateNormal];
    [self.view addSubview:topRight];
    
    UIButton *bottomLeft = [[UIButton alloc] initWithFrame:CGRectMake((SCREEN_WIDTH - 240)/2 + 1, SCREEN_HEIGHT - (SCREEN_WIDTH - 240)/2 + 1 - gap - 19 - 1, buttonWH, buttonWH)];
    [bottomLeft setImage:[UIImage imageNamed:[self imagePath:@"scan_3@2x.png"]] forState:UIControlStateNormal];
    [self.view addSubview:bottomLeft];
    
    UIButton *bottomRight = [[UIButton alloc] initWithFrame:CGRectMake(topRight.frame.origin.x, bottomLeft.frame.origin.y, buttonWH, buttonWH)];
    [bottomRight setImage:[UIImage imageNamed:[self imagePath:@"scan_4@2x.png"]] forState:UIControlStateNormal];
    [self.view addSubview:bottomRight];
}

- (void)beginScanning {
    //获取摄像设备
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //创建输入流
    AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    if (!input) return;
    //创建输出流
    AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc]init];
    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    //设置有效扫描区域
    CGRect scanCrop=[self getScanCrop:self.view.bounds readerViewBounds:self.view.frame];
    output.rectOfInterest = scanCrop;
    //初始化链接对象
    _session = [[AVCaptureSession alloc]init];
    //高质量采集率
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    
    [_session addInput:input];
    [_session addOutput:output];
    //设置扫码支持的编码格式(如下设置条形码和二维码兼容)
    output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    
    AVCaptureVideoPreviewLayer * layer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    layer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    layer.frame=self.view.layer.bounds;
    [self.view.layer insertSublayer:layer atIndex:0];
    //开始捕获
    [_session startRunning];
}
#pragma mark-> 获取扫描区域的比例关系
-(CGRect)getScanCrop:(CGRect)rect readerViewBounds:(CGRect)readerViewBounds {
    CGFloat x,y,width,height;
    
    x = (CGRectGetHeight(readerViewBounds)-CGRectGetHeight(rect))/2/CGRectGetHeight(readerViewBounds);
    y = (CGRectGetWidth(readerViewBounds)-CGRectGetWidth(rect))/2/CGRectGetWidth(readerViewBounds);
    width = CGRectGetHeight(rect)/CGRectGetHeight(readerViewBounds);
    height = CGRectGetWidth(rect)/CGRectGetWidth(readerViewBounds);
    
    return CGRectMake(x, y, width, height);
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects.count>0) {
        [_session stopRunning];
        
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex : 0];
        if (self.scanResult) {
            self.scanResult(@{@"code":@"0", @"message":@"success", @"data":metadataObject.stringValue});
            [self disMiss];
        }
    }
}

#pragma mark 恢复动画
- (void)resumeAnimation {
    CAAnimation *anim = [_scanNetImageView.layer animationForKey:@"translationAnimation"];
    if(anim){
        // 1. 将动画的时间偏移量作为暂停时的时间点
        CFTimeInterval pauseTime = _scanNetImageView.layer.timeOffset;
        // 2. 根据媒体时间计算出准确的启动动画时间，对之前暂停动画的时间进行修正
        CFTimeInterval beginTime = CACurrentMediaTime() - pauseTime;
        
        // 3. 要把偏移时间清零
        [_scanNetImageView.layer setTimeOffset:0.0];
        // 4. 设置图层的开始动画时间
        [_scanNetImageView.layer setBeginTime:beginTime];
        
        [_scanNetImageView.layer setSpeed:1.0];
        
    } else {
        CGFloat scanNetImageViewH = 241;
        CGFloat scanWindowH = SCREEN_WIDTH - 30 * 2;
        CGFloat scanNetImageViewW = _scanWindow.frame.size.width;
        
        _scanNetImageView.frame = CGRectMake(0, -scanNetImageViewH, scanNetImageViewW, scanNetImageViewH);
        CABasicAnimation *scanNetAnimation = [CABasicAnimation animation];
        scanNetAnimation.keyPath = @"transform.translation.y";
        scanNetAnimation.byValue = @(scanWindowH);
        scanNetAnimation.duration = 1.0;
        scanNetAnimation.repeatCount = MAXFLOAT;
        [_scanNetImageView.layer addAnimation:scanNetAnimation forKey:@"translationAnimation"];
        [_scanWindow addSubview:_scanNetImageView];
    }
}

#pragma mark-> 返回
- (void)disMiss {
    if (self.navigationController.viewControllers && self.navigationController.viewControllers[0] == self) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else if (self.navigationController.viewControllers) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark-> 我的相册
-(void)myAlbum {
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        //1.初始化相册拾取器
        UIImagePickerController *controller = [[UIImagePickerController alloc] init];
        //2.设置代理
        controller.delegate = self;
        //3.设置资源：
        /**
         UIImagePickerControllerSourceTypePhotoLibrary,相册
         UIImagePickerControllerSourceTypeCamera,相机
         UIImagePickerControllerSourceTypeSavedPhotosAlbum,照片库
         */
        controller.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        //4.随便给他一个转场动画
        controller.modalTransitionStyle=UIModalTransitionStyleFlipHorizontal;
        [self presentViewController:controller animated:YES completion:NULL];
        
    } else {
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"请在iPhone的\"设置->隐私->照片\"中允许使用照片" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    }
}
#pragma mark-> imagePickerController delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    //1.获取选择的图片
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    //2.初始化一个监测器
    CIDetector*detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
    
    [picker dismissViewControllerAnimated:YES completion:^{
        //监测到的结果数组
        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
        if (features.count >=1) {
            /**结果对象 */
            CIQRCodeFeature *feature = [features objectAtIndex:0];
            NSString *scannedResult = feature.messageString;
            if (self.scanResult) {
                self.scanResult(@{@"code":@"0", @"message":@"扫描成功", @"data":scannedResult});
                [self disMiss];
            }
        }
        else{
            if (self.scanResult) {
                self.scanResult(@{@"code":@"-1", @"message":@"扫描失败", @"data":@"未发现二维码/条码"});
                [self disMiss];
            }
        }
    }];
}

#pragma mark-> 闪光灯
-(void)openFlash:(UIButton*)button {
    button.selected = !button.selected;
    if (button.selected) {
        [self turnTorchOn:YES];
    }
    else{
        [self turnTorchOn:NO];
    }
}
#pragma mark-> 开关闪光灯
- (void)turnTorchOn:(BOOL)on {
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if ([device hasTorch] && [device hasFlash]){
            
            [device lockForConfiguration:nil];
            if (on) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
            }
            [device unlockForConfiguration];
        }
    }
}
- (NSString *)imagePath:(NSString *)imageName {
    NSString *bundleString = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"ScanCode.bundle"];
    
    NSBundle *bundle = [NSBundle bundleWithPath:bundleString];
    return [bundle pathForResource:imageName ofType:@""];
}
@end
