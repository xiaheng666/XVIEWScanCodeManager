//
//  XVIEWScanCodeManager.h
//  XVIEWScanCodeManager
//
//  Created by yyj on 2019/1/4.
//  Copyright © 2019 zd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XVIEWScanCodeManager : NSObject

/**
 *  单例
 */
+ (instancetype)sharedScanCodeManager;

/**
 *  扫描二维码
 @param param     currentVC:当前vc
                  callback:回调方法
 */
- (void)scan:(NSDictionary *)param;

/**
 *  相册识别二维码
 @param param     currentVC:当前vc
                  callback:回调方法
 */
- (void)recognize:(NSDictionary *)param;

/**
 *  解析图片中二维码
 @param param     data:{base64:base64的图片}
                  currentVC:当前vc
                  callback:回调方法
 */
- (void)setImage:(NSDictionary *)param;

/**
 *  生成二维码
 @param param     data:{string:要生成二维码的字符串}
                  currentVC:当前vc
                  callback:回调方法
 */
- (void)getCode:(NSDictionary *)param;

@end
