//
//  TessSentence.h
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KineticObject.h"

//Classes
@class OKTessFont;
@class OKSentenceObject;
@class OKCharObject;

@class TessGlyph;

@interface TessSentence : KineticObject
{
    //Screen bounds
    CGRect sBounds;
    
    //Tess objects
    OKTessFont *tFont;
    
    //Sentence object
    OKSentenceObject *sentence;
    
    // Touches
    NSMutableDictionary *ctrlPts;
    
    //Properties
    int direction;
    int origDirection;
    int state;
    
    //Ends
    int lGlyph;
    int rGlyph;
    
    // Selected Glyphs
    TessGlyph *sGlyph; // Scaling Glyph (selected)
    NSMutableArray *dGlyphs; // Deforming glyphs
    NSMutableArray *rGlyphs; // Reforming glyphs (added here when too many on screen)
}

//Tess objects arrays
@property (nonatomic, retain) NSMutableArray *tGlyphs;

- (id) initTessSentence:(OKSentenceObject*)aSentence tessFont:(OKTessFont*)aTFFont direction:(int)aDirection andBounds:(CGRect)aBounds;
- (void) build:(NSArray*)aChars;

#pragma mark - DRAW

- (void) draw;
- (void) update:(long)dt;
- (void) updateGlyphs:(long)dt;

#pragma mark - TOUCHES

- (void) setCtrlPts:(KineticObject*)aCtrlPt forID:(int)aID;
- (void) removeCtrlPts:(int)aID;

#pragma mark - BAHVIOURS

- (void) scroll:(long)dt inBounds:(CGRect)b;
- (void) brake;
- (void) scale:(float)aScale speed:(float)aSpeed friction:(float)aFriction;
- (void) lens;
- (void) lens:(OKPoint)aPos magnification:(float)aMagnification diameter:(float)aDiameter;
- (void) reform:(float)aSpeed;
- (void) followTouch:(OKPoint)aPosition;
- (void) flick:(float)aVelocity;
- (void) setDefaultSpeed;

#pragma mark - PROPERTIES

- (BOOL) isInside:(CGPoint)p;
- (BOOL) isScaling;
- (BOOL) isDeforming;
- (BOOL) isRepositioning;
- (BOOL) isIdle;

#pragma mark - SETTERS

- (void) setPosition:(OKPoint)aPosition;
- (void) setScaleGlyph:(TessGlyph*)aGlyph;
- (void) addDeformGlyph:(TessGlyph*)aGlyph;
- (void) removeDeformGlyph;
- (void) removeDeformGlyph:(TessGlyph*)aGlyph;
- (void) setDrift;
- (void) setDirection:(int)aDirection;
- (void) applyState:(int)aState;

#pragma mark - GETTERS

- (int) getDirection;
- (int) getOriginalDirection;
- (CGRect) getAbsoluteBounds;
- (TessGlyph*) getGlyphAtPosition:(CGPoint)aPos;
- (int) getDeformingCount;

#pragma mark - SIBLINGS

- (TessGlyph*) getRightSiblingForChild:(TessGlyph*)aGlyph;
- (TessGlyph*) getLeftSiblingForChild:(TessGlyph*)aGlyph;
- (TessGlyph*) getRightMostChild;
- (TessGlyph*) getLeftMostChild;
- (TessGlyph*) siblingForSpace:(TessGlyph*)aGlyph;

@end
