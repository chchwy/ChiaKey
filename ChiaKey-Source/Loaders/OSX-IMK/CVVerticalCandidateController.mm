// [AUTO_HEADER]

#import "CVVerticalCandidateController.h"

#import "NSColor+LFColorExtensions.h"

@implementation CVPageButton

- (BOOL)isFlipped {
  return NO;
}
- (void)drawRect:(NSRect)aRect {
  NSRect selfRect = [self frame];
  NSRect rect = NSMakeRect(0, 0, selfRect.size.width, selfRect.size.height);
  if ([self image]) {
    NSImage *i = nil;
    if ([[self cell] isHighlighted]) {
      if ([self alternateImage])
        i = [self alternateImage];
      else
        i = [self image];
    } else {
      i = [self image];
    }
    NSSize size = [i size];
    float x = (rect.size.width - size.width) / 2;
    float y = (rect.size.height - size.height) / 2;
    [i drawAtPoint:NSMakePoint(x, y)
          fromRect:NSZeroRect
         operation:NSCompositingOperationSourceOver
          fraction:1.0];
  }
}
@end

// the strips above and below the table that hold the page buttons
static const CGFloat kPageControlMargin = 20.0;
// where VerticalCandidateWindow.xib puts the page buttons
static const CGFloat kCollapsedPageButtonX = 4.0;
// room at the right edge for the arrow that says more pages follow
static const CGFloat kMorePagesIndicatorWidth = 10.0;

@implementation CVExpandedCandidateView

- (void)dealloc {
  [_columns release];
  [_keyStrings release];
  [_keyCell release];
  [_textCell release];
  [super dealloc];
}
- (BOOL)isFlipped {
  return YES;
}
- (NSAttributedString *)attributedCandidate:(NSString *)candidate {
  return [[[NSAttributedString alloc]
      initWithString:candidate
          attributes:[NSDictionary
                         dictionaryWithObject:[NSFont systemFontOfSize:_fontSize]
                                       forKey:NSFontAttributeName]] autorelease];
}
- (void)adoptLayoutOfTableView:(NSTableView *)tableView {
  NSTableColumn *keyColumn = [tableView tableColumnWithIdentifier:@"key"];
  NSTableColumn *textColumn = [tableView tableColumnWithIdentifier:@"candidate"];
  [_keyCell release];
  _keyCell = [[keyColumn dataCell] copy];
  [_textCell release];
  _textCell = [[textColumn dataCell] copy];

  NSRect row = [tableView rectOfRow:0];
  NSRect key = [tableView
      frameOfCellAtColumn:[[tableView tableColumns] indexOfObject:keyColumn]
                      row:0];
  NSRect text = [tableView
      frameOfCellAtColumn:[[tableView tableColumns] indexOfObject:textColumn]
                      row:0];
  _keyFrame = NSOffsetRect(key, -NSMinX(row), -NSMinY(row));
  _textFrame = NSOffsetRect(text, -NSMinX(row), -NSMinY(row));
  _rowHeight = NSHeight(row);
  _rowWidth = NSWidth(row);
  _leftInset = NSMinX([tableView convertRect:row toView:[self superview]]);
}
- (CGFloat)widthOfColumn:(NSUInteger)column {
  CGFloat width = 0;
  for (NSString *candidate in [_columns objectAtIndex:column]) {
    [_textCell setObjectValue:[self attributedCandidate:candidate]];
    width = MAX(width, ceil([_textCell cellSize].width));
  }
  CGFloat fitted = NSMinX(_textFrame) + MIN(width, 160.0) + 2.0;
  // the first column keeps the collapsed list's width
  return column == 0 ? MAX(_rowWidth, fitted) : fitted;
}
- (CGFloat)leftOfColumn:(NSUInteger)column {
  CGFloat left = _leftInset;
  for (NSUInteger index = 0; index < column; index++)
    left += [self widthOfColumn:index];
  return left;
}
- (void)setColumns:(NSArray *)columns
        keyStrings:(NSArray *)keyStrings
     currentColumn:(NSUInteger)currentColumn
    highlightedRow:(NSUInteger)highlightedRow
          rowCount:(NSUInteger)rowCount
      hasMorePages:(BOOL)hasMorePages
          fontSize:(float)fontSize {
  [_columns release];
  _columns = [columns copy];
  [_keyStrings release];
  _keyStrings = [keyStrings copy];
  _currentColumn = currentColumn;
  _highlightedRow = highlightedRow;
  _rowCount = rowCount;
  _hasMorePages = hasMorePages;
  _fontSize = fontSize;
  [self setNeedsDisplay:YES];
}
- (NSSize)preferredSize {
  return NSMakeSize(ceil([self leftOfColumn:[_columns count]] + _leftInset +
                         (_hasMorePages ? kMorePagesIndicatorWidth : 0)),
                    ceil(_rowHeight * _rowCount));
}
- (NSRect)rectForColumn:(NSUInteger)column row:(NSUInteger)row {
  return NSMakeRect([self leftOfColumn:column], _rowHeight * row,
                    [self widthOfColumn:column], _rowHeight);
}
- (void)drawRect:(NSRect)dirtyRect {
  NSColor *foreground = [NSColor whiteColor];
  NSColor *fromColor = [NSColor highlightGradientFromColor];
  NSGradient *gradient =
      [[[NSGradient alloc] initWithStartingColor:fromColor
                                     endingColor:[fromColor gradientToColor]]
          autorelease];

  for (NSUInteger column = 0; column < [_columns count]; column++) {
    NSArray *candidates = [_columns objectAtIndex:column];
    BOOL active = column == _currentColumn;
    for (NSUInteger row = 0; row < [candidates count]; row++) {
      NSRect cell = [self rectForColumn:column row:row];
      if (active && row == _highlightedRow) {
        [gradient drawInRect:cell angle:90.0];
      }
      if (active && row < [_keyStrings count] &&
          [[_keyStrings objectAtIndex:row] length]) {
        [_keyCell setObjectValue:[CVTextDecoration
                                     imageWithACharacterInACircle:
                                         [_keyStrings objectAtIndex:row]
                                                       foreground:foreground
                                                       background:[NSColor
                                                                      blackColor]]];
        [_keyCell drawWithFrame:NSOffsetRect(_keyFrame, NSMinX(cell),
                                             NSMinY(cell))
                         inView:self];
      }
      NSRect textFrame = NSOffsetRect(_textFrame, NSMinX(cell), NSMinY(cell));
      textFrame.size.width = NSMaxX(cell) - NSMinX(textFrame);
      [_textCell
          setObjectValue:[self attributedCandidate:[candidates objectAtIndex:row]]];
      // other columns are only a preview, so they recede behind the active one
      [(NSTextFieldCell *)_textCell
          setTextColor:active ? foreground
                              : [foreground colorWithAlphaComponent:0.55]];
      [_textCell drawWithFrame:textFrame inView:self];
    }
  }

  if (_hasMorePages) {
    CGFloat x = [self leftOfColumn:[_columns count]] + 2;
    CGFloat y = NSMidY([self bounds]);
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(x, y - 3)];
    [arrow lineToPoint:NSMakePoint(x + 5, y)];
    [arrow lineToPoint:NSMakePoint(x, y + 3)];
    [arrow closePath];
    [[foreground colorWithAlphaComponent:0.7] setFill];
    [arrow fill];
  }
}
- (void)setClickable:(BOOL)flag {
  _clickable = flag;
}
- (void)setTarget:(id)target action:(SEL)action {
  _target = target;
  _action = action;
}
- (NSInteger)clickedColumn {
  return _clickedColumn;
}
- (NSInteger)clickedRow {
  return _clickedRow;
}
- (void)mouseDown:(NSEvent *)theEvent {
  _clickedColumn = -1;
  _clickedRow = -1;
  if (!_clickable) return;

  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  for (NSUInteger column = 0; column < [_columns count]; column++) {
    NSUInteger count = [[_columns objectAtIndex:column] count];
    for (NSUInteger row = 0; row < count; row++) {
      if (NSPointInRect(point, [self rectForColumn:column row:row])) {
        _clickedColumn = column;
        _clickedRow = row;
        [_target performSelector:_action withObject:self];
        return;
      }
    }
  }
}
@end

@implementation CVVerticalCandidateController

- (void)dealloc {
  [_expandedView release];
  [_candidateArray release];
  [_backgroundColor release];
  [_foregroundColor release];
  [_highlightTextColor release];
  [super dealloc];
}
- (id)init {
  self = [super init];
  if (self != nil) {
    BOOL loaded = [[NSBundle mainBundle] loadNibNamed:@"VerticalCandidateWindow" owner:self topLevelObjects:nil];
    NSAssert((loaded == YES), @"NIB did not load");

    _candidateTextHeight = 18.0;
  }
  return self;
}
- (NSImage *)imagePrev:(NSColor *)aColor {
  NSImage *imagePrev;
  imagePrev = [[[NSImage alloc] initWithSize:NSMakeSize(6, 6)] autorelease];
  [imagePrev lockFocus];
  NSBezierPath *bezierPath = [NSBezierPath bezierPath];
  [bezierPath moveToPoint:NSMakePoint(0, 0)];
  [bezierPath lineToPoint:NSMakePoint(6, 0)];
  [bezierPath lineToPoint:NSMakePoint(3, 6)];
  [bezierPath closePath];
  [aColor setFill];
  [bezierPath fill];
  [imagePrev unlockFocus];
  return imagePrev;
}
- (NSImage *)imageNext:(NSColor *)aColor {
  NSImage *imageNext;
  imageNext = [[[NSImage alloc] initWithSize:NSMakeSize(6, 6)] autorelease];
  [imageNext lockFocus];
  NSBezierPath *bezierPath = [NSBezierPath bezierPath];
  [bezierPath moveToPoint:NSMakePoint(0, 6)];
  [bezierPath lineToPoint:NSMakePoint(6, 6)];
  [bezierPath lineToPoint:NSMakePoint(3, 0)];
  [bezierPath closePath];
  [aColor setFill];
  [bezierPath fill];
  [imageNext unlockFocus];
  return imageNext;
}
- (void)awakeFromNib {
  _backgroundColor = [[NSColor blackColor] retain];
  _foregroundColor = [[NSColor whiteColor] retain];
  _highlightTextColor = [[NSColor whiteColor] retain];

  [[[self window] contentView] setBackgroundFillColor:_backgroundColor];
  [[[self window] contentView] setBorderColor:_foregroundColor];
  [_tableView setTablebackgroundColor:_backgroundColor];

  _candidateArray = [[NSMutableArray alloc] init];
  [_scrollView setBorderType:NSNoBorder];
  [_tableView setDelegate:(id)self];
  [_tableView setDataSource:(id)self];

  [_pageIndicatorTextField setStringValue:@""];
  [_pageIndicatorTextField setTextColor:_foregroundColor];
  [_promptTextField setStringValue:@""];
  [_promptTextField setTextColor:_foregroundColor];

  [_tableView setBackgroundColor:[NSColor clearColor]];
  [_tableView setAction:@selector(sendKey:)];

  [_previousButton setHidden:YES];
  [_nextButton setHidden:YES];

  _expandedView = [[CVExpandedCandidateView alloc] initWithFrame:NSZeroRect];
  _pageButtonOffset = 1;
  _collapsedTopGap = kPageControlMargin;
  [_expandedView setTarget:self action:@selector(sendExpandedKey:)];
  [_expandedView setHidden:YES];
  // below the page buttons, which stay clickable on top of it
  [[[self window] contentView] addSubview:_expandedView
                               positioned:NSWindowBelow
                               relativeTo:nil];

  _sending = NO;
}
- (void)setFontHeight:(float)newHeight {
  _fontHeight = newHeight;
  if (_fontHeight < 20) _fontHeight = 20;
}
- (void)updateDisplay:(PVVerticalCandidatePanel *)panel
              atPoint:(NSPoint)position {
  // hide if it's invisible--before update
  if (!panel->isVisible()) {
    [[self window] orderOut:self];
    return;
  }

  _sending = NO;

  [[[self window] contentView] setBackgroundFillColor:_backgroundColor];
  [[[self window] contentView] setBorderColor:_foregroundColor];

  NSColor *highlightColor = [NSColor highlightGradientFromColor];
  [_previousButton setImage:[self imagePrev:_foregroundColor]];
  [_previousButton setAlternateImage:[self imagePrev:highlightColor]];
  [_nextButton setImage:[self imageNext:_foregroundColor]];
  [_nextButton setAlternateImage:[self imageNext:highlightColor]];

  if (panel->isExpanded()) {
    [self updateExpandedDisplay:panel atPoint:position];
    return;
  }
  [_expandedView setHidden:YES];
  [_scrollView setHidden:NO];
  [_promptTextField setHidden:NO];

  if (_candidateArray)
    [_candidateArray removeAllObjects];
  else
    _candidateArray = [NSMutableArray new];

  [[[self window] contentView] setBackgroundFillColor:_backgroundColor];
  [[[self window] contentView] setBorderColor:_foregroundColor];
  [_tableView setTablebackgroundColor:_backgroundColor];

  // update the content
  size_t fromIndex = panel->currentPage() * panel->candidatesPerPage();
  size_t index;
  size_t count = panel->currentPageCandidateCount();
  size_t highlightedIndex = panel->currentHightlightIndex();
  size_t currentPage = panel->currentPage() + 1;
  size_t pageCount = panel->pageCount();
  NSString *pageString =
      [NSString stringWithFormat:@"%zu/%zu", currentPage, pageCount];
  if (pageCount > 1) {
    [_pageIndicatorTextField setStringValue:pageString];
    [_pageIndicatorTextField setHidden:NO];
    [_previousButton setHidden:NO];
    [_nextButton setHidden:NO];
  } else {
    [_pageIndicatorTextField setStringValue:@""];
    [_pageIndicatorTextField setHidden:YES];
    [_previousButton setHidden:YES];
    [_nextButton setHidden:YES];
  }

  _width = 0;

  NSString *prompt = [NSString stringWithUTF8String:panel->prompt().c_str()];
  [_promptTextField setStringValue:prompt];
  float promptHeight = [_promptTextField frame].size.height;
  NSRect newPromptRect = [[_promptTextField attributedStringValue]
      boundingRectWithSize:NSMakeSize(1600, promptHeight)
                   options:NSStringDrawingUsesLineFragmentOrigin];
  _width = newPromptRect.size.width + 10;

  OVCandidateList *list = panel->candidateList();

  float fontSize = _candidateTextHeight;

  NSFont *defaultFont = [NSFont systemFontOfSize:fontSize];
  NSDictionary *attributes =
      [NSDictionary dictionaryWithObject:defaultFont
                                  forKey:NSFontAttributeName];

  [_tableView setRowHeight:fontSize + 6.0];
  for (index = 0; index < count; index++) {
    string candidate = list->candidateAtIndex(fromIndex + index);
    string keyString = panel->candidateKeyAtIndex(index).receivedString();

    NSAttributedString *c = [[[NSAttributedString alloc]
        initWithString:[NSString stringWithUTF8String:candidate.c_str()]
            attributes:attributes] autorelease];
    NSString *k = [NSString stringWithUTF8String:keyString.c_str()];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setValue:c forKey:@"candidate"];
    NSImage *i = nil;
    if (index == highlightedIndex && panel->isInControl()) {
      i = [CVTextDecoration imageWithACharacterInACircle:k
                                              foreground:_highlightTextColor
                                              background:_backgroundColor];
    } else {
      i = [CVTextDecoration imageWithACharacterInACircle:k
                                              foreground:_foregroundColor
                                              background:_backgroundColor];
    }
    [d setValue:i forKey:@"key"];

    NSRect rect =
        [c boundingRectWithSize:NSMakeSize(1600, [_tableView rowHeight])
                        options:NSStringDrawingUsesLineFragmentOrigin];
    float currentWidth = rect.size.width;
    if (currentWidth >= _width) _width = currentWidth;

    [_candidateArray addObject:d];
  }
  [_tableView reloadData];

  NSRect tableFrame = [_tableView frame];
  tableFrame.size.width = 50 + _width;
  tableFrame.size.height =
      ([_tableView rowHeight] + 2) * panel->candidatesPerPage();
  if (!tableFrame.size.height) tableFrame.size.height = 200;
  [_tableView setFrame:tableFrame];
  [_tableView sizeToFit];

  [self placeWindowWithSize:NSMakeSize(tableFrame.size.width,
                                       tableFrame.size.height + 40)
                    atPoint:position];
  [self placePageButtonsAtX:kCollapsedPageButtonX];

  // The expanded grid copies this layout. Measure it now: once expanded, the
  // hidden table stretches with the wider window.
  if ([_tableView numberOfRows] > 0) {
    NSView *contentView = [[self window] contentView];
    [_expandedView adoptLayoutOfTableView:_tableView];
    NSRect row = [_tableView convertRect:[_tableView rectOfRow:0]
                                  toView:contentView];
    _collapsedTopGap = NSHeight([contentView bounds]) - NSMaxY(row);
    _pageButtonOffset = kCollapsedPageButtonX - NSMinX(row);
  }

  if (panel->isInControl()) {
    _allowClick = YES;
    [_tableView setAllowsEmptySelection:NO];
    [_tableView selectRowIndexes:[NSIndexSet
                                     indexSetWithIndex:(int)highlightedIndex]
            byExtendingSelection:NO];
  } else {
    [_tableView setAllowsEmptySelection:YES];
    [_tableView deselectAll:self];
    _allowClick = NO;
  }

  // show if it's visible--after update
  if (panel->isVisible()) [[self window] makeKeyAndOrderFront:self];
}
- (void)updateExpandedDisplay:(PVVerticalCandidatePanel *)panel
                      atPoint:(NSPoint)position {
  [_scrollView setHidden:YES];
  [_promptTextField setHidden:NO];
  [_promptTextField
      setStringValue:[NSString stringWithUTF8String:panel->prompt().c_str()]];
  [_pageIndicatorTextField
      setStringValue:[NSString stringWithFormat:@"%zu/%zu",
                                                panel->currentPage() + 1,
                                                panel->pageCount()]];
  [_pageIndicatorTextField setHidden:NO];
  [_previousButton setHidden:NO];
  [_nextButton setHidden:NO];

  OVCandidateList *list = panel->candidateList();
  size_t perPage = panel->candidatesPerPage();
  size_t firstPage = panel->expandedFirstPage();
  size_t columnCount = panel->expandedPageCount();
  NSMutableArray *columns = [NSMutableArray array];
  for (size_t column = 0; column < columnCount; column++) {
    NSMutableArray *candidates = [NSMutableArray array];
    size_t from = (firstPage + column) * perPage;
    for (size_t index = from; index < from + perPage && index < list->size();
         index++) {
      [candidates addObject:[NSString stringWithUTF8String:
                                          list->candidateAtIndex(index).c_str()]];
    }
    [columns addObject:candidates];
  }

  NSMutableArray *keyStrings = [NSMutableArray array];
  for (size_t index = 0; index < panel->currentPageCandidateCount(); index++) {
    [keyStrings addObject:[NSString stringWithUTF8String:panel->candidateKeyAtIndex(index)
                                                         .receivedString()
                                                         .c_str()]];
  }

  [_expandedView setColumns:columns
                 keyStrings:keyStrings
              currentColumn:panel->currentPage() - firstPage
             highlightedRow:panel->currentHightlightIndex()
                   rowCount:perPage
               hasMorePages:firstPage + columnCount < panel->pageCount()
                   fontSize:_candidateTextHeight];
  [_expandedView setClickable:panel->isInControl()];

  // Same window height and row positions as the collapsed table, so
  // expanding leaves its rows exactly where they were.
  NSSize size = [_expandedView preferredSize];
  CGFloat height = ([_tableView rowHeight] + 2) * perPage + 40;
  [self placeWindowWithSize:NSMakeSize(size.width, height) atPoint:position];
  [_expandedView setFrame:NSMakeRect(0, height - _collapsedTopGap - size.height,
                                     size.width, size.height)];
  [_expandedView setHidden:NO];
  [self placePageButtonsAtX:[_expandedView
                                leftOfColumn:panel->currentPage() - firstPage] +
                            _pageButtonOffset];

  if (panel->isVisible()) [[self window] makeKeyAndOrderFront:self];
}
// the page buttons sit over the key column of the current page
- (void)placePageButtonsAtX:(CGFloat)x {
  NSRect bounds = [[[self window] contentView] bounds];
  NSRect previousFrame = [_previousButton frame];
  previousFrame.origin =
      NSMakePoint(x, NSMaxY(bounds) - NSHeight(previousFrame));
  [_previousButton setFrame:previousFrame];
  NSRect nextFrame = [_nextButton frame];
  nextFrame.origin = NSMakePoint(x, -1);
  [_nextButton setFrame:nextFrame];
}
- (void)placeWindowWithSize:(NSSize)size atPoint:(NSPoint)position {
  NSPoint newPosition = position;
  NSRect windowFrame = [[self window] frame];
  windowFrame.size = size;
  windowFrame.origin.x = newPosition.x;

  NSRect frame = [[NSScreen mainScreen] visibleFrame];
  NSArray *screens = [NSScreen screens];
  NSUInteger i, c = [screens count];

  if ([screens count] > 1) {
    for (i = 0; i < c; i++) {
      NSScreen *screen = [screens objectAtIndex:i];
      NSRect screenFrame = [screen frame];

      if (newPosition.x >= NSMinX(screenFrame) &&
          newPosition.x <= NSMaxX(screenFrame)) {
        frame = [screen visibleFrame];
        break;
      }
    }
  }

  if (newPosition.y < NSMinY(frame))
    newPosition.y = NSMinY(frame);
  else if (newPosition.y - windowFrame.size.height < NSMinY(frame))
    newPosition.y = newPosition.y + _fontHeight;
  //	else if (newPosition.y + windowFrame.size.height > NSMaxY(frame))
  else if (newPosition.y > NSMaxY(frame))
    newPosition.y = NSMaxY(frame) - windowFrame.size.height;
  else
    newPosition.y = newPosition.y - windowFrame.size.height;

  if (newPosition.x < NSMinX(frame))
    newPosition.x = NSMinX(frame);
  else if (newPosition.x + windowFrame.size.width > NSMaxX(frame))
    newPosition.x = NSMaxX(frame) - windowFrame.size.width;

  windowFrame.origin = newPosition;

  [[self window] setFrame:windowFrame display:YES];
}
- (void)hide {
  [[self window] orderOut:self];
  ;
}

#pragma mark Interface Builder actions

- (IBAction)sendKey:(id)sender {
  if (_sending) return;
  NSInteger selectedItem = [_tableView selectedRow];
  string keyString = _panel->candidateKeyAtIndex(selectedItem).receivedString();
  [[CVSendKey sharedSendKey]
      typeString:[NSString stringWithUTF8String:keyString.c_str()]];
}

- (void)sendExpandedKey:(id)sender {
  if (_sending) return;
  NSInteger column = [_expandedView clickedColumn];
  NSInteger row = [_expandedView clickedRow];
  if (column < 0 || row < 0) return;
  _panel->goToPage(_panel->expandedFirstPage() + (size_t)column);
  _panel->setHighlightIndex((size_t)row);
  OVKey selectionKey = _panel->selectionKeyAtIndex((size_t)row);
  // typeString posts the key after a delay; ignore clicks until it lands
  _sending = YES;
  [_expandedView setClickable:NO];
  [[CVSendKey sharedSendKey]
      typeString:[NSString stringWithUTF8String:selectionKey.receivedString()
                                                    .c_str()]];
}

- (IBAction)updateSelectedCandidate:(id)sender {
  NSInteger selectedItem = [_tableView selectedRow];
  _panel->setHighlightIndex((size_t)selectedItem);
  NSPoint p = [[self window] frame].origin;
  p.y = p.y + [[self window] frame].size.height;
  [self updateDisplay:_panel atPoint:p];
}

- (void)updateContent:(PVVerticalCandidatePanel *)panel
              atPoint:(NSPoint)position;
{
  [self updateDisplay:panel atPoint:position];
  _panel = panel;
}
- (IBAction)gotoNextPage:(id)sender {
  _panel->goToNextPage();
  NSPoint p = [[self window] frame].origin;
  p.y = NSMaxY([[self window] frame]);
  [self updateDisplay:_panel atPoint:p];
}
- (IBAction)gotoPreviousPage:(id)sender {
  _panel->goToPreviousPage();
  NSPoint p = [[self window] frame].origin;
  p.y = NSMaxY([[self window] frame]);
  [self updateDisplay:_panel atPoint:p];
}

- (void)setCandidateTextHeight:(float)inTextHeight {
  _candidateTextHeight = inTextHeight;
}

#pragma mark TableView delegate

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView {
  return _allowClick;
}
- (void)tableView:(NSTableView *)aTableView
    willDisplayCell:(id)aCell
     forTableColumn:(NSTableColumn *)aTableColumn
                row:(NSInteger)rowIndex {
  NSInteger selectedRow = [_tableView selectedRow];
  if ([[aTableColumn identifier] isEqualToString:@"candidate"]) {
    if (rowIndex == selectedRow)
      [aCell setTextColor:_highlightTextColor];
    else
      [aCell setTextColor:_foregroundColor];
  }
}
- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
                          row:(NSInteger)rowIndex {
  if ([[aTableColumn identifier] isEqualToString:@"key"])
    return [[_candidateArray objectAtIndex:rowIndex] objectForKey:@"key"];
  else if ([[aTableColumn identifier] isEqualToString:@"candidate"])
    return [[_candidateArray objectAtIndex:rowIndex] objectForKey:@"candidate"];
  return nil;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return (NSInteger)[_candidateArray count];
}

@end
