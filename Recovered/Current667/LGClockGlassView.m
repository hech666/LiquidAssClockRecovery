// LiquidAss 6.6.7 arm64e — manual source recovery, not original source.
#import "LGClockGlassView.h"
#import <dispatch/dispatch.h>
#import <mach/mach_time.h>
#include <fcntl.h>
#include <math.h>
#include <stddef.h>
#include <stdatomic.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

// Declarations for current shared classes, reconstructed from call sites.
#import "LGClockSharedViews.h"

@interface LGLiveBackdropView (LGClock667Calls)
@property (nonatomic, copy) NSNumber *lgNativeBlurRadiusOverride;
@end

extern BOOL LGDebugLoggingEnabled(void);
extern void *LGClockEditorFieldMap(int create);
extern void *LGClockPosterFieldMap(int create, unsigned index);

// Shared file ABI. Field names (particularly consumed) are semantic labels.
struct LGClockField {
    uint32_t magic, version;          // 0x00, 0x04
    _Atomic uint64_t sequence;        // 0x08 (odd while writing)
    _Atomic uint64_t owner;           // 0x10
    _Atomic uint64_t generation;      // 0x18
    _Atomic uint64_t consumed;        // 0x20
    uint32_t width, height;           // 0x28, 0x2c
    float pointWidth, pointHeight;    // 0x30, 0x34
    _Atomic uint32_t orientation;     // 0x38
};
_Static_assert(offsetof(struct LGClockField, owner) == 0x10, "clock field owner ABI");
_Static_assert(offsetof(struct LGClockField, consumed) == 0x20, "clock field consumer ABI");
_Static_assert(offsetof(struct LGClockField, orientation) == 0x38, "clock field orientation ABI");
_Static_assert(sizeof(struct LGClockField) == 0x40, "clock field payload offset");

typedef struct LGClockField LGClockField;
enum { LGFieldMagic = 0x4c474446, LGFieldVersion = 2,
       LGFieldPayloadSize = 0x400000, LGFieldMapSize = 0x400040 };
static BOOL LGPosterSlots[16];

static dispatch_queue_t LGFieldQueue(void) { // 0x87e24, initializer 0x8bd3c
    static dispatch_once_t once;
    static dispatch_queue_t queue;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("dylv.liquidglass.clock-field", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

static uint64_t LGEditorProducer(void) { // block 0x87e04
    static dispatch_once_t once;
    static uint64_t producer;
    dispatch_once(&once, ^{ producer = mach_absolute_time(); });
    return producer;
}

static LGClockField *LGSpringBoardMap(void) { // inlined in 0x87580
    static LGClockField *map;
    if (map) return map;
    int fd = open("/var/mobile/Library/Accessibility/liquidglass-clock-field.bin",
                  O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (fd < 0) return NULL;
    struct stat st;
    if (fstat(fd, &st) == 0 && S_ISREG(st.st_mode) && st.st_uid == getuid() &&
        ftruncate(fd, LGFieldMapSize) == 0 && fcntl(fd, F_SETPROTECTIONCLASS, 4) >= 0) {
        void *p = mmap(NULL, LGFieldMapSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (p != MAP_FAILED) map = p;
    }
    close(fd);
    return map;
}

static uint64_t LGFieldBeginWrite(LGClockField *map) {
    uint64_t odd = (atomic_load_explicit(&map->sequence, memory_order_relaxed) + 1) | 1;
    atomic_store_explicit(&map->sequence, odd, memory_order_release);
    return odd;
}

static void LGFieldEndWrite(LGClockField *map, uint64_t odd) {
    atomic_store_explicit(&map->sequence, odd + 1, memory_order_release);
}

static void LGFieldClaim(LGClockField *map, uint64_t producer, BOOL initialize) {
    uint64_t odd = LGFieldBeginWrite(map);
    if (initialize) {
        map->magic = LGFieldMagic;
        map->version = LGFieldVersion;
        atomic_store_explicit(&map->orientation, 1, memory_order_release);
    }
    atomic_store_explicit(&map->owner, producer, memory_order_relaxed);
    atomic_store_explicit(&map->generation, 0, memory_order_relaxed);
    atomic_store_explicit(&map->consumed, 0, memory_order_release);
    LGFieldEndWrite(map, odd);
}

static CGFloat LGClockNumber(NSString *key, CGFloat fallback, CGFloat max) {
    id number = LGGlassPreferenceValue(key);
    CGFloat value = [number respondsToSelector:@selector(doubleValue)] ? [number doubleValue] : fallback;
    return isfinite(value) ? fmin(max, fmax(0, value)) : fallback;
}

static CGFloat LGClockScreenScale(UIView *view) {
    CGFloat scale = view.window.screen.scale;
    return scale != 0 ? scale : UIScreen.mainScreen.scale;
}

// a3ba4/a3cd4/a3c54: alpha-only bitmap with top-left point coordinates.
static CGContextRef LGClockAlphaContext(void *data, size_t width, size_t height, CGFloat scale) {
    if (!width || !height) return NULL;
    CGContextRef ctx = CGBitmapContextCreate(data, width, height, 8, width, NULL, kCGImageAlphaOnly);
    if (ctx) {
        CGContextTranslateCTM(ctx, 0, height);
        CGContextScaleCTM(ctx, scale, -scale);
    }
    return ctx;
}

// 0x89ab4: directional edge highlights from a Sobel-like gradient of the
// glyph fill, restricted to the inner stroke. Source names are reconstructed.
static CGImageRef LGClockSpecularImage(CGPathRef path, CGSize size, CGFloat bezel, CGFloat screenScale) {
    if (!path || !(size.width > 0 && size.height > 0)) return NULL;
    CGFloat scale = fmax(2, screenScale);
    CGFloat dw = size.width * scale, dh = size.height * scale;
    if (!(dw >= 1 && dw < 6145 && dh >= 1 && dh < 6145)) return NULL;
    int w = (int)dw, h = (int)dh, step = (int)scale;
    CGRect bounds = CGPathGetBoundingBox(path);
    if (CGRectIsEmpty(bounds)) return NULL;
    int pad = (int)fmaxf(4, (float)(scale * bezel * .25));
    int x0 = MAX(step, (int)floor(CGRectGetMinX(bounds) * scale) - pad);
    int y0 = MAX(step, (int)floor(CGRectGetMinY(bounds) * scale) - pad);
    int x1 = MIN(w - step - 1, (int)ceil(CGRectGetMaxX(bounds) * scale) + pad);
    int y1 = MIN(h - step - 1, (int)ceil(CGRectGetMaxY(bounds) * scale) + pad);

    size_t n = (size_t)w * h;
    NSMutableData *fill = [NSMutableData dataWithLength:n];
    NSMutableData *edge = [NSMutableData dataWithLength:n];
    NSMutableData *rgba = [NSMutableData dataWithLength:n * 4];
    CGContextRef context = LGClockAlphaContext(fill.mutableBytes, w, h, scale);
    if (!context) return NULL;
    CGContextSetAllowsAntialiasing(context, true);
    CGContextSetShouldAntialias(context, true);
    CGContextSetGrayFillColor(context, 1, 1);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    CGContextRelease(context);

    context = LGClockAlphaContext(edge.mutableBytes, w, h, scale);
    if (!context) return NULL;
    CGContextAddPath(context, path);
    CGContextClip(context);
    CGContextAddPath(context, path);
    CGContextSetLineWidth(context, 2);
    CGContextSetGrayStrokeColor(context, 1, 1);
    CGContextStrokePath(context);
    CGContextRelease(context);

    const uint8_t *a = fill.bytes, *clip = edge.bytes;
    uint32_t *px = rgba.mutableBytes;
    float strength = bezel <= 0 ? 1.35f : (float)((bezel / 12) * 1.35);
    for (int y = y0; y <= y1; ++y) {
        for (int x = x0; x <= x1; ++x) {
            int i = y * w + x;
            if (!clip[i]) continue;
            int t = i - w * step, b = i + w * step;
            int tr = a[t + step], tl = a[t - step], br = a[b + step], bl = a[b - step];
            int dx = tr + 2 * a[i + step] + br - tl - 2 * a[i - step] - bl;
            int dy = bl + 2 * a[b] + br - tl - 2 * a[t] - tr;
            if (!dx && !dy) continue;
            float weighted = (dx + dy) * strength;
            int light = (weighted > 0 ? (int)(weighted * 195) : -(int)(weighted * 55)) >> 10;
            if (light > 0) px[i] = MIN(255, (light * clip[i]) >> 8) * 0x01010101u;
        }
    }
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate(rgba.mutableBytes, w, h, 8, (size_t)w * 4, rgb,
                                    kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgb);
    CGImageRef image = context ? CGBitmapContextCreateImage(context) : NULL;
    if (context) CGContextRelease(context);
    // Keep the external bitmap buffers alive through Core Graphics calls under ARC.
    (void)rgba.length;
    return image;
}

// 0x8bd80 (direct callee): two in-place chamfer sweeps, skipping seeds <= 1.
static void LGClockDistancePass(float *distance, uint32_t w, uint32_t h) {
    const float diagonal = 1.4142135381698608f;
    for (uint32_t y = 0; y < h; ++y) {
        for (uint32_t x = 0; x < w; ++x) {
            size_t i = (size_t)y * w + x;
            float v = distance[i];
            if (v <= 1) continue;
            if (x) v = fminf(v, distance[i - 1] + 1);
            if (y) {
                v = fminf(v, distance[i - w] + 1);
                if (x) v = fminf(v, distance[i - w - 1] + diagonal);
                if (x + 1 < w) v = fminf(v, distance[i - w + 1] + diagonal);
            }
            distance[i] = v;
        }
    }
    for (uint32_t y = h; y-- > 0;) {
        for (uint32_t x = w; x-- > 0;) {
            size_t i = (size_t)y * w + x;
            float v = distance[i];
            if (v <= 1) continue;
            if (x + 1 < w) v = fminf(v, distance[i + 1] + 1);
            if (y + 1 < h) {
                v = fminf(v, distance[i + w] + 1);
                if (x) v = fminf(v, distance[i + w - 1] + diagonal);
                if (x + 1 < w) v = fminf(v, distance[i + w + 1] + diagonal);
            }
            distance[i] = v;
        }
    }
}

// 0x8b330: signed distance in point units; negative inside the glyph.
static NSData *LGClockRasterField(CGPathRef path, CGSize size, uint32_t *outW, uint32_t *outH) {
    if (!path || !(size.width > 0 && size.width <= 2048 && size.height > 0 && size.height <= 2048))
        return nil;
    CGFloat scale = fmin(1, 1024 / fmax(size.width, size.height));
    uint32_t w = (uint32_t)(size.width * scale), h = (uint32_t)(size.height * scale);
    if (!w || !h) return nil;
    size_t n = (size_t)w * h;
    NSMutableData *raster = [NSMutableData dataWithLength:n];
    CGContextRef context = LGClockAlphaContext(raster.mutableBytes, w, h, scale);
    if (!context) return nil;
    CGContextSetGrayFillColor(context, 1, 1);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    CGContextRelease(context);

    NSMutableData *result = [NSMutableData dataWithLength:n * sizeof(float)];
    NSMutableData *other = [NSMutableData dataWithLength:n * sizeof(float)];
    const uint8_t *alpha = raster.bytes;
    float *a = result.mutableBytes, *b = other.mutableBytes;
    for (size_t i = 0; i < n; ++i) {
        float fraction = (float)alpha[i] / 255.0f;
        a[i] = alpha[i] == 255 ? 1e12f : fmaxf(0, fraction - .5f);
        b[i] = alpha[i] == 0 ? 1e12f : fmaxf(0, .5f - fraction);
    }
    LGClockDistancePass(a, w, h);
    LGClockDistancePass(b, w, h);
    for (size_t i = 0; i < n; ++i) a[i] = (float)((b[i] - a[i]) / scale);
    *outW = w;
    *outH = h;
    (void)other.length;
    (void)raster.length;
    return result;
}

@implementation LGClockRefractionView
+ (Class)layerClass { // 0x87540
    return NSClassFromString(@"CABackdropLayer") ?: CALayer.class;
}
@end

@implementation LGClockGlassView

- (instancetype)initWithFrame:(CGRect)frame { // 0x87580
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;

    _material = [[UIView alloc] initWithFrame:self.bounds];
    _glyphMask = [CAShapeLayer layer];
    _material.layer.mask = _glyphMask;
    [self addSubview:_material];

    _blur = [[LGBlurView alloc] initWithFrame:self.bounds blurRadius:6];
    _blur.followsSurfaceLiquidity = YES;
    [_blur.layer setValue:@1.0 forKey:@"scale"];
    [_material addSubview:_blur];

    _vibrance = [[LGVibranceView alloc] initWithFrame:self.bounds saturation:1.95 contrast:1.06];
    _vibrance.brightness = .12;
    _vibrance.layer.cornerRadius = 0;
    [_material addSubview:_vibrance];

    NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
    _editor = ![bundle isEqualToString:@"com.apple.springboard"];
    BOOL poster = [bundle isEqualToString:@"com.apple.PosterBoard"];
    _posterSlot = -1;
    if (poster) {
        for (NSInteger i = 0; i < 16; ++i) {
            if (LGPosterSlots[i]) continue;
            LGPosterSlots[i] = YES;
            _posterSlot = i;
            break;
        }
    }
    NSString *filter = _editor ? @"dylv.liquidglass.clockeditor" : @"dylv.liquidglass.clock";
    if (_posterSlot >= 0) filter = [filter stringByAppendingFormat:@".poster%ld", (long)_posterSlot];
    _glass = [[LGClockRefractionView alloc] initWithFrame:self.bounds groupName:nil filterType:filter];
    _glass.lgNativeBlurRadiusOverride = @0;
    _glass.lgSpecularEnabledOverride = @NO;
    [_material addSubview:_glass];

    _colorTint = [[UIView alloc] initWithFrame:self.bounds];
    _colorTint.userInteractionEnabled = NO;
    [_material addSubview:_colorTint];
    [self refreshAppearance];

    _clockSpecular = [CAShapeLayer layer];
    _clockSpecular.fillColor = UIColor.clearColor.CGColor;
    _clockSpecular.strokeColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    _clockSpecular.lineWidth = 1;
    _clockSpecular.contentsGravity = kCAGravityResize;
    _clockSpecular.contentsScale = UIScreen.mainScreen.scale;
    _clockSpecular.opacity = 1;
    _clockSpecular.shadowColor = UIColor.whiteColor.CGColor;
    _clockSpecular.shadowOpacity = .55f;
    _clockSpecular.shadowRadius = 7.5;
    _clockSpecular.shadowOffset = CGSizeZero;
    _specularVibrance = [[LGVibranceView alloc] initWithFrame:self.bounds saturation:1.1 contrast:1];
    _specularVibrance.brightness = .24;
    _specularVibrance.clipsToBounds = NO;
    _specularVibrance.layer.cornerRadius = 0;
    _specularVibrance.layer.mask = _clockSpecular;
    [self addSubview:_specularVibrance];

    _mapping = _editor ? LGClockEditorFieldMap(1) : LGSpringBoardMap();
    if (poster) _mapping = _posterSlot >= 0 ? LGClockPosterFieldMap(1, (unsigned)_posterSlot) : NULL;
    _producer = mach_absolute_time();
    if (_editor && _posterSlot < 0) _producer = LGEditorProducer();
    if (_mapping) {
        LGClockField *map = _mapping;
        uint64_t producer = _producer;
        dispatch_sync(LGFieldQueue(), ^{ // 0x87e68
            if (atomic_load_explicit(&map->owner, memory_order_acquire) != producer)
                LGFieldClaim(map, producer, YES);
        });
    }
    return self;
}

- (void)ensureFieldOwnership { // 0x87ed4
    [self updateFieldOrientation];
    if (!_editor || _invalidated || !_mapping || !_glyphMask.path ||
        atomic_load_explicit(&_mapping->owner, memory_order_acquire) == _producer) return;
    LGClockField *map = _mapping;
    uint64_t producer = _producer;
    dispatch_sync(LGFieldQueue(), ^{ LGFieldClaim(map, producer, NO); }); // 0x8805c
    _firstGeneration = 0;
    [self updateFieldOrientation];
    if (_pendingPath) CGPathRelease(_pendingPath);
    _pendingPath = CGPathCreateCopy(_glyphMask.path);
    _pendingSize = _glyphMask.bounds.size;
    _pendingDeferred = NO;
    ++_fieldEpoch;
    [self publishPendingField];
}

- (void)layoutSubviews { // 0x88cd0
    [super layoutSubviews];
    [self updateFieldOrientation];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _material.frame = self.bounds;
    _colorTint.frame = self.bounds;
    _glyphMask.frame = self.bounds;
    _blur.frame = self.bounds;
    _glass.frame = self.bounds;
    _vibrance.frame = self.bounds;
    _clockSpecular.frame = self.bounds;
    _specularVibrance.frame = self.bounds;
    [CATransaction commit];
    [self logClockGeometry:@"layout"];
}

- (void)updateFieldOrientation { // 0x88e0c (assembly; PDG drops most of this method)
    if (!_mapping || _invalidated || !self.window ||
        atomic_load_explicit(&_mapping->owner, memory_order_acquire) != _producer) return;
    id<UICoordinateSpace> fixed = self.window.screen.fixedCoordinateSpace;
    CGRect bounds = self.bounds;
    CGPoint a = [self convertPoint:bounds.origin toCoordinateSpace:fixed];
    CGPoint b = [self convertPoint:CGPointMake(CGRectGetMaxX(bounds), CGRectGetMinY(bounds))
                 toCoordinateSpace:fixed];
    CGFloat dx = b.x - a.x, dy = b.y - a.y;
    uint32_t orientation = fabs(dx) < fabs(dy) ? (dy > 0 ? 3 : 4) : (dx < 0 ? 2 : 1);
    if (atomic_exchange_explicit(&_mapping->orientation, orientation, memory_order_acq_rel) != orientation)
        [_glass lgInvalidateFilterContents];
}

- (void)setClockColor:(UIColor *)color { // 0x88fbc
    if ([_clockColor isEqual:color]) return;
    _clockColor = color;
    CGFloat hue = 0, saturation = 0, brightness = 0, alpha = 1;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    CGFloat capped = saturation > 1 ? 1 : saturation;
    CGFloat overlayAlpha = alpha * fma(sqrt(fmax(0, capped)), .62, .15);
    _colorTint.backgroundColor = [color colorWithAlphaComponent:overlayAlpha];
    LGLog(@"[ClockColor] glass view=%p input=%@ alpha=%.3f saturation=%.3f overlay=%@",
          self, color, alpha, saturation, _colorTint.backgroundColor);
}

- (UIColor *)clockColor { return _clockColor; } // 0x8bc24

- (void)refreshAppearance { // 0x890fc
    _blur.blurRadius = LGClockNumber(@"Clock.Blur", 6, 50);
    _blur.hidden = _blur.blurRadius <= 0;
    [_blur applyFilters];
    [_glass applyFilters];
}

- (BOOL)fieldReady { // 0x891e4
    return _mapping && _firstGeneration &&
        atomic_load_explicit(&_mapping->owner, memory_order_acquire) == _producer &&
        atomic_load_explicit(&_mapping->consumed, memory_order_acquire) >= _firstGeneration &&
        [_glass lgFilterAttached];
}

- (void)invalidateField { // 0x89250
    if (_invalidated) return;
    _invalidated = YES;
    self.hidden = YES;
    if (!_editor && _mapping) {
        LGClockField *map = _mapping;
        uint64_t producer = _producer;
        dispatch_async(LGFieldQueue(), ^{ // 0x89338
            if (atomic_load_explicit(&map->owner, memory_order_acquire) != producer) return;
            uint64_t odd = LGFieldBeginWrite(map);
            atomic_store_explicit(&map->generation, 0, memory_order_relaxed);
            LGFieldEndWrite(map, odd);
        });
    }
}

- (void)dealloc { // 0x89374; ARC handles 0x8bc34
    if (_posterSlot >= 0) LGPosterSlots[_posterSlot] = NO;
    if (_pendingPath) CGPathRelease(_pendingPath);
}

- (void)setGlyphPath:(CGPathRef)path canvasSize:(CGSize)size deferRendering:(BOOL)deferRendering { // 0x893e8
    ++_digitTransition;
    if (deferRendering && _glyphMask.sublayers.count == 0 && _mapping && path && !_invalidated) {
        if (_pendingPath) CGPathRelease(_pendingPath);
        _pendingPath = CGPathCreateCopy(path);
        _pendingSize = size;
        _pendingDeferred = YES;
        [self publishPendingField];
        return;
    }

    ++_fieldEpoch;
    [_glyphMask.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [_clockSpecular.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    CGFloat scale = LGClockScreenScale(self);
    CGImageRef specular = LGClockSpecularImage(path, size, LGClockNumber(@"Clock.BezelWidth", 9, 100), scale);
    CGRect frame = (CGRect){CGPointZero, size};
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _vibrance.frame = frame;
    _material.frame = frame;
    _colorTint.frame = frame;
    _glyphMask.frame = frame;
    _glyphMask.path = path;
    if (!_blur.hidden) [_blur.layer setValue:NSUUID.UUID.UUIDString forKey:@"groupName"];
    _blur.frame = frame;
    _glass.frame = frame;
    _clockSpecular.frame = frame;
    _specularVibrance.frame = frame;
    _clockSpecular.contents = (__bridge id)specular;
    _clockSpecular.path = specular ? NULL : path;
    [CATransaction commit];
    [self logClockGeometry:@"glyph-update"];
    if (_geometryTraceCount < 4) {
        __weak LGClockGlassView *weakSelf = self;
        for (NSNumber *delay in @[@.1, @.5, @1.5]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [weakSelf logClockGeometry:@"settled"]; }); // 0x8a048
        }
    }
    if (specular) CGImageRelease(specular);
    if (_invalidated || !path || !_mapping) return;
    if (_pendingPath) CGPathRelease(_pendingPath);
    _pendingPath = CGPathCreateCopy(path);
    _pendingSize = size;
    _pendingDeferred = NO;
    [self publishPendingField];
}

- (void)publishPendingField { // 0x8ad54
    if (_busy || !_pendingPath || _invalidated) return;
    _busy = YES;
    CGPathRef path = _pendingPath;
    _pendingPath = NULL;
    CGSize size = _pendingSize;
    BOOL deferred = _pendingDeferred;
    uint64_t epoch = _fieldEpoch;
    CGFloat scale = LGClockScreenScale(self);
    CGFloat bezel = LGClockNumber(@"Clock.BezelWidth", 9, 100);
    LGClockField *map = _mapping;
    uint64_t producer = _producer;
    __weak LGClockGlassView *weakSelf = self;
    dispatch_async(LGFieldQueue(), ^{ // 0x8afa4
        @autoreleasepool {
            CFTimeInterval start = CACurrentMediaTime();
            __block NSData *payload;
            __block uint32_t w = 0, h = 0;
            __block CGImageRef image = NULL;
            if (deferred) {
                dispatch_apply(2, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) { // 0x8b288
                    @autoreleasepool {
                        if (i == 0) payload = LGClockRasterField(path, size, &w, &h);
                        else image = LGClockSpecularImage(path, size, bezel, scale);
                    }
                });
            } else {
                payload = LGClockRasterField(path, size, &w, &h);
            }
            CFTimeInterval cost = CACurrentMediaTime() - start;
            dispatch_async(dispatch_get_main_queue(), ^{ // 0x8b6e0
                LGClockGlassView *view = weakSelf;
                if (view && !view->_invalidated) {
                    view->_busy = NO;
                    if (epoch == view->_fieldEpoch && payload.length && payload.length <= LGFieldPayloadSize &&
                        atomic_load_explicit(&map->owner, memory_order_acquire) == producer) {
                        uint64_t generation = mach_absolute_time();
                        uint64_t odd = LGFieldBeginWrite(map);
                        memcpy((uint8_t *)map + sizeof(*map), payload.bytes, payload.length);
                        map->width = w;
                        map->height = h;
                        map->pointWidth = (float)size.width;
                        map->pointHeight = (float)size.height;
                        atomic_store_explicit(&map->generation, generation, memory_order_relaxed);
                        LGFieldEndWrite(map, odd);
                        if (!view->_firstGeneration) view->_firstGeneration = generation;

                        [CATransaction begin];
                        [CATransaction setDisableActions:YES];
                        if (deferred) {
                            CGRect frame = (CGRect){CGPointZero, size};
                            view->_material.frame = frame;
                            view->_colorTint.frame = frame;
                            view->_glyphMask.frame = frame;
                            view->_blur.frame = frame;
                            view->_vibrance.frame = frame;
                            view->_glass.frame = frame;
                            view->_clockSpecular.frame = frame;
                            view->_specularVibrance.frame = frame;
                            view->_glyphMask.path = path;
                            view->_clockSpecular.contents = (__bridge id)image;
                            view->_clockSpecular.path = image ? NULL : path;
                            if (!view->_blur.hidden)
                                [view->_blur.layer setValue:NSUUID.UUID.UUIDString forKey:@"groupName"];
                        }
                        [view->_glass lgInvalidateFilterContents];
                        [CATransaction commit];
                        if (view->_posterSlot >= 0 && view->_publishedCount < 10)
                            [view logClockGeometry:@"poster-field-published"];
                        if (view->_publishedCount++ < 3)
                            LGLog(@"[ClockField] generation=%llu size=%ux%u cost=%.2fms deferred=%d",
                                  (unsigned long long)generation, w, h, cost * 1000, deferred);
                    }
                    [view publishPendingField];
                }
                if (image) CGImageRelease(image);
                CGPathRelease(path);
            });
        }
    });
}

// Constant arrays in __objc_arrayobj at 0xdf078..0xdf0d8. Old glyphs withdraw
// quickly; new glyphs reveal on the longer curve, both from 1.5 to 0.
static void LGClockInstallDigitWipe(CALayer *layer, CGPathRef path, BOOL incoming, CFTimeInterval begin) {
    static const double enterT[] = {0,.06611,.10043,.20029,.36625,.53374,.69897,.86647,1.03332,1.19865,1.36632,1.53336,1.566};
    static const double enterY[] = {1.5,1.5,1.2717433,.8919396,.5674996,.3677359,.2317529,.1371188,.0723925,.0307417,.007669,.0000229,0};
    static const double exitT[] = {0,.02421,.03389,.06611,.10043,.13361};
    static const double exitY[] = {1.5,1.5,1.4990845,1.414155,1.1030216,0};
    const double *times = incoming ? enterT : exitT;
    const double *values = incoming ? enterY : exitY;
    NSUInteger n = incoming ? sizeof(enterT)/sizeof(*enterT) : sizeof(exitT)/sizeof(*exitT);
    double duration = times[n - 1];
    NSMutableArray *keyTimes = [NSMutableArray arrayWithCapacity:n];
    NSMutableArray *starts = [NSMutableArray arrayWithCapacity:n];
    NSMutableArray *ends = [NSMutableArray arrayWithCapacity:n];
    for (NSUInteger i = 0; i < n; ++i) {
        [keyTimes addObject:@(times[i] / duration)];
        [starts addObject:[NSValue valueWithCGPoint:CGPointMake(0, values[i])]];
        [ends addObject:[NSValue valueWithCGPoint:CGPointMake(0, values[i] - .5)]];
    }
    CAGradientLayer *mask = [CAGradientLayer layer];
    mask.frame = CGPathGetPathBoundingBox(path);
    mask.startPoint = CGPointZero;
    mask.endPoint = CGPointMake(0, -.5);
    id white = (__bridge id)UIColor.whiteColor.CGColor;
    id clear = (__bridge id)UIColor.clearColor.CGColor;
    id middle = (__bridge id)[UIColor colorWithWhite:1 alpha:.5].CGColor;
    mask.colors = incoming ? @[white, middle, clear] : @[clear, middle, white];
    mask.locations = @[@0, @.5, @1];
    layer.mask = mask;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"startPoint"];
    animation.values = starts;
    animation.keyTimes = keyTimes;
    animation.beginTime = begin;
    animation.duration = duration;
    animation.calculationMode = kCAAnimationLinear;
    animation.fillMode = kCAFillModeBoth;
    animation.removedOnCompletion = NO;
    [mask addAnimation:animation forKey:@"digitWipeStart"];
    CAKeyframeAnimation *end = [animation copy];
    end.keyPath = @"endPoint";
    end.values = ends;
    [mask addAnimation:end forKey:@"digitWipeEnd"];
}

- (void)transitionDigits:(NSArray *)paths text:(NSString *)text animated:(BOOL)animated { // 0x8a090
    NSArray *oldPaths = _digitPaths;
    NSString *oldText = _digitText;
    _digitPaths = [paths copy];
    _digitText = [text copy];
    if (!animated || !self.window || oldText.length != text.length || oldPaths.count != text.length ||
        paths.count != text.length || [oldText isEqualToString:text]) return;

    uint64_t token = _digitTransition;
    CGPathRef base = _glyphMask.path ? CGPathCreateCopy(_glyphMask.path) : NULL;
    id contents = _clockSpecular.contents;
    CGPathRef top = _clockSpecular.path ? CGPathCreateCopy(_clockSpecular.path) : NULL;
    CGFloat scale = self.window.screen.scale;
    CGFloat bezel = LGClockNumber(@"Clock.BezelWidth", 9, 100);
    CFTimeInterval begin = [_glyphMask convertTime:CACurrentMediaTime() fromLayer:nil];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _glyphMask.path = NULL;
    _clockSpecular.path = NULL;
    _clockSpecular.contents = nil;
    for (NSUInteger i = 0; i < paths.count; ++i) {
        BOOL unchanged = [text characterAtIndex:i] == [oldText characterAtIndex:i];
        for (NSUInteger p = unchanged ? 1 : 0; p < 2; ++p) {
            CGPathRef path = (__bridge CGPathRef)(p ? paths[i] : oldPaths[i]);
            if (!path || CGPathIsEmpty(path)) continue;
            CAShapeLayer *mask = [CAShapeLayer layer];
            mask.frame = self.bounds;
            mask.path = path;
            mask.fillColor = UIColor.whiteColor.CGColor;
            [_glyphMask addSublayer:mask];
            CAShapeLayer *shine = [CAShapeLayer layer];
            shine.frame = self.bounds;
            shine.contentsScale = scale;
            CGImageRef specular = LGClockSpecularImage(path, self.bounds.size, bezel, scale);
            shine.contents = (__bridge id)specular;
            if (specular) CGImageRelease(specular);
            else {
                shine.path = path;
                shine.fillColor = UIColor.clearColor.CGColor;
                shine.strokeColor = _clockSpecular.strokeColor;
                shine.lineWidth = _clockSpecular.lineWidth;
            }
            [_clockSpecular addSublayer:shine];
            if (!unchanged) {
                LGClockInstallDigitWipe(mask, path, p != 0, begin);
                LGClockInstallDigitWipe(shine, path, p != 0, begin);
            }
        }
    }
    [CATransaction commit];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1600000000LL), dispatch_get_main_queue(), ^{ // 0x8ac20
        if (token == self->_digitTransition) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self->_glyphMask.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
            [self->_clockSpecular.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
            self->_glyphMask.path = base;
            self->_clockSpecular.contents = contents;
            self->_clockSpecular.path = top;
            [CATransaction commit];
        }
        if (base) CGPathRelease(base);
        if (top) CGPathRelease(top);
    });
}

- (void)logClockGeometry:(NSString *)reason { // 0x880a4
    if (!LGDebugLoggingEnabled()) return;
    CFTimeInterval now = CACurrentMediaTime();
    if (_geometryTraceCount >= 80 || (now - _lastGeometryTrace < .5 && [reason isEqualToString:@"layout"])) return;
    _lastGeometryTrace = now;
    ++_geometryTraceCount;

    LGClockField *map = _mapping;
    uint64_t owner = map ? atomic_load_explicit(&map->owner, memory_order_acquire) : 0;
    uint64_t generation = map ? atomic_load_explicit(&map->generation, memory_order_acquire) : 0;
    uint64_t consumed = map ? atomic_load_explicit(&map->consumed, memory_order_acquire) : 0;
    uint32_t orientation = map ? atomic_load_explicit(&map->orientation, memory_order_acquire) : 0;
    uint32_t w = map ? map->width : 0, h = map ? map->height : 0;
    float pointW = map ? map->pointWidth : 0, pointH = map ? map->pointHeight : 0;
    BOOL valid = map && map->magic == LGFieldMagic && map->version == LGFieldVersion && owner && generation &&
        w && w <= 1024 && h && h <= 1024 && pointW > 0 && pointW <= 2048 && pointH > 0 && pointH <= 2048 &&
        orientation >= 1 && orientation <= 4;
    LGLog(@"[ClockPosterField] reason=%@ process=%@ view=%p editor=%d slot=%ld mapping=%p owner=%llu currentProducer=%llu generation=%llu consumed=%llu valid=%d field=%ux%u points=%.3fx%.3f orientation=%u filter=%@ attached=%d",
          reason, NSProcessInfo.processInfo.processName, self, _editor, (long)_posterSlot, (void *)map,
          (unsigned long long)owner, (unsigned long long)_producer, (unsigned long long)generation,
          (unsigned long long)consumed, valid, w, h, pointW, pointH, orientation, _glass.lgFilterType, [_glass lgFilterAttached]);

    // Layer coverage below is semantic, not a byte-for-byte log reconstruction.
    CGRect glyph = _glyphMask.path ? CGPathGetBoundingBox(_glyphMask.path) : CGRectNull;
    CGRect specular = _clockSpecular.path ? CGPathGetBoundingBox(_clockSpecular.path) : CGRectNull;
    NSMutableString *trace = [NSMutableString stringWithFormat:
        @"[CLOCK-GEOMETRY] %.6f reason=%@ view=%p os=%@ window=%p frame=%@ bounds=%@ transform=%@ glyphBounds=%@ specularPathBounds=%@\n",
        now, reason, self, NSProcessInfo.processInfo.operatingSystemVersionString, self.window,
        NSStringFromCGRect(self.frame), NSStringFromCGRect(self.bounds), NSStringFromCGAffineTransform(self.transform),
        NSStringFromCGRect(glyph), NSStringFromCGRect(specular)];
    CALayer *layers[] = {self.layer, _material.layer, _glyphMask, _blur.layer, _vibrance.layer,
                        _glass.layer, _colorTint.layer, _clockSpecular, _specularVibrance.layer};
    const char *names[] = {"self", "material", "glyphMask", "blur", "vibrance", "glass", "colorTint", "clockSpecular", "specularVibrance"};
    for (NSUInteger i = 0; i < sizeof(layers)/sizeof(*layers); ++i) {
        CALayer *layer = layers[i], *p = layer.presentationLayer;
        if (!layer) continue;
        [trace appendFormat:@" %s layer=%p parent=%p frame=%@ bounds=%@ position=%@ anchor=%@ transform=%@ opacity=%g hidden=%d masks=%d mask=%p contentsScale=%g contentsRect=%@ presentationFrame=%@ presentationBounds=%@ presentationPosition=%@ presentationTransform=%@\n",
            names[i], layer, layer.superlayer, NSStringFromCGRect(layer.frame), NSStringFromCGRect(layer.bounds),
            NSStringFromCGPoint(layer.position), NSStringFromCGPoint(layer.anchorPoint), [NSValue valueWithCATransform3D:layer.transform],
            layer.opacity, layer.hidden, layer.masksToBounds, layer.mask, layer.contentsScale, NSStringFromCGRect(layer.contentsRect),
            NSStringFromCGRect(p.frame), NSStringFromCGRect(p.bounds), NSStringFromCGPoint(p.position),
            p ? [NSValue valueWithCATransform3D:p.transform] : nil];
        for (CALayer *child in layer.sublayers) {
            CALayer *cp = child.presentationLayer;
            [trace appendFormat:@" internal=%p class=%@ parent=%p frame=%@ bounds=%@ position=%@ transform=%@ presentationFrame=%@ presentationBounds=%@ filters=%@\n",
                child, NSStringFromClass(child.class), child.superlayer, NSStringFromCGRect(child.frame),
                NSStringFromCGRect(child.bounds), NSStringFromCGPoint(child.position), [NSValue valueWithCATransform3D:child.transform],
                NSStringFromCGRect(cp.frame), NSStringFromCGRect(cp.bounds), child.filters];
        }
    }
    for (UIView *view = self.superview; view; view = view.superview)
        [trace appendFormat:@" ancestor=%p class=%@ frame=%@ bounds=%@ transform=%@ clips=%d\n",
            view, NSStringFromClass(view.class), NSStringFromCGRect(view.frame), NSStringFromCGRect(view.bounds),
            NSStringFromCGAffineTransform(view.transform), view.clipsToBounds];
    LGLog(@"%@", trace);
}

@end
