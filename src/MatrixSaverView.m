//
// Matrix screensaver, drawn natively in the style of the terminal program
// cmatrix: random ASCII characters fall in every other text column, green
// with a white leading character, and are erased from the top after the
// stream has passed.
//
// No web view and no network access. Builds for arm64 and x86_64 -- see
// build.sh.
//

#import <ScreenSaver/ScreenSaver.h>
#import <CoreText/CoreText.h>

// Printable ASCII range used for the rain, as in cmatrix's default mode.
static const UniChar kFirstChar = 33;
static const int kCharCount = 90;

static const NSTimeInterval kTick = 1.0 / 20.0;

typedef struct {
    int spaces;    // blank rows still to leave before the next stream starts
    int length;    // target length of the topmost stream in this column
} MatrixColumn;

@interface MatrixSaverView : ScreenSaverView
@end

@implementation MatrixSaverView {
    CTFontRef _font;
    CGGlyph _glyphs[90];
    CGFloat _cellWidth;
    CGFloat _cellHeight;
    CGFloat _ascent;

    NSSize _gridSize;       // view size the grid was built for
    int _cols;
    int _rows;
    MatrixColumn *_columns; // _cols entries
    CGGlyph *_cells;        // _cols * _rows glyphs, column-major; 0 is blank
    BOOL *_bold;            // _cols * _rows flags for the brighter green
    BOOL *_head;            // _cols * _rows flags for the white leading character
    NSTimer *_timer;

    CGGlyph *_drawGlyphs;   // scratch buffers reused by -drawRect:
    CGPoint *_drawPoints;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        // The rain runs on its own timer (see -startAnimation), so the
        // framework's frame callback is not needed.
        self.animationTimeInterval = 1.0;
    }
    return self;
}

- (void)dealloc {
    [_timer invalidate];
    [self freeGrid];
}

- (void)startAnimation {
    [super startAnimation];
    if (_timer) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer timerWithTimeInterval:kTick repeats:YES block:^(NSTimer *timer) {
        [weakSelf step];
    }];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stopAnimation {
    [_timer invalidate];
    _timer = nil;
    [super stopAnimation];
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

#pragma mark - Grid

- (void)freeGrid {
    if (_font) {
        CFRelease(_font);
        _font = NULL;
    }
    free(_columns);
    free(_cells);
    free(_bold);
    free(_head);
    free(_drawGlyphs);
    free(_drawPoints);
    _columns = NULL;
    _cells = NULL;
    _bold = NULL;
    _head = NULL;
    _drawGlyphs = NULL;
    _drawPoints = NULL;
    _cols = 0;
    _rows = 0;
}

- (CGGlyph)randomGlyph {
    return _glyphs[arc4random_uniform(kCharCount)];
}

- (int)randomLength {
    return 3 + (int)arc4random_uniform((uint32_t)MAX(1, _rows - 3));
}

- (void)buildGridForSize:(NSSize)size {
    [self freeGrid];
    _gridSize = size;
    if (size.width < 1 || size.height < 1) {
        return;
    }

    // Terminal-like text on a full display, scaled down for the small
    // preview in System Settings.
    CGFloat fontSize = MAX(5.0, MIN(16.0, floor(size.height / 55.0)));
    _font = CTFontCreateWithName(CFSTR("Menlo-Bold"), fontSize, NULL);

    UniChar characters[90];
    for (int i = 0; i < kCharCount; i++) {
        characters[i] = (UniChar)(kFirstChar + i);
    }
    CTFontGetGlyphsForCharacters(_font, characters, _glyphs, kCharCount);

    CGSize advance = CGSizeZero;
    CTFontGetAdvancesForGlyphs(_font, kCTFontOrientationHorizontal, &_glyphs['M' - kFirstChar], &advance, 1);
    _ascent = ceil(CTFontGetAscent(_font));
    // cmatrix only uses every second terminal column.
    _cellWidth = ceil(advance.width) * 2.0;
    _cellHeight = _ascent + ceil(CTFontGetDescent(_font)) + ceil(CTFontGetLeading(_font));

    _cols = MAX(1, (int)ceil(size.width / _cellWidth));
    _rows = MAX(1, (int)ceil(size.height / _cellHeight));

    size_t cellCount = (size_t)_cols * (size_t)_rows;
    _columns = calloc((size_t)_cols, sizeof(MatrixColumn));
    _cells = calloc(cellCount, sizeof(CGGlyph));
    _bold = calloc(cellCount, sizeof(BOOL));
    _head = calloc(cellCount, sizeof(BOOL));
    _drawGlyphs = calloc(cellCount, sizeof(CGGlyph));
    _drawPoints = calloc(cellCount, sizeof(CGPoint));

    for (int c = 0; c < _cols; c++) {
        // Stagger the start so the screen fills in gradually.
        _columns[c].spaces = (int)arc4random_uniform((uint32_t)_rows) + 1;
        _columns[c].length = [self randomLength];
    }
}

#pragma mark - Animation

- (void)animateOneFrame {
}

- (void)setCell:(size_t)index head:(BOOL)head {
    _cells[index] = [self randomGlyph];
    _bold[index] = arc4random_uniform(3) == 0;
    _head[index] = head;
}

// One tick of the cmatrix model. Characters never move: every stream in a
// column gains a new leading character below it and, once it is long
// enough, loses its top one. New streams start at the top after a random
// gap, so a column can hold several streams at once.
- (void)step {
    if (!NSEqualSizes(self.bounds.size, _gridSize) || !_columns) {
        [self buildGridForSize:self.bounds.size];
    }
    if (!_columns) {
        return;
    }

    for (int c = 0; c < _cols; c++) {
        MatrixColumn *column = &_columns[c];
        size_t base = (size_t)c * (size_t)_rows;
        BOOL topFree = (_cells[base] == 0);
        BOOL topmost = YES;

        int r = 0;
        while (r < _rows) {
            while (r < _rows && _cells[base + r] == 0) {
                r++;
            }
            if (r >= _rows) {
                break;
            }
            int start = r;
            while (r < _rows && _cells[base + r] != 0) {
                _head[base + r] = NO;
                r++;
            }

            if (r >= _rows) {
                // The stream has reached the bottom: it only drains away.
                _cells[base + start] = 0;
                break;
            }
            [self setCell:base + (size_t)r head:YES];
            if (!topmost || r - start >= column->length) {
                _cells[base + start] = 0;
            }
            topmost = NO;
            r++;
        }

        if (topFree) {
            if (column->spaces > 0) {
                column->spaces--;
            } else {
                [self setCell:base head:YES];
                column->length = [self randomLength];
                column->spaces = (int)arc4random_uniform((uint32_t)_rows) + 1;
            }
        }
    }

    [self setNeedsDisplay:YES];
}

// Appends the lit cells that match `wantHead` / `wantBold` to the scratch
// buffers and draws them in one call.
- (void)drawCellsInContext:(CGContextRef)context head:(BOOL)wantHead bold:(BOOL)wantBold {
    size_t count = 0;

    for (int c = 0; c < _cols; c++) {
        for (int r = 0; r < _rows; r++) {
            size_t index = (size_t)c * (size_t)_rows + (size_t)r;
            if (_cells[index] == 0) {
                continue;
            }
            BOOL isHead = _head[index];
            if (isHead != wantHead || (!isHead && _bold[index] != wantBold)) {
                continue;
            }
            _drawGlyphs[count] = _cells[index];
            _drawPoints[count] = CGPointMake(c * _cellWidth, _gridSize.height - (r * _cellHeight + _ascent));
            count++;
        }
    }

    if (count > 0) {
        CTFontDrawGlyphs(_font, _drawGlyphs, _drawPoints, count, context);
    }
}

- (void)drawRect:(NSRect)rect {
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;

    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextFillRect(context, NSRectToCGRect(self.bounds));

    if (!_columns || !_font) {
        return;
    }

    // The view is flipped (row 0 at the top) but glyphs must be drawn in an
    // unflipped coordinate system to come out upright.
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1, -1);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(context, kCGTextFill);

    CGContextSetRGBFillColor(context, 0.0, 0.67, 0.0, 1);
    [self drawCellsInContext:context head:NO bold:NO];

    CGContextSetRGBFillColor(context, 0.2, 1.0, 0.2, 1);
    [self drawCellsInContext:context head:NO bold:YES];

    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    [self drawCellsInContext:context head:YES bold:NO];

    CGContextRestoreGState(context);
}

- (BOOL)hasConfigureSheet {
    return NO;
}

- (NSWindow *)configureSheet {
    return nil;
}

@end
