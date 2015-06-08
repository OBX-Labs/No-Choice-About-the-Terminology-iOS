//
//  OKPoEMMProperties.h
//  OKPoEMM
//
//  Created by Christian Gratton on 2013-02-18.
//  Copyright (c) 2013 Christian Gratton. All rights reserved.
//

#import "OKAppProperties.h"

// Properties name constants of static parameters (plist)
// These values can be used throughout different poemm apps, they should not change
extern NSString* const Text; // current package
extern NSString* const Title;
extern NSString* const Default;
extern NSString* const TextFile;
extern NSString* const TextVersion;
extern NSString* const AuthorImage;
extern NSString* const FontFile;
extern NSString* const FontOutlineFile;
extern NSString* const FontTessellationFile;

// This will be unique to each poemm app, you will need to create a unique property for each different value that appears in the plist

// Choice.mm
extern NSString* const BackgroundColor;
extern NSString* const FlickScalar;
extern NSString* const ScaleDelay;
// TessSentence.m
extern NSString* const TessellationAccuracy;
extern NSString* const ScaleSpeed;
extern NSString* const RescaleSpeed;
extern NSString* const ScaleFriction;
extern NSString* const MinimumScale;
extern NSString* const MaximumScale;
extern NSString* const LensMagnification;
extern NSString* const LensDiameter;
extern NSString* const ReformSpeed;
extern NSString* const ReformSpeedForMaximumDeformGlyphs;
extern NSString* const MaximumDeformingGlyphs;
extern NSString* const FillColorIdle;
extern NSString* const FillColorIdleFadeSpeed;
extern NSString* const FillColorFinger1;
extern NSString* const FillColorFinger1FadeSpeed;
extern NSString* const FillColorFinger2;
extern NSString* const FillColorFinger2FadeSpeed;
// TessGlyph.mm
extern NSString* const MinimumScrollSpeed;
extern NSString* const MaximumScrollSpeed;
extern NSString* const ScrollFriction;
extern NSString* const OutlineColor;
extern NSString* const OutlineWidth;
extern NSString* const RenderPadding;

// Property name constant of dynamic paramaters
extern NSString* const Orientation;
extern NSString* const UprightAngle;

@interface OKPoEMMProperties : OKAppProperties

// Get the device orientation
+ (UIDeviceOrientation) orientation;

// Keep track of the device orientation (only the ones supported by the app)
+ (void) setOrientation:(UIDeviceOrientation)aOrientation;

// Get the upright angle which is recomputed when the orientation is set
+ (int) uprightAngle;

+ (void) initWithContentsOfFile:(NSString *)aPath;

+ (id) objectForKey:(id)aKey;

+ (void) setObject:(id)aObject forKey:(id)aKey;

// Fills the properties with a loaded package dictionary (Properties-iPhone, Properties-iPhone-Retina, Properties-iPhone-568h, Properties-iPad, Properties-iPad-Retina)
+ (void) fillWith:(NSDictionary*)aTextDict;

+ (void) listProperties;

@end
