//
//  TessGlyph.h
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KineticObject.h"

//Classes
@class OKTessFont;
@class OKCharObject;

@class TessSentence;

@class OKTessData;
@class OKCharDef;

#define ARC4RANDOM_MAX 0x100000000

@interface TessGlyph : KineticObject
{
    //Rendering bounds
    CGRect rBounds;
    
    //Tess objects
    OKTessFont *tFont;
        
    //TessSentence (parent)
    TessSentence *parent;
    
    //Tesselated Data
    OKTessData *origData;
    OKTessData *dfrmData;
            
    CGRect bounds;
    CGRect absBounds;
    
    //3d points in 2d space arrays
	GLfloat modelview[16];
	GLfloat projection[16];
    
    // Lens Deltas
    GLfloat *lastDeltas;
    
    //Color
    float clr[4]; //color
    float clrTarget[4]; //target color
    
    float clrRedStep, clrGreenStep, clrBlueStep, clrAlphaStep;  //fading speed
    BOOL isSetColor;
    
    // Deform
    BOOL isDeform;
    BOOL isDrifting;
    BOOL sReposition;
    
    // Outline
    BOOL canVertexArray;
}

//Char object
@property (nonatomic, strong) OKCharObject *charObj;

- (id) initTessGlyph:(OKCharObject*)aChar tessFont:(OKTessFont*)aTFFont parent:(TessSentence*)aParent accuracy:(int)aAccuracy andBounds:(CGRect)aBounds;
- (void) buildWithAccuracy:(int)aAccuracy;
- (OKTessData*) tesselate:(OKCharDef*)aCharDef accuracy:(int)aAccuracy;

#pragma mark - DRAW

- (void) draw;
- (void) drawOutlines:(OKTessData*)aData;
- (void) drawDebugBoundsForMinX:(float)minX maxX:(float)maxX minY:(float)minY maxY:(float)maxY;
- (void) update:(long)dt;

#pragma mark - COLOR

- (void) updateColor:(long)dt;
- (void) setColor:(float*)c;
- (float*) getColor;
- (BOOL) isColorSet;
- (void) fadeTo:(float*)c withSpeed:(float)aSpeed;

#pragma mark - BEHAVIOURS

#pragma mark - BEHAVIOURS 1 TOUCH
- (void) scroll:(long)dt;
- (void) scale:(float)aScale speed:(float)aSpeed friction:(float)aFriction;
- (void) setDefaultSpeed;

#pragma mark - BEHAVIOURS 2 TOUCH
- (void) drift;
- (void) undrift;
- (void) reposition;
- (void) lens:(OKPoint)aPos magnification:(float)aMagnification diameter:(float)aDiameter;
- (void) reform:(float)aSpeed;

#pragma mark - PROPERTIES

- (BOOL) isOutside:(CGRect)b;
- (BOOL) isInside:(CGPoint)p;
- (BOOL) isScaling;
- (BOOL) isDeforming;
- (BOOL) isRepositioning;
- (BOOL) isIdleColor;
- (BOOL) isIdle;

#pragma mark - SETTERS

- (void) setAfterRightMostGlyph:(TessGlyph*)aR;
- (void) setBeforeLeftMostGlyph:(TessGlyph*)aL;

#pragma mark - GETTERS

- (CGRect) getBounds;
- (CGRect) getAbsoluteBounds;
- (OKPoint) getAbsoluteCoordinates;
- (OKPoint) transform:(OKPoint)aPoint;

#pragma mark - POINT CONVERSION

- (CGPoint) convertPoint:(CGPoint)aPoint withZ:(float)z;

#pragma mark - RANDOM

- (float) floatRandom;
- (float) arc4randomf:(float)max :(float)min;

@end
