// [AUTO_HEADER]

#import <Cocoa/Cocoa.h>
#import <PlainVanilla/PlainVanilla.h>

#import "CVFloatingBackground.h"
#import "CVFloatingTableView.h"
#import "CVSendKey.h"
#import "CVTextDecoration.h"

using namespace OpenVanilla;

@interface CVPageButton : NSButton
@end

// Several pages side by side, one page per column; only the current column
// has keys.
@interface CVExpandedCandidateView : NSView {
  NSArray *_columns;
  NSArray *_keyStrings;
  NSUInteger _currentColumn;
  NSUInteger _highlightedRow;
  NSUInteger _rowCount;
  BOOL _hasMorePages;
  float _fontSize;
  // copied from the collapsed table, so each column renders exactly like it
  NSCell *_keyCell;
  NSCell *_textCell;
  NSRect _keyFrame;
  NSRect _textFrame;
  CGFloat _rowHeight;
  CGFloat _leftInset;

  BOOL _clickable;
  NSInteger _clickedColumn;
  NSInteger _clickedRow;
  id _target;
  SEL _action;
}
- (void)setColumns:(NSArray *)columns
        keyStrings:(NSArray *)keyStrings
     currentColumn:(NSUInteger)currentColumn
    highlightedRow:(NSUInteger)highlightedRow
          rowCount:(NSUInteger)rowCount
      hasMorePages:(BOOL)hasMorePages
          fontSize:(float)fontSize;
// the table must already hold a row; the view must be in its window
- (void)adoptLayoutOfTableView:(NSTableView *)tableView;
- (NSSize)preferredSize;
- (CGFloat)leftOfColumn:(NSUInteger)column;
- (void)setClickable:(BOOL)flag;
- (void)setTarget:(id)target action:(SEL)action;
- (NSInteger)clickedColumn;
- (NSInteger)clickedRow;
@end

@interface CVVerticalCandidateController : NSWindowController {
  IBOutlet id _scrollView;
  IBOutlet CVFloatingTableView *_tableView;
  IBOutlet NSTextField *_pageIndicatorTextField;
  IBOutlet NSTextField *_promptTextField;
  IBOutlet NSButton *_previousButton;
  IBOutlet NSButton *_nextButton;

  NSColor *_backgroundColor;
  NSColor *_foregroundColor;
  NSColor *_highlightTextColor;
  NSMutableArray *_candidateArray;
  PVVerticalCandidatePanel *_panel;
  float _width;
  float _fontHeight;

  BOOL _allowClick;
  BOOL _sending;

  float _candidateTextHeight;

  CVExpandedCandidateView *_expandedView;
  CGFloat _pageButtonOffset;
  CGFloat _collapsedTopGap;
}

- (void)setFontHeight:(float)newHeight;
- (void)updateContent:(PVVerticalCandidatePanel *)panel
              atPoint:(NSPoint)position;
- (void)hide;

- (void)setCandidateTextHeight:(float)inTextHeight;

#pragma mark Interface Builder actions

/*!
        @method	sendKey:
        @abstract Raises a keyboard event and send a key code as
        simulating a key is pressed down.
        @param sender The Sender Object.
*/
- (IBAction)sendKey:(id)sender;
- (IBAction)updateSelectedCandidate:(id)sender;
- (IBAction)gotoNextPage:(id)sender;
- (IBAction)gotoPreviousPage:(id)sender;
@end
