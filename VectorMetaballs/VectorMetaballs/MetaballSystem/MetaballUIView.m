/*
 
 File: MetaballUIView.h
 
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

#import "MetaballUIView.h"
#import "Metaball.h"

#define MAXSTEPS 400
#define RESOLUTION 4

typedef struct {
    CGPoint position;
    CGFloat force;
} PositionForce;

@implementation MetaballUIView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        self.multipleTouchEnabled = YES;
        
        Metaball *metaball = [[Metaball alloc] initWithPosition:CGPointMake(220, 200) size:50.0];
        
        self.metaballArray = [NSMutableArray array];
        [_metaballArray addObject:metaball];
        
        [self drawMetaballSystem];
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    
    CGContextClearRect(context, rect);
    
    if (pathRef) {
        CGContextSetLineWidth(context, 2.0f);
        [[UIColor whiteColor] setStroke];
        [[UIColor whiteColor] setFill];
        
        CGContextAddPath(context, pathRef);
        CGContextDrawPath(context, kCGPathStroke);
    }
    
    CGContextRestoreGState(context);
}

#pragma mark
#pragma mark Metaball calculation

- (void)drawMetaballSystem
{
    minSize = CGFLOAT_MAX;
    
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        Metaball *metaball = (Metaball *)obj;
        minSize = MIN(metaball.size, minSize);
    }];
    
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        Metaball *metaball = (Metaball *)obj;
        metaball.edge = [self trackBorder:CGPointMake(metaball.position.x, metaball.position.y)];
        metaball.tracked = NO;
    }];
    
    __block Metaball *currentMetaball = [self untrackedMetaball];
    
    CGMutablePathRef mutablePathRef = CGPathCreateMutable();
    __block CGPoint edge = currentMetaball.edge;
    CGPathMoveToPoint(mutablePathRef, NULL, edge.x, edge.y);
    
    int edgeSteps = 0;
    while (currentMetaball && edgeSteps < MAXSTEPS) {
        PositionForce positionForce;
        positionForce.force = RESOLUTION;
        positionForce.position = edge;
        
        edge = [self rungeKutta2:positionForce];
        
        edge = [self stepToBorder:edge].position;
        
        CGPathAddLineToPoint(mutablePathRef, NULL, edge.x, edge.y);
        
        __block CGPoint previousEdge = CGPointMake(edge.x, edge.y);
        
        [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            
            Metaball *metaball = (Metaball *)obj;
            if ([self distanceFromPoint:metaball.edge toPoint:previousEdge] < RESOLUTION * 0.5) {
                
                edge = metaball.edge;
                currentMetaball.tracked = YES;
                
                if (metaball.tracked) {
                    currentMetaball = [self untrackedMetaball];
                    
                    if (currentMetaball) {
                        edge = currentMetaball.edge;
                        CGPathMoveToPoint(mutablePathRef, NULL, edge.x, edge.y);
                    } else {
                    }
                    
                } else {
                    currentMetaball = metaball;
                }
                
                *stop = YES;
            }
        }];
        
        ++edgeSteps;
    }
    
    if (pathRef) CGPathRelease(pathRef);
    pathRef = CGPathCreateCopy(mutablePathRef);
    
    CGPathRelease(mutablePathRef);
}

- (Metaball *)untrackedMetaball
{
    __block NSInteger index = NSNotFound;
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        Metaball *metaball = (Metaball *)obj;
        if (!metaball.tracked) {
            index = idx;
            *stop = YES;
        }
    }];
    
    if (index != NSNotFound) {
        return [_metaballArray objectAtIndex:index];
    } else {
        return nil;
    }
}

- (CGFloat)vectorLength:(CGPoint)vector
{
    return sqrtf(powf(vector.x,2) + powf(vector.y, 2));
}

- (CGFloat)calculateForce:(CGPoint)position
{
    __block CGFloat force = 0;
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        Metaball *metaball = (Metaball *)obj;
        CGFloat div = powf([self vectorLength:CGPointMake(metaball.position.x - position.x, metaball.position.y - position.y)], GOOIENESS);
        if (div != 0.0f) {
            force += metaball.size / div;
        } else {
            force += 100000;
        }
    }];
    
    return force;
}

- (CGPoint)calculateNormal:(CGPoint)position
{
    __block CGPoint normal = CGPointZero;
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        Metaball *metaball = (Metaball *)obj;
        CGPoint radius = CGPointMake(metaball.position.x - position.x, metaball.position.y - position.y);
        CGFloat length = [self vectorLength:radius];
        if (length != 0) {
            CGFloat multiply = (-1) * GOOIENESS * metaball.size / powf(length, 2 + GOOIENESS);
            normal = CGPointMake(normal.x + radius.x * multiply, normal.y + radius.y * multiply);
        }
    }];
    CGFloat magnitude = [self vectorLength:normal];
    
    return CGPointMake(normal.x / magnitude, normal.y / magnitude);
}

- (PositionForce)stepToBorder:(CGPoint)position
{
    CGFloat force = [self calculateForce:position];
    CGPoint normal = [self calculateNormal:position];
    CGFloat stepSize = powf((minSize / THRESHOLD), 1.0 / GOOIENESS) - powf((minSize / force), 1.0 / GOOIENESS) + FLT_EPSILON;
    PositionForce positionForce;
    positionForce.position = CGPointMake(position.x + normal.x*stepSize, position.y + normal.y*stepSize);
    positionForce.force = force;
    
    return positionForce;
}

- (CGPoint)trackBorder:(CGPoint)position
{
    PositionForce positionForce;
    positionForce.force = CGFLOAT_MAX;
    positionForce.position = CGPointMake(position.x, position.y + 1);
    
    int reps = 0;
    CGFloat previousForce = 0;
    while (fabsf(positionForce.force - previousForce) > FLT_EPSILON && positionForce.force > THRESHOLD) {
        previousForce = positionForce.force;
        positionForce = [self stepToBorder:positionForce.position];
        reps++;
    }
    return positionForce.position;
}

- (CGPoint)rungeKutta2:(PositionForce)positionForce
{
    CGPoint normal = [self calculateNormal:positionForce.position];
    CGPoint t1 = CGPointMake(normal.y * RESOLUTION * -0.5, normal.x * RESOLUTION * 0.5);
    
    CGPoint normal2 = [self calculateNormal:CGPointMake(positionForce.position.x + t1.x, positionForce.position.y + t1.y)];
    CGPoint t2 = CGPointMake(normal2.y * RESOLUTION * -1, normal2.x * RESOLUTION);
    
    return CGPointMake(positionForce.position.x + t2.x, positionForce.position.y + t2.y);
}

- (CGFloat)distanceFromPoint:(CGPoint)point1 toPoint:(CGPoint)point2
{
    CGFloat x1 = point1.x - point2.x;
    CGFloat y1 = point1.y - point2.y;
    
    return x1*x1 + y1*y1;
}

#pragma mark
#pragma mark Touch interaction

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    __block NSUInteger index = 0;
    [touches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        if ([_metaballArray count] > index) {
            UITouch *touch = (UITouch *)obj;
            Metaball *currentMetaball = [_metaballArray objectAtIndex:index];
            currentMetaball.position = [touch locationInView:self];
            index++;
        } else {
            *stop = YES;
        }
    }];
    
    [self drawMetaballSystem];
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    __block NSUInteger index = 0;
    [touches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        if ([_metaballArray count] > index) {
            UITouch *touch = (UITouch *)obj;
            Metaball *currentMetaball = [_metaballArray objectAtIndex:index];
            currentMetaball.position = [touch locationInView:self];
            index++;
        } else {
            *stop = YES;
        }
    }];
    
    [self drawMetaballSystem];
    [self setNeedsDisplay];
}

#pragma mark

- (void)addMetaballAtPosition:(CGPoint)position size:(CGFloat)size
{
    Metaball *newMetaball = [[Metaball alloc] initWithPosition:position size:size];
    [_metaballArray addObject:newMetaball];
    
    [self drawMetaballSystem];
    [self setNeedsDisplay];
}

- (void)removeMetaballs
{
    [_metaballArray removeAllObjects];
    CGPathRelease(pathRef);
    pathRef = NULL;
    
    [self setNeedsDisplay];
}

@end
