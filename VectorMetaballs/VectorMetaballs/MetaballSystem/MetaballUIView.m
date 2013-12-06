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
    GLKVector2 position;
    CGFloat force;
} PositionForce;

@implementation MetaballUIView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        self.multipleTouchEnabled = YES;
        
        Metaball *metaball = [[Metaball alloc] initWithPosition:GLKVector2Make(220, 200) size:50.0];
        
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
        metaball.edge = [self trackBorder:metaball.position];
        metaball.tracked = NO;
    }];
    
    __block Metaball *currentMetaball = [self untrackedMetaball];
    
    CGMutablePathRef mutablePathRef = CGPathCreateMutable();
    __block GLKVector2 edge = currentMetaball.edge;
    CGPathMoveToPoint(mutablePathRef, NULL, edge.x, edge.y);
    
    int edgeSteps = 0;
    while (currentMetaball && edgeSteps < MAXSTEPS) {
        PositionForce positionForce;
        positionForce.force = RESOLUTION;
        positionForce.position = edge;
        
        edge = [self rungeKutta2:positionForce];
        
        edge = [self stepToBorder:edge].position;
        
        CGPathAddLineToPoint(mutablePathRef, NULL, edge.x, edge.y);
        
        __block GLKVector2 previousEdge = GLKVector2Make(edge.x, edge.y);
        
        [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            
            Metaball *metaball = (Metaball *)obj;
            if (GLKVector2Distance(metaball.edge, previousEdge) < RESOLUTION * 0.5) {
                
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

- (CGFloat)calculateForce:(GLKVector2)position
{
    __block CGFloat force = 0;
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        Metaball *metaball = (Metaball *)obj;
        CGFloat div = powf(GLKVector2Distance(metaball.position, position), GOOIENESS);
        if (div != 0.0f) {
            force += metaball.size / div;
        } else {
            force += 100000;
        }
    }];
    
    return force;
}

- (GLKVector2)calculateNormal:(GLKVector2)position
{
    __block GLKVector2 normal = GLKVector2Make(0,0);
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        Metaball *metaball = (Metaball *)obj;
        GLKVector2 radius = GLKVector2Subtract(metaball.position, position);
        CGFloat length = GLKVector2Length(radius);
        if (length != 0) {
            CGFloat multiply = (-1) * GOOIENESS * metaball.size / powf(length, 2 + GOOIENESS);
            normal = GLKVector2Add(normal, GLKVector2MultiplyScalar(radius, multiply));
        }
    }];
    
    return GLKVector2Normalize(normal);
}

- (PositionForce)stepToBorder:(GLKVector2)position
{
    CGFloat force = [self calculateForce:position];
    GLKVector2 normal = [self calculateNormal:position];
    CGFloat stepSize = powf((minSize / THRESHOLD), 1.0 / GOOIENESS) - powf((minSize / force), 1.0 / GOOIENESS) + FLT_EPSILON;
    PositionForce positionForce;
    positionForce.position = GLKVector2Add(position, GLKVector2MultiplyScalar(normal, stepSize));
    positionForce.force = force;
    
    return positionForce;
}

- (GLKVector2)trackBorder:(GLKVector2)position
{
    PositionForce positionForce;
    positionForce.force = CGFLOAT_MAX;
    positionForce.position = GLKVector2Make(position.x, position.y + 1);
    
    int reps = 0;
    CGFloat previousForce = 0;
    while (fabsf(positionForce.force - previousForce) > FLT_EPSILON && positionForce.force > THRESHOLD) {
        previousForce = positionForce.force;
        positionForce = [self stepToBorder:positionForce.position];
        reps++;
    }
    return positionForce.position;
}

- (GLKVector2)rungeKutta2:(PositionForce)positionForce
{
    GLKVector2 normal = [self calculateNormal:positionForce.position];
    GLKVector2 t1 = GLKVector2Make(normal.y * RESOLUTION * -0.5, normal.x * RESOLUTION * 0.5);
    
    GLKVector2 normal2 = [self calculateNormal:GLKVector2Add(positionForce.position, t1)];
    GLKVector2 t2 = GLKVector2Make(normal2.y * RESOLUTION * -1, normal2.x * RESOLUTION);
    
    return GLKVector2Add(positionForce.position, t2);
}

#pragma mark
#pragma mark Touch interaction

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self updateMetaballsForTouchSet:touches];
    
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
    [self updateMetaballsForTouchSet:touches];
    
    [self drawMetaballSystem];
    [self setNeedsDisplay];
}

#pragma mark

- (void)addMetaballAtPosition:(GLKVector2)position size:(CGFloat)size
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

- (void)updateMetaballsForTouchSet:(NSSet *)touches
{
    __block NSMutableSet *trackedTouches = [touches mutableCopy];
    
    [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        __block CGFloat shortestDistanceToMetaballs = CGFLOAT_MAX;
        __block CGFloat distanceToCurrentMetaball = CGFLOAT_MAX;
        __block UITouch *matchingTouch;
        __block Metaball *movedMetaball;
        
        [_metaballArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            
            Metaball *currentMetaball = (Metaball *)obj;
            
            if ([trackedTouches count] > 0) {
                
                [trackedTouches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                    UITouch *touch = (UITouch *)obj;
                    CGPoint location = [touch locationInView:self];
                    CGFloat distance = GLKVector2Distance(currentMetaball.position, GLKVector2Make(location.x, location.y));
                    if (distance < distanceToCurrentMetaball) {
                        distanceToCurrentMetaball = distance;
                        matchingTouch = touch;
                    }
                }];
                
                if (distanceToCurrentMetaball < shortestDistanceToMetaballs) {
                    shortestDistanceToMetaballs = distanceToCurrentMetaball;
                    movedMetaball = currentMetaball;
                }
            }
        }];
        
        if (movedMetaball) {
            CGPoint movedPoint = [matchingTouch locationInView:self];
            movedMetaball.position = GLKVector2Make(movedPoint.x, movedPoint.y);
            [trackedTouches removeObject:matchingTouch];
        }
    }];
}

@end
