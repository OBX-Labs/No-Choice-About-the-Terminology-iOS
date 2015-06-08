//
//  Choice.m
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import "Choice.h"

#import "OKPoEMMProperties.h"

//Classes
#import "OKTessFont.h"
#import "OKTextObject.h"
#import "OKSentenceObject.h"
#import "OKCharObject.h"

#import "TessSentence.h"
#import "TessGlyph.h"

#import "OKTessData.h"
#import "OKCharDef.h"

#import "OKTouch.h"

static int DIR_LEFT = -1;
static int DIR_NONE = 0;
static int DIR_RIGHT = 1;

static float BG_COLOR[] = {0.0, 0.0, 0.0, 0.0}; // 1.0, 0.0, 0.0, 1.0

// BEHAVIORS
static float FLICK_SCALAR; // 0.175f
static float SCALE_DELAY; // 0.05f

// STATES
static int IDLE = 1;
static int SCALING = 2;
static int RESCALING = 3;
static int DEFORM = 4;
static int REFORM = 5;

// RENDER ORDER
static int BOTTOM = 1;
static int MIDDLE = 2;
static int TOP = 3;

@implementation Choice

- (id) initWithTessFont:(OKTessFont*)aTFFont text:(OKTextObject*)aText andBounds:(CGRect)aBounds
{
    self = [super init];
    if(self)
    {
        // Load propeties
        NSArray *bgColor = [OKPoEMMProperties objectForKey:BackgroundColor];        
        BG_COLOR[0] = [[bgColor objectAtIndex:0] floatValue];
        BG_COLOR[1] = [[bgColor objectAtIndex:1] floatValue];
        BG_COLOR[2] = [[bgColor objectAtIndex:2] floatValue];
        BG_COLOR[3] = [[bgColor objectAtIndex:3] floatValue];        
        FLICK_SCALAR = [[OKPoEMMProperties objectForKey:FlickScalar] floatValue];
        SCALE_DELAY = [[OKPoEMMProperties objectForKey:ScaleDelay] floatValue];
        
        //Tess objects
        tFont = aTFFont;
        
        //Bounds
        sBounds = aBounds;
        
        //Tess objects arrays
        tSentences = [[NSMutableArray alloc] init];
        
        // Scaling Sentence
        scalingSentence = nil;
        
        // Deform Sentence
        deformingSentence = nil;
        
        //Touches
        ctrlPts = [[NSMutableDictionary alloc] init];
        
        //Animation time tracking
        lUpdate = [[NSDate alloc] init];
        now = [[NSDate alloc] init];
                
        [self build:aText.sentenceObjects];
        
        NSLog(@"Total Sentences %i", [tSentences count]);
        
        int tGlyphs = 0;
        for(TessSentence *ts in tSentences)
        {
            for(TessGlyph *tg in ts.tGlyphs)
            {
                tGlyphs++;
            }
        }
        
        NSLog(@"Total Glyphs %i", tGlyphs);
    }
    return self;
}

- (void) build:(NSArray*)aSentences
{
    //Line
    int l = 0;
    
    //Get height of sentences
    float hDivision = sBounds.size.height/[aSentences count];
    
    //Create and position
    for(OKSentenceObject *sentence in aSentences)
    {
        TessSentence *ts = [[TessSentence alloc] initTessSentence:sentence tessFont:tFont direction:((l % 2 == 0) ? DIR_LEFT : DIR_RIGHT) andBounds:sBounds];
        
        float hHeight = [tFont getHeightForString:sentence.sentence]/2.0f;
        
        float center = (hDivision/2.0f) - hHeight;
        float y = ((l + 1) * hDivision) - center;
        float yOffset = (sBounds.size.height - y);
            
        [ts setPosition:OKPointMake(0.0, yOffset, 0.0)];
        
        //Add sentence to array
        [tSentences addObject:ts];
        
        [ts release];
        
        l++;
    }
}

#pragma mark - DRAW

- (void) draw
{
    //Millis since last draw
    DT = (long)([now timeIntervalSinceDate:lUpdate] * 1000);
    [lUpdate release];
    
    //Clear - Draw bg color (open gl)
    glClearColor(BG_COLOR[0], BG_COLOR[1], BG_COLOR[2], BG_COLOR[3]);
    glClear(GL_COLOR_BUFFER_BIT);
    
    //Enable Blending
    glEnable(GL_BLEND);
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    //Draw sentences
    [self drawSentences];
    
    // Update
    [self update:DT];
    
    //Update Sentences
    [self updateTouches:DT];
    
    //Disable Blending
    glDisable(GL_BLEND);
    
    //Keep track of time
    lUpdate = [[NSDate alloc] initWithTimeIntervalSince1970:[now timeIntervalSince1970]];
    [now release];
    now = [[NSDate alloc] init];
}

- (void) drawSentences
{       
    //Draw sentences
    for(TessSentence *ts in tSentences)
    {
        [ts draw];
    }
}

- (void) update:(long)dt
{
    // Update control points
    for(NSString *aKey in ctrlPts)
    {
        KineticObject *ko = [ctrlPts objectForKey:aKey];
        [ko update:dt];
    }
    
    // Update Sentences
    for(TessSentence *ts in tSentences)
    {
        [ts update:dt];
        [ts scroll:dt inBounds:sBounds];
    }
}

- (void) updateTouches:(long)dt
{
    // Update Sentences based on Touches
    if([ctrlPts count] == 0) return;
    
    // Find appropriate touch for given interaction
    // Scale
    KineticObject *f1 = [ctrlPts objectForKey:@"1"]; // 1 = Finger ID which scales when finger 1
    
    if(f1)
    {
        if(!scalingSentence)
            [self findScalingSentence:f1.pos];
        else
            [self updateScalingSentence:f1.pos];
    }
    
    // Deform
    KineticObject *f2 = [ctrlPts objectForKey:@"2"]; // 2 = Finger ID which deforms when finger 2
    
    if(f2)
    {
        if(!deformingSentence)
            [self findDeformingSentence:f2.pos];
        else
            [self updateDeformingSentence:f2.pos];
    }
}

#pragma mark - BEHAVIORS SETTING

- (void) findScalingSentence:(OKPoint)aPos
{    
    for(TessSentence *ts in tSentences)
    {
        if(ts == deformingSentence) continue;
        
        if([ts isInside:CGPointFromOKPoint(aPos)])
        {
            TessGlyph *tg = [ts getGlyphAtPosition:CGPointFromOKPoint(aPos)];
                        
            if(tg)
            {
                // Prepare new sentence
                scalingSentence = [ts retain];
                
                // Start scaling in a few seconds
                [self performSelector:@selector(setCanScale) withObject:nil afterDelay:SCALE_DELAY];
                
                // Brake and set main glyph on scaling sentence
                [scalingSentence brake];
                [scalingSentence setScaleGlyph:tg];
                
                // Match touch
                [scalingSentence followTouch:aPos];
            }
        }
    }
    
    // Set Render Order
    if(scalingSentence)
        [self setRenderOrderFor:scalingSentence at:BOTTOM];
}

- (void) updateScalingSentence:(OKPoint)aPos
{    
    if(![scalingSentence isInside:CGPointFromOKPoint(aPos)])
    {
        // Flick sentence
        [scalingSentence flick:(CGPointFromOKPoint(aPos).x - iPos.x) * FLICK_SCALAR];
        
        // Deselect sentence
        [scalingSentence applyState:RESCALING];
        scalingSentence = nil;
        [scalingSentence release];
        
        // Find new sentence
        [self findScalingSentence:aPos];
    }
    
    // Follow Touch
    if(scalingSentence)
        [scalingSentence followTouch:aPos];
}

- (void) findDeformingSentence:(OKPoint)aPos
{
    for(TessSentence *ts in tSentences)
    {
        if(ts == scalingSentence) continue;
        
        if([ts isInside:CGPointFromOKPoint(aPos)])
        {            
            TessGlyph *tg = [ts getGlyphAtPosition:CGPointFromOKPoint(aPos)];
            
            if(tg)
            {                
                // Prepare new sentence
                deformingSentence = [ts retain];
                
                // Add Deforming Glyph
                [ts addDeformGlyph:tg];
                
                // Make it DEFORM
                [ts applyState:DEFORM];
            }
        }
    }
        
    // Set Render Order
    if(deformingSentence)
        [self setRenderOrderFor:deformingSentence at:MIDDLE];
}

- (void) updateDeformingSentence:(OKPoint)aPos
{  
    if(![deformingSentence isInside:CGPointFromOKPoint(aPos)])
    {
        // Deselect sentence
        [deformingSentence applyState:REFORM];
        [deformingSentence setDrift];        
        deformingSentence = nil;
        [deformingSentence release];
        
        // Find new sentence
        [self findDeformingSentence:aPos];
    }
    else // Sentence is still selected, drift incoming glyphs
    {
        for(TessSentence *ts in tSentences)
        {
            if(ts == scalingSentence) continue;
            
            if([ts isInside:CGPointFromOKPoint(aPos)])
            {
                TessGlyph *tg = [ts getGlyphAtPosition:CGPointFromOKPoint(aPos)];
                
                if(tg)
                {                   
                    // Add Deforming Glyph
                    [ts addDeformGlyph:tg];
                }
            }
        }

    }
}

#pragma mark - Touches

- (void) setCtrlPts:(int)aID atPosition:(CGPoint)aPosition
{
    KineticObject *pt = [ctrlPts objectForKey:[NSString stringWithFormat:@"%i", aID]];
    
    if(!pt)
    {
        KineticObject *ko = [[KineticObject alloc] init];
        [ko setPos:OKPointMake(aPosition.x, aPosition.y, 0.0)];
        
        // Set initial touch position
        if(aID == 1)
            iPos = aPosition;
        
        [ctrlPts setObject:ko forKey:[NSString stringWithFormat:@"%i", aID]];
        pt = ko;
        
        [ko release];
    }
    else
    {
        [pt setPos:OKPointMake(aPosition.x, aPosition.y, 0.0)];
    }
    
    // Set Ctrl Points in TessSentences
    for(TessSentence *ts in tSentences)
    {
        [ts setCtrlPts:pt forID:aID];
    }
}

- (void) removeCtrlPts:(int)aID atPosition:(CGPoint)aPosition
{
    if([ctrlPts count] == 0) return;
        
    // Remove Ctrl Points
    [ctrlPts removeObjectForKey:[NSString stringWithFormat:@"%i", aID]];
    
    for(TessSentence *ts in tSentences)
    {
        [ts removeCtrlPts:aID];
    }
    
    // Find appropriate touch for given interaction
    if(aID == 1) // Finger 1 - Scaling
    {
        // No Scaling Sentence
        if(!scalingSentence) return;
        
        // Flick sentence        
        [scalingSentence flick:(aPosition.x - iPos.x) * FLICK_SCALAR];
        
        // Set Scaling Sentence Inactive
        [scalingSentence applyState:RESCALING];
        
        // If we still have a deforming sentence, the rescaling one should appear on top of it.
        if(deformingSentence)
            [self setRenderOrderFor:deformingSentence at:BOTTOM];
        
        scalingSentence = nil;
        [scalingSentence release];

    }
    
    if(aID == 2) // Finger 2 - Deform
    {
        // No deforming sentence
        if(!deformingSentence) return;
        
        // Set Deforming Sentence Inactive
        [deformingSentence applyState:REFORM];
        [deformingSentence setDrift];
        deformingSentence = nil;
        [deformingSentence release];
    }
}

- (void) touchesBegan:(int)aID atPosition:(CGPoint)aPosition
{
    // Set Control Point
    [self setCtrlPts:aID atPosition:aPosition];
}

- (void) touchesMoved:(int)aID atPosition:(CGPoint)aPosition
{
    // Set Control Point
    [self setCtrlPts:aID atPosition:aPosition];
}

- (void) touchesEnded:(int)aID atPosition:(CGPoint)aPosition
{
    // Remove Control Point
    [self removeCtrlPts:aID atPosition:aPosition];
}

- (void) touchesCancelled:(int)aID atPosition:(CGPoint)aPosition
{
    // Remove Control Point
    [self removeCtrlPts:aID atPosition:aPosition];
}

#pragma mark - BAHVIOURS

- (void) setCanScale
{
    if(scalingSentence)
        [scalingSentence applyState:SCALING];
}

- (void) setRenderOrderFor:(TessSentence*)aTessSentence at:(int)aOrder
{
    if(aOrder == BOTTOM) // Insert in position 0 to draw first
    {
        [tSentences removeObject:aTessSentence];
        [tSentences insertObject:aTessSentence atIndex:0];
    }
    else if(aOrder == MIDDLE) // Insert above BOTTOM TessSentence and below TOP TessSentences
    {
        if(scalingSentence)
        {
            // Find Bottom (First being drawn - in this case, scaling sentence)
            int index = [tSentences indexOfObject:scalingSentence];
                        
            // Apply
            [tSentences removeObject:aTessSentence];
            [tSentences insertObject:aTessSentence atIndex:(index + 1)];
        }
        else
        {            
            // No Scaling sentence, make Deforming bottom
            [tSentences removeObject:aTessSentence];
            [tSentences insertObject:aTessSentence atIndex:0];
        }
    }
    else if(aOrder == TOP) // Insert in last position to draw last
    {
        [tSentences removeObject:aTessSentence];
        [tSentences insertObject:aTessSentence atIndex:[tSentences count]];
    }
}

#pragma mark - GETTERS

- (void) dealloc
{
    [tSentences release];
    [lUpdate release];
    [now release];
    
    [super dealloc];
}

@end
