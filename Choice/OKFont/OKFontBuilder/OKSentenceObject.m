//
//  OKSentenceObject.m
//  Smooth
//
//  Created by Christian Gratton on 11-06-28.
//  Copyright 2011 Christian Gratton. All rights reserved.
//

#import "OKSentenceObject.h"
#import "OKWordObject.h"
#import "OKCharObject.h"

@implementation OKSentenceObject
@synthesize sentence, glyphObjects;

- (id) initWithSentence:(NSString*)aSentence withTessFont:(OKTessFont*)aTess
{
    self = [self init];
	if (self != nil)
	{
        sentence = [[NSString alloc] initWithString:aSentence];
        tessFont = aTess;
        width = [aTess getWidthForString:sentence];
        height = [aTess getHeightForString:sentence];

        glyphObjects = [[NSMutableArray alloc] init];
        
        //Chars
        NSMutableArray *charObjs = [[NSMutableArray alloc] init];
        
        for(NSString *word in [sentence componentsSeparatedByString:@" "])
        {
            [charObjs addObject:word];
            [charObjs addObject:@" "];
        }
        
        //Positions
        x = 0;
        y = 0;
        
        OKPoint glyphPoint = OKPointMake(0, 0, 0);
        OKCharObject *prevGlyph = nil;
        
        for(NSString *word in charObjs)
        {            
            for(int i = 0; i < [word length]; i++)
            {                
                OKCharObject *glyph = [[OKCharObject alloc] initWithChar:[NSString stringWithFormat:@"%C", [word characterAtIndex:i]] withFont:aTess];
                    
                //Set position
                [glyph setPosition:OKPointMake(glyphPoint.x, glyphPoint.y, 0)];
                
                //Add glyph width to position
                glyphPoint.x += [tessFont getXAdvanceForString:glyph.glyph] - (prevGlyph == nil ? 0 : [tessFont getKerningForLetter:glyph.glyph withPreviousLetter:prevGlyph.glyph]);
                
                //If not last character keep in memory the prev glyph (for kerning)
                if(i < ([word length] - 1))
                    prevGlyph = [glyph retain];
                else
                    prevGlyph = nil;
                
                //Add glyph to array
                [glyphObjects addObject:glyph];
                [glyph release];
            }
        }
        
        [charObjs release];
    }
    return self;
}

#pragma mark setters

- (void) setWidth:(float)aWidth
{
    width = aWidth;
}

- (void) setHeight:(float)aHeight
{
    height = aHeight;
}

- (void) setX:(float)aX
{
    x = aX;
}

- (void) setY:(float)aY
{
    y = aY;
}

- (void) setPosition:(OKPoint)aPos
{
    absPos = [tessFont getPositionAbsolute:aPos withString:sentence];
    
    [self setX:aPos.x];
    [self setY:aPos.y];
}

#pragma mark getters

- (float) getWitdh
{
    return width;
}

- (float) getHeight
{
    return height;
}

- (float) getX
{
    return x;
}

- (float) getY
{
    return y;
}

- (OKPoint) getCenter
{
    return OKPointMake(width/2, height/2, 0);
}

#pragma mark dealloc
- (void)dealloc
{
    [sentence release];
	[super dealloc];
}

@end
