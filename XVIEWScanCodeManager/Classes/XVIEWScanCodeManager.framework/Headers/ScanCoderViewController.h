//
//  ScanCoderViewController.h
//  XView
//
//  Created by yyj on 16/6/30.
//  Copyright © 2016年 XiaHeng. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ScanCoderViewController : UIViewController

@property (nonatomic, copy) void (^scanResult) (NSDictionary *resultDict);
/**
 resultDict=@{@“result”:@“返回结果”};
 result为扫描结果,否则result为失败原因
 */
@end
