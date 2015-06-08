//
//  Choice.h
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OKGeometry.h"

//Classes
@class OKTessFont;
@class OKTextObject;
@class OKSentenceObject;
@class OKCharObject;

@class TessSentence;
@class TessGlyph;

@class OKTessData;
@class OKCharDef;

@class OKTouch;

@interface Choice : NSObject
{
    //Screen bounds
    CGRect sBounds;
    
    //Tess objects
    OKTessFont *tFont;
    
    //Tess objects arrays
    NSMutableArray *tSentences;
    
    // Touches
    NSMutableDictionary *ctrlPts;
    
    //Animation time tracking
    NSDate *lUpdate;
    NSDate *now;
    long DT;
    
    //Touches
    CGPoint iPos;
    
    // Scaling Sentence
    TessSentence *scalingSentence;
    
    // Deform Sentence
    TessSentence *deformingSentence;
}

- (id) initWithTessFont:(OKTessFont*)aTFFont text:(OKTextObject*)aText andBounds:(CGRect)aBounds;
- (void) build:(NSArray*)aSentences;

#pragma mark - DRAW

- (void) draw;
- (void) drawSentences;
- (void) update:(long)dt;
- (void) updateTouches:(long)dt;

#pragma mark - BEHAVIORS SETTING
// Touch 1
- (void) findScalingSentence:(OKPoint)aPos;
- (void) updateScalingSentence:(OKPoint)aPos;
// Touch 2
- (void) findDeformingSentence:(OKPoint)aPos;
- (void) updateDeformingSentence:(OKPoint)aPos;

#pragma mark - Touches

- (void) setCtrlPts:(int)aID atPosition:(CGPoint)aPosition;
- (void) removeCtrlPts:(int)aID atPosition:(CGPoint)aPosition;

- (void) touchesBegan:(int)aID atPosition:(CGPoint)aPosition;
- (void) touchesMoved:(int)aID atPosition:(CGPoint)aPosition;
- (void) touchesEnded:(int)aID atPosition:(CGPoint)aPosition;
- (void) touchesCancelled:(int)aID atPosition:(CGPoint)aPosition;

#pragma mark - BAHVIOURS

- (void) setCanScale;
- (void) setRenderOrderFor:(TessSentence*)aTessSentence at:(int)aOrder;

@end
