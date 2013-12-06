/*
 
 File: ViewController.m
 
 Copyright (c) 2013 Dillion Tan
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "ViewController.h"
#import "MetaballUIView.h"

@interface ViewController ()

@end

@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.metaballUIView = [[MetaballUIView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:_metaballUIView];
    
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, self.view.frame.size.width-20, 44)];
    infoLabel.text = @"Double tap to create a metaball";
    infoLabel.textColor = [UIColor whiteColor];
    infoLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    [self.view addSubview:infoLabel];
    
    self.doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gesture:)];
    _doubleTap.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:_doubleTap];
    
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _clearButton.frame = CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44);
    _clearButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
    [_clearButton setTitle:@"CLEAR" forState:UIControlStateNormal];
    [_clearButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_clearButton addTarget:self action:@selector(clear:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_clearButton];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)gesture:(UITapGestureRecognizer *)doubleTap
{
    if (doubleTap.state == UIGestureRecognizerStateRecognized) {
        CGPoint location = [doubleTap locationInView:self.view];
        
        [_metaballUIView addMetaballAtPosition:GLKVector2Make(location.x, location.y) size:2.0f * (arc4random()%15) + 10.0f];
    }
}

- (void)clear:(id)sender
{
    [_metaballUIView removeMetaballs];
}

@end
