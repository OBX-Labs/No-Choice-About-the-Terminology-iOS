//
//  TessSentence.m
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import "TessSentence.h"
#import "OKPoEMMProperties.h"

#import "OKTessFont.h"
#import "OKBitmapFont.h"
#import "OKSentenceObject.h"
#import "OKCharObject.h"

#import "TessGlyph.h"

//DEBUG settings
static BOOL DEBUG_BOUNDS = NO;

static int TF_ACCURACY; // iPad 3 iPhone 2

// SCALE
static float SCALE_SPEED; // iPad 0.95f iPhone 0.2375f
static float RESCALE_SPEED; // 7.5f
static float MIN_GLYPH_SCALE; // 1.0f
static float MAX_GLYPH_SCALE; // iPad 150.0f iPhone 105.0f
static float GLYPH_SCALE_FRICTION; // 0.0f

// DEFORM
static float LENS_MAGNIFICAION; // iPad 1.0f iPhone 0.5f
static float LENS_DIAMETER; // 20.0f iPhone 10.0f
static float REFORM_SPEED; // 0.225f
static float REFORM_MAX_DEFORM_GLYPHS_SPEED; // iPad 0.035f iPhone 0.0175f
static int MAX_DEFORM_GLYPHS; // 10

// COLORS 
static float FILL_COLOR_IDLE[] = {0.0, 0.0, 0.0, 0.0}; // 0.0, 0.0, 0.0, 1.0
static float FILL_COLOR_IDLE_FADE_SPEED; // 1000.0f;
static float FILL_COLOR_TOUCH1[] = {0.0, 0.0, 0.0, 0.0}; // 1.0, 1.0, 0.31, 1.0
static float FILL_COLOR_TOUCH1_FADE_SPEED; // 1000.0f;
static float FILL_COLOR_TOUCH2[] = {0.0, 0.0, 0.0, 0.0}; // 0.42, 0.02, 0.58, 1.0
static float FILL_COLOR_TOUCH2_FADE_SPEED; // 1000.0f;

// DIRECTIONS
static int DIR_LEFT = -1;
static int DIR_NONE = 0;
static int DIR_RIGHT = 1;

// STATES
static int IDLE = 1;
static int SCALING = 2;
static int RESCALING = 3;
static int DEFORM = 4;
static int REFORM = 5;

@implementation TessSentence
@synthesize tGlyphs;

- (id) initTessSentence:(OKSentenceObject*)aSentence tessFont:(OKTessFont*)aTFFont direction:(int)aDirection andBounds:(CGRect)aBounds
{
    self = [super init];
    if(self)
    {                
        // Properties
        TF_ACCURACY = [[OKPoEMMProperties objectForKey:TessellationAccuracy] floatValue];
        SCALE_SPEED = [[OKPoEMMProperties objectForKey:ScaleSpeed] floatValue];
        RESCALE_SPEED = [[OKPoEMMProperties objectForKey:RescaleSpeed] floatValue];
        MIN_GLYPH_SCALE = [[OKPoEMMProperties objectForKey:MinimumScale] floatValue];
        MAX_GLYPH_SCALE = [[OKPoEMMProperties objectForKey:MaximumScale] floatValue];
        GLYPH_SCALE_FRICTION = [[OKPoEMMProperties objectForKey:ScaleFriction] floatValue];        
        LENS_MAGNIFICAION = [[OKPoEMMProperties objectForKey:LensMagnification] floatValue];
        LENS_DIAMETER = [[OKPoEMMProperties objectForKey:LensDiameter] floatValue];
        REFORM_SPEED = [[OKPoEMMProperties objectForKey:ReformSpeed] floatValue];
        REFORM_MAX_DEFORM_GLYPHS_SPEED = [[OKPoEMMProperties objectForKey:ReformSpeedForMaximumDeformGlyphs] floatValue];
        MAX_DEFORM_GLYPHS = [[OKPoEMMProperties objectForKey:MaximumDeformingGlyphs] floatValue];
        NSArray *fillColorIdle = [OKPoEMMProperties objectForKey:FillColorIdle];
        FILL_COLOR_IDLE[0] = [[fillColorIdle objectAtIndex:0] floatValue];
        FILL_COLOR_IDLE[1] = [[fillColorIdle objectAtIndex:1] floatValue];
        FILL_COLOR_IDLE[2] = [[fillColorIdle objectAtIndex:2] floatValue];
        FILL_COLOR_IDLE[3] = [[fillColorIdle objectAtIndex:3] floatValue];
        FILL_COLOR_IDLE_FADE_SPEED  = [[OKPoEMMProperties objectForKey:FillColorIdleFadeSpeed] floatValue];
        NSArray *fillColorFinger1 = [OKPoEMMProperties objectForKey:FillColorFinger1];
        FILL_COLOR_TOUCH1[0] = [[fillColorFinger1 objectAtIndex:0] floatValue];
        FILL_COLOR_TOUCH1[1] = [[fillColorFinger1 objectAtIndex:1] floatValue];
        FILL_COLOR_TOUCH1[2] = [[fillColorFinger1 objectAtIndex:2] floatValue];
        FILL_COLOR_TOUCH1[3] = [[fillColorFinger1 objectAtIndex:3] floatValue];
        FILL_COLOR_TOUCH1_FADE_SPEED  = [[OKPoEMMProperties objectForKey:FillColorFinger1FadeSpeed] floatValue];
        NSArray *fillColorFinger2 = [OKPoEMMProperties objectForKey:FillColorFinger2];
        FILL_COLOR_TOUCH2[0] = [[fillColorFinger2 objectAtIndex:0] floatValue];
        FILL_COLOR_TOUCH2[1] = [[fillColorFinger2 objectAtIndex:1] floatValue];
        FILL_COLOR_TOUCH2[2] = [[fillColorFinger2 objectAtIndex:2] floatValue];
        FILL_COLOR_TOUCH2[3] = [[fillColorFinger2 objectAtIndex:3] floatValue];
        FILL_COLOR_TOUCH2_FADE_SPEED  = [[OKPoEMMProperties objectForKey:FillColorFinger2FadeSpeed] floatValue];
        
        //Tess objects
        tFont = aTFFont;
        
        // Screen bounds
        sBounds = aBounds;
        
        //Sentence object
        sentence = aSentence;
        
        //Touches
        ctrlPts = [[NSMutableDictionary alloc] init];
        
        // Set State
        state = IDLE;
        
        //Set Direction
        [self setDirection:aDirection];
        origDirection = aDirection;
        
        //Tess objects arrays
        tGlyphs = [[NSMutableArray alloc] init];
                
        // Deforming Glyphs
        dGlyphs = [[NSMutableArray alloc] init];
        rGlyphs = [[NSMutableArray alloc] init];
        
        [self build:sentence.glyphObjects];
    }
    return self;
}

- (void) build:(NSArray*)aChars
{    
    //Code to get center of sentence
    pos = OKPointMake([sentence getX], [sentence getY], 0.0);
    
    //Create
    for(OKCharObject *glyph in aChars)
    {        
        TessGlyph *tg = [[TessGlyph alloc] initTessGlyph:glyph tessFont:tFont parent:self accuracy:TF_ACCURACY andBounds:sBounds];
        
        //Add sentence to array
        [tGlyphs addObject:tg];
        
        [tg release];
    }
    
    lGlyph = 0;
    rGlyph = ([tGlyphs count] - 1);
}

#pragma mark - DRAW

- (void) draw
{
    //Draw glyphs
    
    //Transform
    glPushMatrix();
    glTranslatef(pos.x, pos.y, pos.z);
    
    for(TessGlyph *tg in rGlyphs)
    {
        //Update color
        float *clr = [tg getColor];
        glColor4f(clr[0], clr[1], clr[2], clr[3]);
        
        [tg draw];
    }
    
    // Deform glyph on bottom
    for(TessGlyph *tg in dGlyphs)
    {
        //Update color
        float *clr = [tg getColor];
        glColor4f(clr[0], clr[1], clr[2], clr[3]);
        
        [tg draw];
    }
    
    // Normal glyphs in the middle
    for(TessGlyph *tg in tGlyphs)
    {
        if(tg != sGlyph && ![dGlyphs containsObject:tg] && ![rGlyphs containsObject:tg])
        {
            //Update color
            float *clr = [tg getColor];
            glColor4f(clr[0], clr[1], clr[2], clr[3]);
            
            [tg draw];
        }
        
        if([rGlyphs containsObject:tg] && [tg isIdle])
        {
            [rGlyphs removeObject:tg];
        }
    }
    
    // Scaling glyph on top
    if(sGlyph)
    {
        //Update color
        float *clr = [sGlyph getColor];
        glColor4f(clr[0], clr[1], clr[2], clr[3]);
        
        [sGlyph draw];
    }
    
    //Draw sentence bounds
    if(DEBUG_BOUNDS)
    {        
        //debug bounding box
        const GLfloat line[] =
        {
            0.0f , 0.0f, //point A
            0.0f, [sentence getHeight], //point B
            sBounds.size.width, [sentence getHeight], //point C
            sBounds.size.width, 0.0f, //point D
        };
        
        glVertexPointer(2, GL_FLOAT, 0, line);
        //glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 4);
    }
    
    glPopMatrix();
}

- (void) update:(long)dt
{        
    // Update sentece based on state
    if(state == SCALING)
       [self scale:MAX_GLYPH_SCALE speed:SCALE_SPEED friction:GLYPH_SCALE_FRICTION];
    else if(state == RESCALING)
        [self scale:MIN_GLYPH_SCALE speed:RESCALE_SPEED friction:GLYPH_SCALE_FRICTION];
    else if(state == DEFORM)
        [self lens];
    else if(state == REFORM)
        [self reform:REFORM_SPEED];
    else if([self isIdle])
        [self applyState:IDLE];
    
    // Check when no touch is detected that the sentence is reshaping
    // (fixes a bug that if a sentence is scaling and deforming at the same time,
    // it can't decide which one to do and jams on a behavior).
    if([ctrlPts count] == 0)
    {
        if(![self isIdle])
        {            
            if([self isScaling])
                [self applyState:RESCALING];
            
            if([self isDeforming])
                [self applyState:REFORM];
            
            if([self isRepositioning])
               [self setDrift];
            
            if(state == REFORM && [dGlyphs count] > 0)
               [self setDrift];
        }
    }
    
    // Update glyphs
    [self updateGlyphs:dt];
}

- (void) updateGlyphs:(long)dt
{
    for(TessGlyph *tg in tGlyphs)
    {
        [tg update:dt];
        
        float FILL_COLOR_TOUCH4[] = {0.42, 0.02, 0.58, 0.0};
        
        if([tg isScaling])
            [sGlyph fadeTo:FILL_COLOR_TOUCH1 withSpeed:FILL_COLOR_TOUCH1_FADE_SPEED];
        else if([dGlyphs containsObject:tg])
            [tg fadeTo:FILL_COLOR_TOUCH2 withSpeed:FILL_COLOR_TOUCH2_FADE_SPEED];
        else if([rGlyphs containsObject:tg])
            [tg fadeTo:FILL_COLOR_TOUCH4 withSpeed:FILL_COLOR_IDLE_FADE_SPEED];
        else
            [tg fadeTo:FILL_COLOR_IDLE withSpeed:FILL_COLOR_IDLE_FADE_SPEED];
    }
}

#pragma mark - TOUCHES

- (void) setCtrlPts:(KineticObject*)aCtrlPt forID:(int)aID
{    
    [ctrlPts setObject:aCtrlPt forKey:[NSString stringWithFormat:@"%i", aID]];
}

- (void) removeCtrlPts:(int)aID
{
    [ctrlPts removeObjectForKey:[NSString stringWithFormat:@"%i", aID]];
}

#pragma mark - BAHVIOURS

- (void) scroll:(long)dt inBounds:(CGRect)b
{    
    //Scroll left
    if(direction == DIR_LEFT)
    {
        //Go through glyphs
        int count = 0;
        for(TessGlyph *tg in tGlyphs)
        {
            [tg scroll:dt];
                    
            if(count == lGlyph)
            {                                
                if(tg.pos.x + [tFont getWidthForString:tg.charObj.glyph] < b.origin.x)
                {                    
                    [tg setAfterRightMostGlyph:[tGlyphs objectAtIndex:rGlyph]];
                                        
                    rGlyph = lGlyph;
                    
                    if(lGlyph == ([tGlyphs count] - 1))
                        lGlyph = 0;
                    else
                        lGlyph++;
                }
            }
            
            count++;
        }
    }
    else if(direction == DIR_RIGHT)
    {
        for(int i = [tGlyphs count] - 1; i >= 0; i--)
        {
            TessGlyph *tg = [tGlyphs objectAtIndex:i];
            
            [tg scroll:dt];
            
            if(i == rGlyph)
            {
                if(tg.pos.x - [tFont getWidthForString:tg.charObj.glyph] > b.size.width)
                {
                    [tg setBeforeLeftMostGlyph:[tGlyphs objectAtIndex:lGlyph]];
                                     
                    lGlyph = rGlyph;
                    
                    if(rGlyph == 0)
                        rGlyph = ([tGlyphs count] - 1);
                    else
                        rGlyph--;
                }
            }
        }
    }
}

- (void) brake
{
    for(TessGlyph *tg in tGlyphs)
    {
        [tg setVel:OKPointMake(0.0, 0.0, 0.0)];
    }
}

- (void) scale:(float)aScale speed:(float)aSpeed friction:(float)aFriction
{
    for(TessGlyph *tg in tGlyphs)
    {
        [tg scale:aScale speed:aSpeed friction:aFriction];
    }
}

- (void) lens
{
    // Deform
    KineticObject *f2 = [ctrlPts objectForKey:@"2"]; // 2 = Finger ID which deforms when finger 2
    
    if(f2)
    {
        [self setDefaultSpeed];
        
        [self lens:f2.pos magnification:LENS_MAGNIFICAION diameter:LENS_DIAMETER];
    }
    else
        [self applyState:REFORM];
}

- (void) lens:(OKPoint)aPos magnification:(float)aMagnification diameter:(float)aDiameter
{
    for(TessGlyph *tg in dGlyphs)
    {
        [tg lens:aPos magnification:aMagnification diameter:aDiameter];
    }
    
    [self reform:REFORM_SPEED];
}
    
- (void) reform:(float)aSpeed
{
    for(TessGlyph *tg in tGlyphs)
    {
        if(![dGlyphs containsObject:tg] && ![rGlyphs containsObject:tg])
            [tg reform:aSpeed];
        else if([rGlyphs containsObject:tg])
            [tg reform:REFORM_MAX_DEFORM_GLYPHS_SPEED];
    }
}

- (void) followTouch:(OKPoint)aPosition
{    
    if(!sGlyph)
        return;
    
    int tDir;
    
    if(aPosition.x - sGlyph.pos.x > 0.0) tDir = DIR_RIGHT;
    else if(aPosition.x - sGlyph.pos.x < 0.0) tDir = DIR_LEFT;
    else tDir = DIR_NONE;
    
    float tOffset = aPosition.x - sGlyph.pos.x;
    
    for(TessGlyph *tg in tGlyphs)
    {
        [tg setPos:OKPointAdd(tg.pos, OKPointMake(tOffset, 0, 0))];
        
        if(tDir != DIR_NONE)
            [self setDirection:tDir];
    }
}

- (void) flick:(float)aVelocity
{
    int nDir;
    float nVel = aVelocity;
    
    if(nVel < 0.0f)
        nDir = DIR_LEFT;
    else if(nVel > 0.0f)
        nDir = DIR_RIGHT;
        
    for(TessGlyph *tg in tGlyphs)
    {
        [tg setVel:OKPointMake(nVel, 0.0, 0.0)];
    }
    
    [self setDirection:nDir];
}

- (void) setDefaultSpeed
{
    for(TessGlyph *tg in tGlyphs)
    {
        [tg setDefaultSpeed];
    }
}

#pragma mark - PROPERTIES

- (BOOL) isInside:(CGPoint)p { return (CGRectContainsPoint([self getAbsoluteBounds], p) ? YES : NO); }

- (BOOL) isScaling
{
    for(TessGlyph *tg in tGlyphs)
    {
        if([tg isScaling])
            return YES;
    }
    
    return NO;
}

- (BOOL) isDeforming
{
    for(TessGlyph *tg in tGlyphs)
    {
        if([tg isDeforming])
            return YES;
    }
    
    return NO;
}

- (BOOL) isRepositioning
{
    for(TessGlyph *tg in tGlyphs)
    {
        if([tg isRepositioning])
            return YES;
    }
    
    return NO;
}

- (BOOL) isIdle
{
    for(TessGlyph *tg in tGlyphs)
    {
        if(![tg isIdle])
            return NO;
    }
    
    return YES;
}

#pragma mark - SETTERS

- (void) setPosition:(OKPoint)aPosition { [self setPos:aPosition]; }

- (void) setScaleGlyph:(TessGlyph*)aGlyph { sGlyph = aGlyph; }

- (void) addDeformGlyph:(TessGlyph*)aGlyph
{
    [aGlyph drift];
    
    // Remove first glyph is max is reached
    if([self getDeformingCount] >= MAX_DEFORM_GLYPHS)
        [self removeDeformGlyph];
    
    if(![dGlyphs containsObject:aGlyph])
        [dGlyphs addObject:aGlyph];
    
    [self applyState:DEFORM];
}

- (void) removeDeformGlyph
{
    // Get first glyph
    TessGlyph *tg = [dGlyphs objectAtIndex:0];
        
    // Add to temp and remove from deform
    [rGlyphs addObject:tg];
    [dGlyphs removeObject:tg];
}

- (void) removeDeformGlyph:(TessGlyph*)aGlyph
{    
    // Add to temp and remove from deform
    [rGlyphs addObject:aGlyph];
    [dGlyphs removeObject:aGlyph];
}

- (void) setDrift
{
    for(TessGlyph *tg in dGlyphs)
    {
        [tg undrift];
    }
    
    for(TessGlyph *tg in rGlyphs)
    {
        [tg undrift];
    }
    
    [dGlyphs removeAllObjects];
    [rGlyphs removeAllObjects];
}

- (void) setDirection:(int)aDirection { direction = aDirection; }

- (void) applyState:(int)aState { state = aState; }

#pragma mark - GETTERS

- (int) getDirection { return direction; }

- (int) getOriginalDirection { return origDirection; }

- (CGRect) getAbsoluteBounds
{
    BOOL sUseGlyph = NO;
    float nPos = 0.0f;
    
    if([sentence getWitdh] < sBounds.size.width)
    {
        TessGlyph *tg = [tGlyphs objectAtIndex:lGlyph];
        nPos = tg.pos.x;
        sUseGlyph = YES;
    }
    
    return CGRectMake((sUseGlyph ? nPos : pos.x), pos.y, [sentence getWitdh], [sentence getHeight]);
}

- (TessGlyph*) getGlyphAtPosition:(CGPoint)aPos
{
    for(TessGlyph *tg in tGlyphs)
    {        
        if([tg isInside:aPos] && ![rGlyphs containsObject:tg])
        {
            if([tg.charObj.glyph isEqualToString:@" "])
               return [self siblingForSpace:tg];
            else
                return tg;
        }
    }

    return nil;
}

- (int) getDeformingCount { return [dGlyphs count]; };

#pragma mark - SIBLINGS

- (TessGlyph*) getRightSiblingForChild:(TessGlyph*)aGlyph
{
    return ([tGlyphs indexOfObject:aGlyph] < ([tGlyphs count] - 1) ? [tGlyphs objectAtIndex:([tGlyphs indexOfObject:aGlyph] + 1)] : nil);
}

- (TessGlyph*) getLeftSiblingForChild:(TessGlyph*)aGlyph
{
    return ([tGlyphs indexOfObject:aGlyph] > 0 ? [tGlyphs objectAtIndex:([tGlyphs indexOfObject:aGlyph] - 1)] : nil);
}

- (TessGlyph*) getRightMostChild
{
    return [tGlyphs lastObject];
}

- (TessGlyph*) getLeftMostChild
{
    return [tGlyphs objectAtIndex:0];
}

- (TessGlyph*) siblingForSpace:(TessGlyph*)aGlyph
{    
    if([self getDirection] == DIR_LEFT)
        return [self getRightSiblingForChild:aGlyph];
    else if([self getDirection] == DIR_RIGHT)
        return [self getLeftSiblingForChild:aGlyph];
    
    return (((arc4random() % 100) % 2 == 0) ? [self getRightSiblingForChild:aGlyph] : [self getLeftSiblingForChild:aGlyph]);
}

- (void) dealloc
{
    [dGlyphs release];
    [rGlyphs release];
    [ctrlPts release];
    [tGlyphs release];
    
    [super dealloc];
}

@end
