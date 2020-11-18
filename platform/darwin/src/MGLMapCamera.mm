#import "MGLMapCamera.h"
#import "MGLGeometry_Private.h"
#import "MGLLoggingConfiguration_Private.h"

#import <CoreLocation/CoreLocation.h>

#include <mbgl/math/wrap.hpp>

BOOL MGLEqualFloatWithAccuracy(CGFloat left, CGFloat right, CGFloat accuracy)
{
    return MAX(left, right) - MIN(left, right) <= accuracy;
}

@implementation MGLMapCamera

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)camera
{
    return [[self alloc] init];
}

+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                              fromEyeCoordinate:(CLLocationCoordinate2D)eyeCoordinate
                                    eyeAltitude:(CLLocationDistance)eyeAltitude
{
    CLLocationDirection heading = -1;
    CGFloat pitch = -1;
    if (CLLocationCoordinate2DIsValid(centerCoordinate) && CLLocationCoordinate2DIsValid(eyeCoordinate)) {
        heading = MGLDirectionBetweenCoordinates(eyeCoordinate, centerCoordinate);
        
        CLLocation *centerLocation = [[CLLocation alloc] initWithLatitude:centerCoordinate.latitude
                                                                longitude:centerCoordinate.longitude];
        CLLocation *eyeLocation = [[CLLocation alloc] initWithLatitude:eyeCoordinate.latitude
                                                             longitude:eyeCoordinate.longitude];
        CLLocationDistance groundDistance = [eyeLocation distanceFromLocation:centerLocation];
        CGFloat radianPitch = atan2(eyeAltitude, groundDistance);
        pitch = mbgl::util::wrap(90 - MGLDegreesFromRadians(radianPitch), 0.0, 360.0);
    }

    return [[self alloc] initWithCenterCoordinate:centerCoordinate
                                         altitude:eyeAltitude
                                            pitch:pitch
                                           heading:heading
                                           padding:MGLEdgeInsetsZero];
}

+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                 acrossDistance:(CLLocationDistance)distance
                                          pitch:(CGFloat)pitch
                                        heading:(CLLocationDirection)heading
{
    // Angle at the viewpoint formed by the straight lines running perpendicular
    // to the ground and toward the center coordinate.
    CLLocationDirection eyeAngle = 90 - pitch;
    CLLocationDistance altitude = distance * sin(MGLRadiansFromDegrees(eyeAngle));
    
    return [[self alloc] initWithCenterCoordinate:centerCoordinate
                                         altitude:altitude
                                            pitch:pitch
                                          heading:heading];
}

+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                       altitude:(CLLocationDistance)altitude
                                          pitch:(CGFloat)pitch
                                        heading:(CLLocationDirection)heading
{
    return [[self alloc] initWithCenterCoordinate:centerCoordinate
                                         altitude:altitude
                                            pitch:pitch
                                           heading:heading
                                           padding:MGLEdgeInsetsZero];
}

+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                        altitude:(CLLocationDistance)altitude
                                           pitch:(CGFloat)pitch
                                         heading:(CLLocationDirection)heading
                                         padding:(MGLEdgeInsets)padding
{
    return [[self alloc] initWithCenterCoordinate:centerCoordinate
                                          altitude:altitude
                                             pitch:pitch
                                           heading:heading
                                           padding:padding];
}

- (instancetype)initWithCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                altitude:(CLLocationDistance)altitude
                                   pitch:(CGFloat)pitch
                                 heading:(CLLocationDirection)heading
                                     padding:(MGLEdgeInsets)padding
{
    MGLLogDebug(@"Initializing withCenterCoordinate: %@ altitude: %.0fm pitch: %f° heading: %f° padding:%@ padding; %f, %f, %f, %f", MGLStringFromCLLocationCoordinate2D(centerCoordinate), altitude, pitch, heading, padding.top, padding.left, padding.bottom, padding.right);
    if (self = [super init])
    {
        _centerCoordinate = centerCoordinate;
        _altitude = altitude;
        _pitch = pitch;
        _heading = heading;
        _padding = padding;
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    MGLLogInfo(@"Initialiazing with coder.");
    if (self = [super init])
    {
        _centerCoordinate = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"centerLatitude"],
                                                       [coder decodeDoubleForKey:@"centerLongitude"]);
        _altitude = [coder decodeDoubleForKey:@"altitude"];
        _pitch = [coder decodeDoubleForKey:@"pitch"];
        _heading = [coder decodeDoubleForKey:@"heading"];
        _padding.left = [coder decodeDoubleForKey:@"paddingLeft"];
        _padding.right = [coder decodeDoubleForKey:@"paddingRight"];
        _padding.top = [coder decodeDoubleForKey:@"paddingTop"];
        _padding.bottom = [coder decodeDoubleForKey:@"paddingBottom"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_centerCoordinate.latitude forKey:@"centerLatitude"];
    [coder encodeDouble:_centerCoordinate.longitude forKey:@"centerLongitude"];
    [coder encodeDouble:_altitude forKey:@"altitude"];
    [coder encodeDouble:_pitch forKey:@"pitch"];
    [coder encodeDouble:_heading forKey:@"heading"];
    [coder encodeDouble:_padding.left forKey:@"paddingLeft"];
    [coder encodeDouble:_padding.right forKey:@"paddingRight"];
    [coder encodeDouble:_padding.top forKey:@"paddingTop"];
    [coder encodeDouble:_padding.bottom forKey:@"paddingBottom"];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithCenterCoordinate:_centerCoordinate
                                                              altitude:_altitude
                                                                 pitch:_pitch
                                                               heading:_heading
                                                                padding:_padding];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingViewingDistance {
    return [NSSet setWithObjects:@"altitude", @"pitch", nil];
}

- (CLLocationDistance)viewingDistance {
    CLLocationDirection eyeAngle = 90 - self.pitch;
    return self.altitude / sin(MGLRadiansFromDegrees(eyeAngle));
}

- (void)setViewingDistance:(CLLocationDistance)distance {
    MGLLogDebug(@"Setting viewingDistance: %f", distance);
    CLLocationDirection eyeAngle = 90 - self.pitch;
    self.altitude = distance * sin(MGLRadiansFromDegrees(eyeAngle));
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; centerCoordinate = %f, %f; altitude = %.0fm; heading = %.0f°; pitch = %.0f° ; padding = %f, %f, %f, %f>",
             NSStringFromClass([self class]), (void *)self, _centerCoordinate.latitude, _centerCoordinate.longitude, _altitude, _heading, _pitch, _padding.top, _padding.left, _padding.bottom, _padding.right];
}

- (BOOL)isEqual:(id)other
{
    if ( ! [other isKindOfClass:[self class]])
    {
        return NO;
    }
    if (other == self)
    {
        return YES;
    }

    MGLMapCamera *otherCamera = other;
    return (_centerCoordinate.latitude == otherCamera.centerCoordinate.latitude
            && _centerCoordinate.longitude == otherCamera.centerCoordinate.longitude
            && _altitude == otherCamera.altitude
            && _pitch == otherCamera.pitch && _heading == otherCamera.heading
             && MGLEdgeInsetsEqual(_padding, otherCamera.padding));
}

- (BOOL)isEqualToMapCamera:(MGLMapCamera *)otherCamera
{
    if (otherCamera == self)
    {
        return YES;
    }
    
    return (MGLEqualFloatWithAccuracy(_centerCoordinate.latitude, otherCamera.centerCoordinate.latitude, 1e-6)
            && MGLEqualFloatWithAccuracy(_centerCoordinate.longitude, otherCamera.centerCoordinate.longitude, 1e-6)
            && MGLEqualFloatWithAccuracy(_altitude, otherCamera.altitude, 1e-6)
            && MGLEqualFloatWithAccuracy(_pitch, otherCamera.pitch, 1)
            && MGLEqualFloatWithAccuracy(_heading, otherCamera.heading, 1))
             && MGLEqualFloatWithAccuracy(_padding.left, otherCamera.padding.left, 1e-6)
             && MGLEqualFloatWithAccuracy(_padding.right, otherCamera.padding.right, 1e-6)
             && MGLEqualFloatWithAccuracy(_padding.top, otherCamera.padding.top, 1e-6)
             && MGLEqualFloatWithAccuracy(_padding.bottom, otherCamera.padding.bottom, 1e-6);
}

- (NSUInteger)hash
{
    return (@(_centerCoordinate.latitude).hash + @(_centerCoordinate.longitude).hash
            + @(_altitude).hash + @(_pitch).hash + @(_heading).hash + @(_padding.left).hash
             + @(_padding.right).hash + @(_padding.top).hash + @(_padding.bottom).hash);
}

@end
