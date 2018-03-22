//
//  TessGlyph.m
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import "TessGlyph.h"
#import "OKPoEMMProperties.h"

//Classes
#import "OKTessFont.h"
#import "OKCharObject.h"

#import "TessSentence.h"

#import "OKTessData.h"
#import "OKCharDef.h"

//DEBUG settings
static BOOL DEBUG_BOUNDS = NO;

static float GLYPH_SCROLL_MIN_SPEED; // iPad 6.0f iPhone 3.0f
static float GLYPH_SCROLL_MAX_SPEED; // iPad 48.0f iPhone 24.0f
static float GLYPH_SCROLL_FRICTION; // 0.98f

static float FILL_COLOR_IDLE[] = {0.0, 0.0, 0.0, 0.0}; // 0.0, 0.0, 0.0, 1.0
static float OUTLINE_COLOR_TOUCH2[] = {0.0, 0.0, 0.0, 0.0}; // 1.0, 0.0, 0.04, 0.59
static float OUTLINE_WIDTH; // 1.0f;
static float RENDER_PADDING; // iPad 20.0f iPhone 10.0f

@implementation TessGlyph
@synthesize charObj;

- (id) initTessGlyph:(OKCharObject*)aChar tessFont:(OKTessFont*)aTFFont parent:(TessSentence*)aParent accuracy:(int)aAccuracy andBounds:(CGRect)aBounds
{
    self = [super init];
    if(self)
    {        
        // Properties
        GLYPH_SCROLL_MIN_SPEED = [[OKPoEMMProperties objectForKey:MinimumScrollSpeed] floatValue];
        GLYPH_SCROLL_MAX_SPEED = [[OKPoEMMProperties objectForKey:MaximumScrollSpeed] floatValue];
        GLYPH_SCROLL_FRICTION = [[OKPoEMMProperties objectForKey:ScrollFriction] floatValue];
        NSArray *fillColorIdle = [OKPoEMMProperties objectForKey:FillColorIdle];
        FILL_COLOR_IDLE[0] = [[fillColorIdle objectAtIndex:0] floatValue];
        FILL_COLOR_IDLE[1] = [[fillColorIdle objectAtIndex:1] floatValue];
        FILL_COLOR_IDLE[2] = [[fillColorIdle objectAtIndex:2] floatValue];
        FILL_COLOR_IDLE[3] = [[fillColorIdle objectAtIndex:3] floatValue];
        NSArray *outlineColor = [OKPoEMMProperties objectForKey:OutlineColor];
        OUTLINE_COLOR_TOUCH2[0] = [[outlineColor objectAtIndex:0] floatValue];
        OUTLINE_COLOR_TOUCH2[1] = [[outlineColor objectAtIndex:1] floatValue];
        OUTLINE_COLOR_TOUCH2[2] = [[outlineColor objectAtIndex:2] floatValue];
        OUTLINE_COLOR_TOUCH2[3] = [[outlineColor objectAtIndex:3] floatValue];
        OUTLINE_WIDTH = [[OKPoEMMProperties objectForKey:OutlineWidth] floatValue];
        RENDER_PADDING = [[OKPoEMMProperties objectForKey:RenderPadding] floatValue];
                
        //Tess objects
        tFont = aTFFont;
        
        // Set Rendering Padding
        float x = [tFont getMaxWidth] + RENDER_PADDING;
        float width = aBounds.size.width + (x * 2);
        rBounds = CGRectMake(-x, aBounds.origin.y, width, aBounds.size.height);
        
        //Char object
        charObj = aChar;
                
        //TessSentence (parent)
        parent = aParent;
        
        //Color
        clr[0] = 0.0f;
		clr[1] = 0.0f;
		clr[2] = 0.0f;
		clr[3] = 0.0f;
		
		clrTarget[0] = 0.0f;
		clrTarget[1] = 0.0f;
		clrTarget[2] = 0.0f;
		clrTarget[3] = 1.0f;
        
        isDeform = NO;
        isDrifting = NO;
        sReposition = NO;
        
        canVertexArray = NO;
        NSString *reqVer = @"5.0.0";
        NSString *currVer = [[UIDevice currentDevice] systemVersion];
        if ([currVer compare:reqVer options:NSNumericSearch] != NSOrderedAscending)
            canVertexArray = YES;
        
        [self buildWithAccuracy:aAccuracy];
    }
    return self;
}

- (void) buildWithAccuracy:(int)aAccuracy
{        
    //Set velocity
    [self setVel:OKPointMake([parent getDirection] * GLYPH_SCROLL_MIN_SPEED, 0.0, 0.0)];
    [self setOrigVel:vel];
    
    //Get the center of the glyph and use that as the position
    OKPoint nPoint = [charObj getPositionAbsolute];
    CGRect gBounds = [charObj getLocalBoundingBox];
    
    OKPoint gCenter = OKPointMake((gBounds.origin.x + gBounds.size.width/2.0), (gBounds.origin.y + gBounds.size.height/2.0), 0.0);    
    
    nPoint = OKPointAdd(nPoint, gCenter);
    [self setPos:nPoint];
    
    //Tessalate text in original form
    origData = [self tesselate:[tFont getCharDefForChar:charObj.glyph] accuracy:aAccuracy];
        
    //Offset the vertices so they are relative to the glyph's position
    if(origData.endsCount > 0)
    {
        GLfloat *vertices = [origData getVertices];
        int numVertices = [origData numVertices];
        
        // Lens Deltas
        lastDeltas = new GLfloat[numVertices * 2];
        
        for(int i = 0; i < numVertices; i++)
        {
            vertices[i * 2 + 0] -= gCenter.x;
            vertices[i * 2 + 1] -= gCenter.y;
            
            lastDeltas[i * 2 + 0] = 0.0;
            lastDeltas[i * 2 + 1] = 0.0;
        }
    }
    
    //Clone to deformed data
    dfrmData = [origData copy];
}

- (OKTessData*) tesselate:(OKCharDef*)aCharDef accuracy:(int)aAccuracy
{
    return [[aCharDef.tessData objectForKey:[NSString stringWithFormat:@"%i", aAccuracy]] copy];
}

#pragma mark - DRAW

- (void) draw
{
    //Transform
    glPushMatrix();
    
    if(isDrifting)
        glTranslatef(csPos.x, csPos.y, csPos.z);
    else
        glTranslatef(pos.x, pos.y, pos.z);
    
    glScalef(sca, sca, 0.0);
    
    //Keep track of bounding box
    float minX = CGFLOAT_MAX;
    float minY = CGFLOAT_MAX;
    float maxX = CGFLOAT_MIN;
    float maxY = CGFLOAT_MIN;
    
    //Draw deformed data
    if(dfrmData)
    {
        OKTessData *data = dfrmData;
        
        if(data.endsCount > 0)
        {
            //sBounds
            if(![self isOutside:rBounds])
            {
                for(int i = 0; i < data.shapesCount; i++)
                {
                    glVertexPointer(2, GL_FLOAT, 0, [data getVertices:i]);
                    //glEnableClientState(GL_VERTEX_ARRAY);
                    glDrawArrays([data getType:i], 0, [data numVertices:i]);
                }
            }
            
            // Draw outline
            if(isDeform)
                [self drawOutlines:data];
            
            // Determine bounds for actual glyph
            GLfloat *vertices = [origData getVertices:0];
                
            for(int i = 0; i < origData.verticesCount; i++)
            {
                if(vertices[i * 2 + 0] < minX) minX = vertices[i * 2 + 0];
                if(vertices[i * 2 + 0] > maxX) maxX = vertices[i * 2 + 0];
                if(vertices[i * 2 + 1] < minY) minY = vertices[i * 2 + 1];
                if(vertices[i * 2 + 1] > maxY) maxY = vertices[i * 2 + 1];
            }
        }
        else // Should be space
        {
            if([charObj.glyph isEqualToString:@" "])
            {
                minX = [charObj getMinX];
                maxX = [charObj getMaxX];
                minY = [charObj getMinY];
                maxY = [charObj getMaxY];
            }
        }
    }
        
    bounds = CGRectMake(minX, minY, maxX - minX, maxY - minY);
    
    glPushMatrix();
    
    glGetFloatv(GL_MODELVIEW_MATRIX, modelview);
    
    glPopMatrix();
    
    glGetFloatv(GL_PROJECTION_MATRIX, projection);
    
    //Might need to offset to absPos of Glyph
    CGPoint aPointMin = [self convertPoint:CGPointMake(minX, minY) withZ:0.0];
    CGPoint aPointMax = [self convertPoint:CGPointMake(maxX, maxY) withZ:0.0];
    
    absBounds = CGRectMake(aPointMin.x, aPointMin.y, aPointMax.x - aPointMin.x, aPointMax.y - aPointMin.y);
    
    if(absBounds.size.width < 1) absBounds.size.width++;
    if(absBounds.size.height < 1) absBounds.size.height++;
    
    if(DEBUG_BOUNDS)
       [self drawDebugBoundsForMinX:minX maxX:maxX minY:minY maxY:maxY];
    
    glPopMatrix();
}

- (void) drawOutlines:(OKTessData*)aData
{
    glColor4f(OUTLINE_COLOR_TOUCH2[0], OUTLINE_COLOR_TOUCH2[1], OUTLINE_COLOR_TOUCH2[2], OUTLINE_COLOR_TOUCH2[3]);
    
    if(aData.oEndsCount > 0)
    {
        
        for(int i = 0; i < aData.oShapesCount; i++)
        {
            if(canVertexArray)
            {
                glEnable(GL_LINE_SMOOTH);
                
                //glEnableClientState(GL_VERTEX_ARRAY);
                glVertexPointer(2, GL_FLOAT, 0, [aData getVertices]);
                glLineWidth(OUTLINE_WIDTH);
                glDrawElements(GL_LINE_LOOP, [aData numOutlineIndices:i], GL_UNSIGNED_INT_OES, [aData getOutlineIndices:i]);
                //glDisableClientState(GL_VERTEX_ARRAY);
                
                glDisable(GL_LINE_SMOOTH);
            }
            else
            {
                // Variables
                GLfloat *vertices = [aData getVertices]; // get existing verts (all of them since there are more shapes in fill than stroke)
                int numIndices = [aData numOutlineIndices:i]; // indexes in outline
                GLfloat *vert = new GLfloat[numIndices * 2]; // create new array to store outline vertices based on fill
                GLint *indices = [aData getOutlineIndices:i]; // get array of indexes
                
                for(int j = 0; j < numIndices; j++)
                {
                    vert[j * 2 + 0] = vertices[indices[j] * 2 + 0]; // x
                    vert[j * 2 + 1] = vertices[indices[j] * 2 + 1]; // y
                }
                
                // Draw outline
                glEnable(GL_LINE_SMOOTH);
                
                glVertexPointer(2, GL_FLOAT, 0, vert);
                //glEnableClientState(GL_VERTEX_ARRAY);
                glLineWidth(OUTLINE_WIDTH);
                glDrawArrays(GL_LINE_LOOP, 0, numIndices);
                
                glDisable(GL_LINE_SMOOTH);
            }
        }
    }
}

- (void) drawDebugBoundsForMinX:(float)minX maxX:(float)maxX minY:(float)minY maxY:(float)maxY
{
    //debug bounding box
    const GLfloat line[] =
    {
        minX, minY, //point A
        minX, maxY, //point B
        maxX, maxY, //point C
        maxX, minY, //point D
    };
    
    glVertexPointer(2, GL_FLOAT, 0, line);
    //glEnableClientState(GL_VERTEX_ARRAY);
    glDrawArrays(GL_LINE_LOOP, 0, 4);
}

- (void) update:(long)dt
{
    [super update:dt];
    
    [self updateColor:dt];
    
    if(sReposition)
        [self reposition];
}

#pragma mark - COLOR

- (void) updateColor:(long)dt
{
    if(clr[0] == clrTarget[0] && clr[1] == clrTarget[1] && clr[2] == clrTarget[2] && clr[3] == clrTarget[3])
		return;
    
    //fade each color element
    float diff;
    float delta;
    float direction;
    
    float newr = clr[0];
    float newg = clr[1];
    float newb = clr[2];
    float newa = clr[3];
    
    //red
    diff = (clrTarget[0] - clr[0]);
    if (diff != 0)
    {        
        delta = clrRedStep * dt;        
        direction = diff < 0 ? -1 : 1;
        
        if (diff*direction < delta)
            newr = clrTarget[0];
        else
            newr += delta*direction;
    }
    
    //green
    diff = (clrTarget[1] - clr[1]);
    if (diff != 0)
    {
        delta = clrGreenStep * dt;
        direction = diff < 0 ? -1 : 1;
        
        if (diff*direction < delta)
            newg = clrTarget[1];
        else
            newg += delta*direction;
    }
    
    //blue
    diff = (clrTarget[2] - clr[2]);
    if (diff != 0)
    {
        delta = clrBlueStep * dt;
        direction = diff < 0 ? -1 : 1;
        
        if (diff*direction < delta)
            newb = clrTarget[2];
        else
            newb += delta*direction;
    }
    
    //alpha
    diff = (clrTarget[3] - clr[3]);
    if (diff != 0)
    {
        delta = clrAlphaStep * dt;
        direction = diff < 0 ? -1 : 1;
        
        if (diff*direction < delta)
            newa = clrTarget[3];
        else
            newa += delta*direction;
    }
    
    clr[0] = newr;
    clr[1] = newg;
    clr[2] = newb;
    clr[3] = newa;
}

//set the color
- (void) setColor:(float*)c
{
    clr[0] = c[0];
    clr[1] = c[1];
    clr[2] = c[2];
    clr[3] = c[3];
    isSetColor = YES;
}

//get color
- (float*) getColor
{
    return clr;
}

- (BOOL) isColorSet
{
    return isSetColor;
}

//set the color to fade to
- (void) fadeTo:(float*)c withSpeed:(float)aSpeed
{
    if(clr[0] == c[0] && clr[1] == c[1] && clr[2] == c[2] && clr[3] == c[3])
		return;
    
    clrRedStep = ((clrTarget[0] - clr[0]) / aSpeed);
    if(clrRedStep < 0) clrRedStep *= -1;
    
    clrGreenStep = ((clrTarget[1] - clr[1]) / aSpeed);
    if(clrGreenStep < 0) clrGreenStep *= -1;
    
    clrBlueStep = ((clrTarget[2] - clr[2]) / aSpeed);
    if(clrBlueStep < 0) clrBlueStep *= -1;
    
    clrAlphaStep = ((clrTarget[3] - clr[3]) / aSpeed);
    if(clrAlphaStep < 0) clrAlphaStep *= -1;
        
    clrTarget[0] = c[0];
    clrTarget[1] = c[1];
    clrTarget[2] = c[2];
    clrTarget[3] = c[3];
}

#pragma mark - BEHAVIOURS

#pragma mark - BEHAVIOURS 1 TOUCH
- (void) scroll:(long)dt
{    
    //scroll
    OKPoint posProp = pos;    
    OKPoint velProp = vel;
        
    posProp = OKPointAdd(posProp, OKPointMake(velProp.x, 0.0, 0.0));
        
    if(velProp.x > GLYPH_SCROLL_MAX_SPEED || velProp.x < -GLYPH_SCROLL_MAX_SPEED)
    {
        vel = OKPointMake(vel.x * GLYPH_SCROLL_FRICTION, 0.0, 0.0);
    }
    
    [self setPos:posProp];
}

- (void) scale:(float)aScale speed:(float)aSpeed friction:(float)aFriction
{
    [self approachScale:aScale speed:aSpeed friction:aFriction];
}

- (void) setDefaultSpeed
{
    //Set velocity
    [self setVel:OKPointMake([parent getDirection] * GLYPH_SCROLL_MIN_SPEED, 0.0, 0.0)];
}

#pragma mark - BEHAVIOURS 2 TOUCH

- (void) drift
{
    csPos = pos;
    isDrifting = YES;
}

- (void) undrift
{
    // do something
    sReposition = YES;
}

- (void) reposition
{
    BOOL isDone = YES;
    
    float dx = pos.x - csPos.x;
    float dy = pos.y - csPos.y;
    float d = sqrt(pow(dx, 2) + pow(dy, 2));
        
    if(d > 10.0f)
    {
        isDone = NO;
        
        dx *= 0.7f;
        dy *= 0.7f;
    }
    
    csPos.x += dx;
    csPos.y += dy;
    
    if(isDone)
    {
        csPos = pos;
        sReposition = NO;
        isDrifting = NO;
    }
}

- (void) lens:(OKPoint)aPos magnification:(float)aMagnification diameter:(float)aDiameter
{    
    OKPoint touchPos = aPos;
    
    //Temp variables
    OKPoint ptPos, ptPosAbs, touchDelta, newDelta;
    float touchDist, dx, dy;
    
    if(dfrmData)
    {
        for(int i = 0; i < dfrmData.shapesCount; i++)
        {
            GLfloat *dfrmVertices = [dfrmData getVertices:i];
            int numVertices = [dfrmData numVertices:i];
            
            for(int j = 0; j < numVertices; j++)
            {
                ptPos.x = dfrmVertices[j * 2 + 0];
                ptPos.y = dfrmVertices[j * 2 + 1];
                ptPosAbs = [self transform:ptPos];
                
                //offset the touch position from this point
                touchDelta = OKPointSub(touchPos, ptPosAbs);
                touchDist = OKPointMag(touchDelta);
                
                float scaleFactor = (aDiameter / 2.0f) - (aDiameter / 2.0f - 1.0) / (touchDist + 1.0);
                
                if(touchDist != 0.0)
                {
                    dx = -touchDelta.x + (aMagnification * -touchDelta.x / touchDist) * scaleFactor;
                    dy = -touchDelta.y + (aMagnification * -touchDelta.y / touchDist) * scaleFactor;
                }
                else
                {
                    dx = -touchDelta.x;
                    dy = -touchDelta.y;
                }
                
                newDelta = OKPointMake(dx + touchDelta.x, dy + touchDelta.y, 0.0);
                ptPos = OKPointAdd(ptPos, OKPointSub(newDelta, OKPointMake(lastDeltas[j*2 + 0], lastDeltas[j*2 + 1], 0.0)));
                
                dfrmVertices[j * 2 + 0] = ptPos.x;
                dfrmVertices[j * 2 + 1] = ptPos.y;
                
                lastDeltas[j*2 + 0] = newDelta.x;
                lastDeltas[j*2 + 1] = newDelta.y;
            }
        }
        
        isDeform = YES;
    }
}

- (void) reform:(float)aSpeed
{
    BOOL isDone = YES;
    
    if(origData)
    {
        float offset[2];
        float mag;
        
        for(int i = 0; i < origData.shapesCount; i++)
        {
            GLfloat *vertices = [origData getVertices:i];
            int numVertices = [origData numVertices:i];
            GLfloat *dfrmVertices = [dfrmData getVertices:i];
            
            //loop through all the vertices of this shape
            for(int j = 0; j < numVertices; j++)
            {
                offset[0] = vertices[j*2 + 0] - dfrmVertices[j*2 + 0];
                offset[1] = vertices[j*2 + 1] - dfrmVertices[j*2 + 1];
                
                mag = sqrtf((offset[0] * offset[0]) + (offset[1] * offset[1]));
                                
                if(mag < 0.1f) continue;
                
                if(mag > 0.8f)
                {
                    isDone = NO;
                    
                    offset[0] *= aSpeed;//0.0175f
                    offset[1] *= aSpeed;//aSpeed;
                }
                
                dfrmVertices[j*2 + 0] += offset[0];
                dfrmVertices[j*2 + 1] += offset[1];
            }
        }
        
        if(isDone)
            isDeform = NO;
    }
}

#pragma mark - PROPERTIES

- (BOOL) isOutside:(CGRect)b { return (CGRectIntersectsRect(b, absBounds) ? NO : YES); }

- (BOOL) isInside:(CGPoint)p { return (CGRectContainsPoint(absBounds, p) ? YES : NO); }

- (BOOL) isScaling { return pSca < sca; }

- (BOOL) isDeforming { return isDeform; }

- (BOOL) isRepositioning { return sReposition; }

- (BOOL) isIdleColor { return clr[0] == FILL_COLOR_IDLE[0] && clr[1] == FILL_COLOR_IDLE[1] && clr[2] == FILL_COLOR_IDLE[2] && clr[3] == FILL_COLOR_IDLE[3]; }

- (BOOL) isIdle { return sca == 1.0f && ![self isDeforming] && ![self isRepositioning] && [self isIdleColor]; }

#pragma mark - SETTERS

- (void) setAfterRightMostGlyph:(TessGlyph*)aR
{    
    float x = (aR.pos.x + [aR.charObj getLocalBoundingBox].size.width/2) + [charObj getLocalBoundingBox].size.width/2;
    [self setPos:OKPointMake(x, pos.y, pos.z)];
}

- (void) setBeforeLeftMostGlyph:(TessGlyph*)aL
{
    float x = (aL.pos.x - [aL.charObj getLocalBoundingBox].size.width/2) - [charObj getLocalBoundingBox].size.width/2;
    [self setPos:OKPointMake(x, pos.y, pos.z)];
}

#pragma mark - GETTERS

- (CGRect) getBounds { return bounds; }

- (CGRect) getAbsoluteBounds { return absBounds; }

- (OKPoint) getAbsoluteCoordinates { return OKPointMake(absBounds.origin.x, absBounds.origin.y, 0.0); }

- (OKPoint) transform:(OKPoint)aPoint
{
    OKPoint ac = [self getAbsoluteCoordinates];
    OKPoint ptSca = aPoint;
    
    return OKPointMake(ac.x + ptSca.x, ac.y + ptSca.y, ac.z + ptSca.z);
}

#pragma mark - POINT CONVERSION

- (CGPoint) convertPoint:(CGPoint)aPoint withZ:(float)z
{
    float ax = ((modelview[0] * aPoint.x) + (modelview[4] * aPoint.y) + (modelview[8] * z) + modelview[12]);
	float ay = ((modelview[1] * aPoint.x) + (modelview[5] * aPoint.y) + (modelview[9] * z) + modelview[13]);
	float az = ((modelview[2] * aPoint.x) + (modelview[6] * aPoint.y) + (modelview[10] * z) + modelview[14]);
	float aw = ((modelview[3] * aPoint.x) + (modelview[7] * aPoint.y) + (modelview[11] * z) + modelview[15]);
	
	float ox = ((projection[0] * ax) + (projection[4] * ay) + (projection[8] * az) + (projection[12] * aw));
	float oy = ((projection[1] * ax) + (projection[5] * ay) + (projection[9] * az) + (projection[13] * aw));
	float ow = ((projection[3] * ax) + (projection[7] * ay) + (projection[11] * az) + (projection[15] * aw));
	
	if(ow != 0)
		ox /= ow;
	
	if(ow != 0)
		oy /= ow;
	
    //VICTOR - PROPER SCREEN BOUNDS
	return CGPointMake(([UIScreen mainScreen].bounds.size.width * (1 + ox) / 2.0f), ([UIScreen mainScreen].bounds.size.height * (1 + oy) / 2.0f));
}

#pragma mark - RANDOM

- (float) floatRandom
{
    return (float)arc4random()/ARC4RANDOM_MAX;
}

- (float) arc4randomf:(float)max :(float)min
{
    return ((max - min) * [self floatRandom]) + min;
}

@end

