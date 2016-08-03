//
//  ViewController.m
//  test_block
//
//  Created by zhangyan on 16/5/12.
//  Copyright © 2016年 zhangyan. All rights reserved.
//

#import "ViewController.h"
typedef long (^sum_block)(int a, int b);

@interface ViewController ()
{
     NSObject* _instanceObj;
}
@property (nonatomic, retain) NSString* someVar;
@end

@implementation ViewController
@synthesize someVar;

NSObject* __globalObj = nil;
- (void) test {
    static NSObject* __staticObj = nil;
    __globalObj = [[NSObject alloc] init];
    __staticObj = [[NSObject alloc] init];
    
    NSObject* localObj = [[NSObject alloc] init];
    __block NSObject* blockObj = [[NSObject alloc] init];
    
    typedef void (^MyBlock)(void) ;
    MyBlock aBlock = ^{
        NSLog(@"%@", __globalObj);
        NSLog(@"%@", __staticObj);
        NSLog(@"%@", _instanceObj);
        NSLog(@"%@", localObj);
        NSLog(@"%@", blockObj);
    };
    aBlock = [aBlock copy];
    NSLog(@"aBlock = %@", aBlock);
    aBlock();
    
//    NSLog(@"%lu", [__globalObj retainCount]);
//    NSLog(@"%lu", [__staticObj retainCount]);
//    NSLog(@"%lu", [_instanceObj retainCount]);
//    NSLog(@"%lu", [localObj retainCount]);
//    NSLog(@"%lu", [blockObj retainCount]);
    /*
     __globalObj和__staticObj在内存中的位置是确定的，所以Block copy时不会retain对象。
     _instanceObj在Block copy时也没有直接retain _instanceObj对象本身，"但会retain self"。
     所以在Block中可以直接读写_instanceObj变量。
     localObj在Block copy时，系统自动retain对象，增加其引用计数。
     blockObj在Block copy时也不会retain。
     非ObjC对象，如GCD队列dispatch_queue_t。Block copy时并不会自动增加他的引用计数，这点要非常小心。
     */
}
/*
 Block中使用的ObjC对象的行为
 对象obj在Block被copy到堆上的时候自动retain了一次。
 因为Block不知道obj什么时候被释放，为了不在Block使用obj前被释放，
 Block retain了obj一次，在Block被释放的时候，obj被release一次。
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _instanceObj = [[NSObject alloc] init];
    [self test];
    
    typedef void (^myBlock)(void);
//    打破循环引用法1
    __block ViewController* weakSelf = self;
    
    myBlock alo = ^{
        NSLog(@"%@", self.someVar);
    };
//    打破循环引用法2
    NSString* str = self.someVar;
    myBlock aloa = ^{
        NSLog(@"%@", str);
    };
    
    sum_block sumBl = [self sumBlock1];
    long sum = sumBl(1,2);
    NSLog(@"sum = %d",sum);
    
    sum_block sumBl2 = [self sumBlock2];
    long sum2 = sumBl2(1,2);
    NSLog(@"sum2 = %d",sum2);
    
    sum_block sumBl3 = [self sumBlock3];
    long sum3 = sumBl3(1,2);
    NSLog(@"sum3 = %d",sum3);
    
    sum_block sumBl4 = [self sumBlock4];
    long sum4 = sumBl4(1,2);
    NSLog(@"sum4 = %d",sum4);
    
    foo();
    
    dispatch_queue_t mySerialDispatchQueue = dispatch_queue_create("com.example.gcd.MySerialDispatchQueue", DISPATCH_QUEUE_CONCURRENT);
//    Global Dispatch Queue是所有应用程序都能够使用的Concurrent Dispatch Queue，没有必要通过dispatch_queue_create函数逐个生成Concurrent Dispatch Queue。只要获取Global Dispatch Queue使用就可以了。
//    默认优先级的Global Dispatch Queue中执行Block
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //可并行执行的处理
        //在Main Dispatch Queue中执行Block
        dispatch_async(dispatch_get_main_queue(), ^{
            //只能在主线程中执行的处理
        });
    });
//    ［array count］
    dispatch_apply(10, mySerialDispatchQueue, ^(size_t index){
        NSLog(@"dsf = index %d",index);
        
    });
    
//    同步死锁,并且卡住线程
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_sync(queue, ^{
        NSLog(@"Hello");
    });
    
}
/*
 *根据Block在内存中的位置分为三种类型NSGlobalBlock，NSStackBlock, NSMallocBlock。
 
 NSGlobalBlock：类似函数，位于text段；
 NSStackBlock：位于栈内存，函数返回后Block将无效；
 NSMallocBlock：位于堆内存。
 */
- (sum_block)sumBlock1
{
    sum_block blk = ^long (int a, int b)
    {
        return  a + b;
    };
    NSLog(@"blk1 = %@", blk);//__NSGlobalBlock__
    return blk;
}
//在Block内变量base是只读的，如果想在Block内改变base的值，在定义base时要用 __block修饰
- (sum_block)sumBlock2
{
    int base = 100;
    sum_block blk = ^long (int a, int b)
    {
//        base++;编译错误，只读局部自动变量，在Block中只读。Block定义时copy变量的值，在Block中作为常量使用，所以即使变量的值在Block外改变，也不影响他在Block中的值。
        return base + a + b;
    };
    NSLog(@"blk2 = %@", blk);//__NSStackBlock__
    base++;
    long sum = blk(1,2);
    NSLog(@"sum1 = %d", sum);
    
//    Block中使用__block修饰的变量时，将取变量此刻运行时的值，而不是定义时的快照
    __block int basea = 100;
    sum_block blka = ^long (int a, int b)
    {
        return basea + a + b;
    };
    basea++;
    long suma = blka(1,2);
    NSLog(@"suma = %d", suma);
    return blk;
}
- (sum_block)sumBlock3
{
    int base = 100;
    sum_block blk = ^long (int a, int b)
    {
        return base + a + b;
    };
    sum_block blkc = [blk copy];//__NSMallocBlock__
    NSLog(@"blk3 = %@", blk);
    NSLog(@"blkc = %@", blkc);
    base++;
    long sum = blkc(1,2);
    NSLog(@"sum3 = %d", sum);
    
    return blk;
}
/*
 static变量、全局变量。因为全局变量或静态变量在内存中的地址是固定的，
 Block在读取该变量值的时候是直接从其所在内存读出，
 获取到的是最新值，而不是在定义时copy的常量。
 */
- (sum_block)sumBlock4
{
    __block int base = 100;
    sum_block blk = ^long (int a, int b)
    {
        base++;
        return base + a + b;
    };
    base = 0;
    NSLog(@"base = %d", base);
    NSLog(@"sum4 = %d", blk(1,2));
    NSLog(@"base = %d", base);
    
    return blk;
}
/*
 为什么blk1类型是NSGlobalBlock，而blk2类型是NSStackBlock？
 blk1和blk2的区别在于，blk1没有使用Block以外的任何外部变量，
 Block不需要建立局部变量值的快照，这使blk1与函数没有任何区别，
 从blk1所在内存地址0x47d0猜测编译器把blk1放到了text代码段。
 blk2与blk1唯一不同是的使用了局部变量base，在定义（注意是定义，不是运行）blk2时，
 局部变量base当前值被copy到栈上，作为常量供Block使用
 */



/*
 Block的copy、retain、release操作
 不同于NSObjec的copy、retain、release操作：
 1F790C837B3707DBF09C8F75ED50D809
 Block_copy与copy等效，Block_release与release等效；
 对Block不管是retain、copy、release都不会改变引用计数retainCount，retainCount始终是1；
 NSGlobalBlock：retain、copy、release操作都无效；
 NSStackBlock：retain、release操作无效，必须注意的是，NSStackBlock在函数返回后，Block内存将被回收。
 即使retain也没用。容易犯的错误是[[mutableAarry addObject:stackBlock]，在函数出栈后，
 从mutableAarry中取到的stackBlock已经被回收，变成了野指针。
 正确的做法是先将stackBlock copy到堆上，然后加入数组：[mutableAarry addObject:[[stackBlock copy] autorelease]]。支持copy，copy之后生成新的NSMallocBlock类型对象。
 NSMallocBlock支持retain、release，虽然retainCount始终是1，但内存管理器中仍然会增加、减少计数。
 copy之后不会生成新的对象，只是增加了一次引用，类似retain；尽量不要对Block使用retain操作。
 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
/*
 Block变量，被__block修饰的变量称作Block变量。 基本类型的Block变量等效于全局变量、或静态变量。
 Block被另一个Block使用时，另一个Block被copy到堆上时，被使用的Block也会被copy。但作为参数的Block是不会发生copy的。
 */
void foo() {
    int base = 100;
    sum_block blk = ^ long (int a, int b) {
        return  base + a + b;
    };
    NSLog(@"%@", blk); // <__NSStackBlock__: 0xbfffdb40>
    bar(blk);
}

void bar(sum_block sum_blk) {
    NSLog(@"%@",sum_blk); // 与上面一样，说明作为参数传递时，并不会发生copy
    
    void (^blk) (sum_block) = ^ (sum_block sum) {
        NSLog(@"%@",sum);     // 无论blk在堆上还是栈上，作为参数的Block不会发生copy。
        NSLog(@"%@",sum_blk); // 当blk copy到堆上时，sum_blk也被copy了一分到堆上上。
    };
    blk(sum_blk); // blk在栈上
    
    blk = [blk copy];
    blk(sum_blk); // blk在堆上
}
@end

















