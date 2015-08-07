//
//  ViewController.m
//  OperationQueueAndGCD
//
//  Created by Alan.Yen on 2015/8/7.
//  Copyright (c) 2015年 17Life All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property(nonatomic, strong) NSOperationQueue *queue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 內容參考: http://blog.csdn.net/hello_hwc/article/details/46659311
    // 選擇GCD or NSOperationQueue？
    // 這個其實沒有標準答案，NSOperationQueue是GCD的上層封裝，何為封裝？就是把一些功能包裝到一起提供給開發者。在iOS開發的時候有一個原則
    // 優先選用上層API，除非上層API不能實現，或者實現後有性能問題，才會選擇底層。
    // 關於這個問題，其實不同人有不同的理解和習慣。個人的見解是，分析下自己的任務的性質
    
    // 以下情況下優先考慮NSOperationQueue
    // 1. 任務之間有依賴關係
    // 2. 限制最大可執行的任務數量。
    // 3. 任務有可能被取消
    
    // 以下情況下優先考慮GCD：
    //
    // 1. 任務就是簡單的Block提交
    // 2. 任務之間需要複雜的Block嵌套
    // 3. 任務需要非常頻繁的提交。
    //    （這點簡單提一下，因為NSOperation是對象，對象要分配額外的內存和釋放內存，如果這個過程非常頻繁，CPU損耗巨大
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 測試執行相依的 task
        // [self tryTaskDependencyWithNSOperationQueue];
        // [self tryTaskDependencyWithGCD];
        [self tryObserveNSOperationQueue];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tryTaskDependencyWithNSOperationQueue {
    
    // 內容參考: http://blog.csdn.net/hello_hwc/article/details/46659311
    // 有三個任務，任務一和任務二可以同時進行，任務三必須在任務一和任務二都完成了之後才能執行。
    // 最後，在三個任務都完成了通知用戶。
    // 看看用NSOperationQueue如何實現
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    NSBlockOperation *task1 = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"starting task1");
        sleep(3);
        NSLog(@"task1 is done");
    }];

    NSBlockOperation *task2 = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"starting task2");
        sleep(3);
        NSLog(@"task2 is done");
    }];
    
    NSBlockOperation *task3 = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"starting task3");
        sleep(3);
        NSLog(@"task3 is done");
    }];
    
    [task2 addDependency:task1];
    [task3 addDependency:task1];
    [task3 addDependency:task2];
    
    NSBlockOperation *doneOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"All task is done");
    }];
    
    [doneOperation addDependency:task1];
    [doneOperation addDependency:task2];
    [doneOperation addDependency:task3];
    
    [queue addOperations:@[task1, task2, task3, doneOperation] waitUntilFinished:NO];
}

- (void)tryTaskDependencyWithGCD {
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_group_async(group, globalQueue, ^{
        sleep(1);
        NSLog(@"task1 is done");
    });
    
    dispatch_group_async(group, globalQueue, ^{
        sleep(2);
        NSLog(@"task2 is done");
    });
    
    dispatch_group_notify(group, globalQueue, ^{
        
        dispatch_async(globalQueue, ^{
            sleep(1);
            NSLog(@"task3 is done");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"All task is done");
            });
        });
    });
}

- (void)tryObserveNSOperationQueue {
    
    // 內容參考: http://blog.csdn.net/gavinming/article/details/7061719
    // NSOperationQueue 線程隊列完畢 finished 狀態檢測
    self.queue = [[NSOperationQueue alloc] init];
    // [self.queue addObserver:self forKeyPath:@"operations" options:NSKeyValueObservingOptionNew context:nil];
    [self.queue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:nil];
    
    NSBlockOperation *task1 = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"starting task1");
        sleep(3);
        NSLog(@"task1 is done");
    }];
    
    NSBlockOperation *task2 = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"starting task2");
        sleep(3);
        NSLog(@"task2 is done");
    }];
    
    NSBlockOperation *task3 = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"starting task3");
        sleep(3);
        NSLog(@"task3 is done");
    }];
    
    [task2 addDependency:task1];
    [task3 addDependency:task1];
    [task3 addDependency:task2];
    
    NSBlockOperation *doneOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"All task is done (Operation)");
    }];
    
    [doneOperation addDependency:task1];
    [doneOperation addDependency:task2];
    [doneOperation addDependency:task3];
    
    [self.queue addOperations:@[task1, task2, task3, doneOperation] waitUntilFinished:NO];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    // KVO,觀察 queue 是否執行完
    if (object == self.queue && [keyPath isEqualToString:@"operations"]) {
        if (0 == self.queue.operations.count) {
            NSLog(@"All task is done (KVO: operations)");
            [self.queue setSuspended:YES];
        }
    }
    // KVO,觀察 queue 是否執行完
    else if (object == self.queue && [keyPath isEqualToString:@"operationCount"]) {
        if (0 == self.queue.operations.count) {
            NSLog(@"All task is done (KVO: operationCount)");
            [self.queue setSuspended:YES];
        }
    }
    else {
        // 參考: http://www.dribin.org/dave/blog/archives/2008/09/24/proper_kvo_usage/
        // 有談到為什麼要這麼寫
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
