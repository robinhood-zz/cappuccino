
/*
 * CPTextField.j
 * AppKit
 *
 * Created by Francisco Tolmasky.
 * Copyright 2008, 280 North, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import "CPControl.j"
@import "CPStringDrawing.j"
@import "CPCompatibility.j"

#include "CoreGraphics/CGGeometry.h"
#include "Platform/Platform.h"
#include "Platform/DOM/CPDOMDisplayServer.h"


/*
    @global
    @group CPLineBreakMode
*/
CPLineBreakByWordWrapping       = 0;
/*
    @global
    @group CPLineBreakMode
*/
CPLineBreakByCharWrapping       = 1;
/*
    @global
    @group CPLineBreakMode
*/
CPLineBreakByClipping           = 2;
/*
    @global
    @group CPLineBreakMode
*/
CPLineBreakByTruncatingHead     = 3;
/*
    @global
    @group CPLineBreakMode
*/
CPLineBreakByTruncatingTail     = 4;
/*
    @global
    @group CPLineBreakMode
*/
CPLineBreakByTruncatingMiddle   = 5;

/*
    A textfield bezel with a squared corners.
	@global
	@group CPTextFieldBezelStyle
*/
CPTextFieldSquareBezel          = 0;
/*
    A textfield bezel with rounded corners.
	@global
	@group CPTextFieldBezelStyle
*/
CPTextFieldRoundedBezel         = 1;


#if PLATFORM(DOM)

var CPTextFieldDOMInputElement = nil,
    CPTextFieldDOMPasswordInputElement = nil,
    CPTextFieldDOMStandardInputElement = nil,
    CPTextFieldInputOwner = nil,
    CPTextFieldTextDidChangeValue = nil,
    CPTextFieldInputResigning = NO,
    CPTextFieldInputDidBlur = NO,
    CPTextFieldInputIsActive = NO,
    CPTextFieldCachedSelectStartFunction = nil,
    CPTextFieldCachedDragFunction = nil,
    
    CPTextFieldBlurFunction = nil,
    CPTextFieldKeyUpFunction = nil,
    CPTextFieldKeyPressFunction = nil,
    CPTextFieldKeyDownFunction = nil;
    
#endif

var CPSecureTextFieldCharacter = "\u2022";

@implementation CPString (CPTextFieldAdditions)

/*!
    Returns the string (\c self).
*/
- (CPString)string
{
    return self;
}

@end

CPTextFieldStateRounded     = CPThemeState("rounded");
CPTextFieldStatePlaceholder = CPThemeState("placeholder");

/*!
    @ingroup appkit
    This control displays editable text in a Cappuccino application.
*/
@implementation CPTextField : CPControl
{
    BOOL                    _isEditable;
    BOOL                    _isSelectable;
    BOOL                    _isSecure;

    BOOL                    _drawsBackground;
    
    CPColor                 _textFieldBackgroundColor;
    
    id                      _placeholderString;
    
    id                      _delegate;
    
    CPString                _textDidChangeValue;

    // NS-style Display Properties
    CPTextFieldBezelStyle   _bezelStyle;
    BOOL                    _isBordered;
    CPControlSize           _controlSize;
}

+ (CPTextField)textFieldWithStringValue:(CPString)aStringValue placeholder:(CPString)aPlaceholder width:(float)aWidth
{
    return [self textFieldWithStringValue:aStringValue placeholder:aPlaceholder width:aWidth theme:[CPTheme defaultTheme]];
}

+ (CPTextField)textFieldWithStringValue:(CPString)aStringValue placeholder:(CPString)aPlaceholder width:(float)aWidth theme:(CPTheme)aTheme
{
    var textField = [[self alloc] initWithFrame:CGRectMake(0.0, 0.0, aWidth, 29.0)];

    [textField setTheme:aTheme];
    [textField setStringValue:aStringValue];
    [textField setPlaceholderString:aPlaceholder];
    [textField setBordered:YES];
    [textField setBezeled:YES];
    [textField setEditable:YES];

    [textField sizeToFit];

    return textField;
}

+ (CPTextField)roundedTextFieldWithStringValue:(CPString)aStringValue placeholder:(CPString)aPlaceholder width:(float)aWidth
{
    return [self roundedTextFieldWithStringValue:aStringValue placeholder:aPlaceholder width:aWidth theme:[CPTheme defaultTheme]];
}

+ (CPTextField)roundedTextFieldWithStringValue:(CPString)aStringValue placeholder:(CPString)aPlaceholder width:(float)aWidth theme:(CPTheme)aTheme
{
    var textField = [[CPTextField alloc] initWithFrame:CGRectMake(0.0, 0.0, aWidth, 29.0)];

    [textField setTheme:aTheme];
    [textField setStringValue:aStringValue];
    [textField setPlaceholderString:aPlaceholder];
    [textField setBezelStyle:CPTextFieldRoundedBezel];
    [textField setBordered:YES];
    [textField setBezeled:YES];
    [textField setEditable:YES];

    [textField sizeToFit];

    return textField;
}

+ (CPTextField)labelWithTitle:(CPString)aTitle
{
    return [self labelWithTitle:aTitle theme:[CPTheme defaultTheme]];
}

+ (CPTextField)labelWithTitle:(CPString)aTitle theme:(CPTheme)aTheme
{
    var textField = [[self alloc] init];

    [textField setStringValue:aTitle];
    [textField sizeToFit];

    return textField;
}

+ (CPString)themeClass
{
    return "textfield";
}

+ (id)themeAttributes
{
    return [CPDictionary dictionaryWithObjects:[_CGInsetMakeZero(), _CGInsetMake(2.0, 2.0, 2.0, 2.0), nil]
                                       forKeys:[@"bezel-inset", @"content-inset", @"bezel-color"]];
}

/* @ignore */
#if PLATFORM(DOM)
- (DOMElement)_inputElement
{
    if (!CPTextFieldDOMInputElement)
    {
        CPTextFieldDOMInputElement = document.createElement("input");
        CPTextFieldDOMInputElement.style.position = "absolute";
        CPTextFieldDOMInputElement.style.border = "0px";
        CPTextFieldDOMInputElement.style.padding = "0px";
        CPTextFieldDOMInputElement.style.margin = "0px";
        CPTextFieldDOMInputElement.style.whiteSpace = "pre";
        CPTextFieldDOMInputElement.style.background = "transparent";
        CPTextFieldDOMInputElement.style.outline = "none";

        CPTextFieldBlurFunction = function(anEvent)
        {
            if (CPTextFieldInputOwner && CPTextFieldInputOwner._DOMElement != CPTextFieldDOMInputElement.parentNode)
                return;

            if (!CPTextFieldInputResigning)
            {
                [[CPTextFieldInputOwner window] makeFirstResponder:nil];
                return;
            }

            CPTextFieldHandleBlur(anEvent, CPTextFieldDOMInputElement);
            CPTextFieldInputDidBlur = YES;

            return true;
        }

        CPTextFieldKeyDownFunction = function(aDOMEvent)
        {
            CPTextFieldTextDidChangeValue = [CPTextFieldInputOwner stringValue];

            aDOMEvent = aDOMEvent || window.event;

            if (aDOMEvent.keyCode == CPReturnKeyCode || aDOMEvent.keyCode == CPTabKeyCode) 
                CPTextFieldKeyPressFunction(aDOMEvent);

            return true;
        }

        CPTextFieldKeyPressFunction = function(aDOMEvent)
        {
            aDOMEvent = aDOMEvent || window.event;

            CPTextFieldKeyUpFunction();

            if (aDOMEvent.keyCode == CPReturnKeyCode || aDOMEvent.keyCode == CPTabKeyCode) 
            {
                if (aDOMEvent.preventDefault)
                    aDOMEvent.preventDefault(); 
                if (aDOMEvent.stopPropagation)
                    aDOMEvent.stopPropagation();
                aDOMEvent.cancelBubble = true;

                var owner = CPTextFieldInputOwner;

                if (aDOMEvent && aDOMEvent.keyCode == CPReturnKeyCode)
                {
                    [owner sendAction:[owner action] to:[owner target]];
                    [owner selectText:nil];
                }
                else if (aDOMEvent && aDOMEvent.keyCode == CPTabKeyCode)
                {
                    if (!aDOMEvent.shiftKey)
                        [[owner window] selectNextKeyView:owner];
                    else
                        [[owner window] selectPreviousKeyView:owner];
                }
            }

            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        }

        CPTextFieldKeyUpFunction = function()
        {
            [CPTextFieldInputOwner _setStringValue:CPTextFieldDOMInputElement.value];

            if ([CPTextFieldInputOwner stringValue] !== CPTextFieldTextDidChangeValue)
            {
                [CPTextFieldInputOwner textDidChange:[CPNotification notificationWithName:CPControlTextDidChangeNotification object:CPTextFieldInputOwner userInfo:nil]];
                CPTextFieldTextDidChangeValue = [CPTextFieldInputOwner stringValue];
            }

            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        }

        CPTextFieldHandleBlur = function(anEvent)
        {            
            var owner = CPTextFieldInputOwner;
            CPTextFieldInputOwner = nil;

            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        }

        if (document.attachEvent)
        {
            CPTextFieldDOMInputElement.attachEvent("on" + CPDOMEventKeyUp, CPTextFieldKeyUpFunction);
            CPTextFieldDOMInputElement.attachEvent("on" + CPDOMEventKeyDown, CPTextFieldKeyDownFunction);
            CPTextFieldDOMInputElement.attachEvent("on" + CPDOMEventKeyPress, CPTextFieldKeyPressFunction);
        }
        else
        {
            CPTextFieldDOMInputElement.addEventListener(CPDOMEventKeyUp, CPTextFieldKeyUpFunction, NO);
            CPTextFieldDOMInputElement.addEventListener(CPDOMEventKeyDown, CPTextFieldKeyDownFunction, NO);
            CPTextFieldDOMInputElement.addEventListener(CPDOMEventKeyPress, CPTextFieldKeyPressFunction, NO);
        }

        //FIXME make this not onblur
        CPTextFieldDOMInputElement.onblur = CPTextFieldBlurFunction;
        
        CPTextFieldDOMStandardInputElement = CPTextFieldDOMInputElement;
    }
    
    if (CPFeatureIsCompatible(CPInputTypeCanBeChangedFeature))
    {
        if ([self isSecure])
            CPTextFieldDOMInputElement.type = "password";
        else
            CPTextFieldDOMInputElement.type = "text";

        return CPTextFieldDOMInputElement;
    }

    if ([self isSecure])
    {
        if (!CPTextFieldDOMPasswordInputElement)
        {
            CPTextFieldDOMPasswordInputElement = document.createElement("input");
            CPTextFieldDOMPasswordInputElement.style.position = "absolute";
            CPTextFieldDOMPasswordInputElement.style.border = "0px";
            CPTextFieldDOMPasswordInputElement.style.padding = "0px";
            CPTextFieldDOMPasswordInputElement.style.margin = "0px";
            CPTextFieldDOMPasswordInputElement.style.whiteSpace = "pre";
            CPTextFieldDOMPasswordInputElement.style.background = "transparent";
            CPTextFieldDOMPasswordInputElement.style.outline = "none";
            CPTextFieldDOMPasswordInputElement.type = "password";

            CPTextFieldDOMPasswordInputElement.attachEvent("on" + CPDOMEventKeyUp, CPTextFieldKeyUpFunction);
            CPTextFieldDOMPasswordInputElement.attachEvent("on" + CPDOMEventKeyDown, CPTextFieldKeyDownFunction);
            CPTextFieldDOMPasswordInputElement.attachEvent("on" + CPDOMEventKeyPress, CPTextFieldKeyPressFunction);

            CPTextFieldDOMPasswordInputElement.onblur = CPTextFieldBlurFunction;
        }
        
        CPTextFieldDOMInputElement = CPTextFieldDOMPasswordInputElement;
    }
    else
    {
        CPTextFieldDOMInputElement = CPTextFieldDOMStandardInputElement;
    }
    
    return CPTextFieldDOMInputElement;
}
#endif

- (id)initWithFrame:(CGRect)aFrame
{
    self = [super initWithFrame:aFrame];

    if (self)
    {
        [self setStringValue:@""];
        [self setPlaceholderString:@""];

        _sendActionOn = CPKeyUpMask | CPKeyDownMask;

        [self setValue:CPLeftTextAlignment forThemeAttribute:@"alignment"];
    }
    
    return self;
}

#pragma mark Controlling Editability and Selectability

/*! 
    Sets whether or not the receiver text field can be edited
*/
- (void)setEditable:(BOOL)shouldBeEditable
{
    _isEditable = shouldBeEditable;
}

/*!
    Returns \c YES if the textfield is currently editable by the user.
*/
- (BOOL)isEditable
{
    return _isEditable;
}

/*!
    Sets whether the field's text is selectable by the user.
    @param aFlag \c YES makes the text selectable
*/
- (void)setSelectable:(BOOL)aFlag
{
    _isSelectable = aFlag;
}

/*!
    Returns \c YES if the field's text is selectable by the user.
*/
- (BOOL)isSelectable
{
    return _isSelectable;
}

/*!
    Sets whether the field's text is secure.
    @param aFlag \c YES makes the text secure
*/
- (void)setSecure:(BOOL)aFlag
{
    _isSecure = aFlag;
}

/*!
    Returns \c YES if the field's text is secure (password entry).
*/
- (BOOL)isSecure
{
    return _isSecure;
}

// Setting the Bezel Style
/*!
    Sets whether the textfield will have a bezeled border.
    @param shouldBeBezeled \c YES means the textfield will draw a bezeled border
*/
- (void)setBezeled:(BOOL)shouldBeBezeled
{
    if (shouldBeBezeled)
        [self setThemeState:CPThemeStateBezeled];
    else
        [self unsetThemeState:CPThemeStateBezeled];
}

/*!
    Returns \c YES if the textfield draws a bezeled border.
*/
- (BOOL)isBezeled
{
    return [self hasThemeState:CPThemeStateBezeled];
}

/*!
    Sets the textfield's bezel style.
    @param aBezelStyle the constant for the desired bezel style
*/
- (void)setBezelStyle:(CPTextFieldBezelStyle)aBezelStyle
{
    var shouldBeRounded = aBezelStyle === CPTextFieldRoundedBezel;
    
    if (shouldBeRounded)
        [self setThemeState:CPTextFieldStateRounded];
    else
        [self unsetThemeState:CPTextFieldStateRounded];
}

/*!
    Returns the textfield's bezel style.
*/
- (CPTextFieldBezelStyle)bezelStyle
{
    if ([self hasThemeState:CPTextFieldStateRounded])
        return CPTextFieldRoundedBezel;

    return CPTextFieldSquareBezel;
}

/*!
    Sets whether the textfield will have a border drawn.
    @param shouldBeBordered \c YES makes the textfield draw a border
*/
- (void)setBordered:(BOOL)shouldBeBordered
{
    if (shouldBeBordered)
        [self setThemeState:CPThemeStateBordered];
    else
        [self unsetThemeState:CPThemeStateBordered];
}

/*!
    Returns \c YES if the textfield has a border.
*/
- (BOOL)isBordered
{
    return [self hasThemeState:CPThemeStateBordered];
}

/*!
    Sets whether the textfield will have a background drawn.
    @param shouldDrawBackground \c YES makes the textfield draw a background
*/
- (void)setDrawsBackground:(BOOL)shouldDrawBackground
{
    if (_drawsBackground == shouldDrawBackground)
        return;
        
    _drawsBackground = shouldDrawBackground;
    
    [self setNeedsLayout];
    [self setNeedsDisplay:YES];
}

/*!
    Returns \c YES if the textfield draws a background.
*/
- (BOOL)drawsBackground
{
    return _drawsBackground;
}

/*!
    Sets the background color, which is shown for non-bezeled text fields with drawsBackground set to YES
    @param aColor The background color
*/
- (void)setTextFieldBackgroundColor:(CPColor)aColor
{
    if (_textFieldBackgroundColor == aColor)
        return;
        
    _textFieldBackgroundColor = aColor;
    
    [self setNeedsLayout];
    [self setNeedsDisplay:YES];
}

/*!
    Returns the background color.
*/
- (CPColor)textFieldBackgroundColor
{
    return _textFieldBackgroundColor;
}

/* @ignore */
- (BOOL)acceptsFirstResponder
{
    return [self isEditable] && [self isEnabled];
}

/* @ignore */
- (BOOL)becomeFirstResponder
{
#if PLATFORM(DOM)
    if (CPTextFieldInputOwner && [CPTextFieldInputOwner window] !== [self window])
        [[CPTextFieldInputOwner window] makeFirstResponder:nil];
#endif

    [self setThemeState:CPThemeStateEditing];

    [self _updatePlaceholderState];

    [self setNeedsLayout];

#if PLATFORM(DOM)

    var string = [self stringValue],
        element = [self _inputElement];

    element.value = string;
    element.style.color = [[self currentValueForThemeAttribute:@"text-color"] cssString];
    element.style.font = [[self currentValueForThemeAttribute:@"font"] cssString];
    element.style.zIndex = 1000;

    switch ([self alignment])
    {
        case CPCenterTextAlignment: element.style.textAlign = "center";
                                    break;
        case CPRightTextAlignment:  element.style.textAlign = "right";
                                    break;
        default:                    element.style.textAlign = "left";
    }

    var contentRect = [self contentRectForBounds:[self bounds]];

    element.style.top = _CGRectGetMinY(contentRect) + "px";
    element.style.left = (_CGRectGetMinX(contentRect) - 1) + "px"; // why -1?
    element.style.width = _CGRectGetWidth(contentRect) + "px";
    element.style.height = _CGRectGetHeight(contentRect) + "px";

    _DOMElement.appendChild(element);

    window.setTimeout(function() 
    { 
        element.focus();
        CPTextFieldInputOwner = self;
    }, 0.0);
 
    //post CPControlTextDidBeginEditingNotification
    [self textDidBeginEditing:[CPNotification notificationWithName:CPControlTextDidBeginEditingNotification object:self userInfo:nil]];
    element.value = [self stringValue];

    [[[self window] platformWindow] _propagateCurrentDOMEvent:YES];
    
    CPTextFieldInputIsActive = YES;

    if (document.attachEvent)
    {
        CPTextFieldCachedSelectStartFunction = document.body.onselectstart;
        CPTextFieldCachedDragFunction = document.body.ondrag;
        
        document.body.ondrag = function () {};
        document.body.onselectstart = function () {};
    }
    
#endif

    return YES;
}

/* @ignore */
- (BOOL)resignFirstResponder
{
    [self unsetThemeState:CPThemeStateEditing];

    [self _updatePlaceholderState];

    [self setNeedsLayout];

#if PLATFORM(DOM)

    var element = [self _inputElement];

    [self setObjectValue:element.value];

    CPTextFieldInputResigning = YES;
    element.blur();
    
    if (!CPTextFieldInputDidBlur)
        CPTextFieldBlurFunction();
    
    CPTextFieldInputDidBlur = NO;
    CPTextFieldInputResigning = NO;

    if (element.parentNode == _DOMElement)
        element.parentNode.removeChild(element);

    CPTextFieldInputIsActive = NO;

    if (document.attachEvent)
    {
        CPTextFieldCachedSelectStartFunction = nil;
        CPTextFieldCachedDragFunction = nil;
        
        document.body.ondrag = CPTextFieldCachedDragFunction
        document.body.onselectstart = CPTextFieldCachedSelectStartFunction
    }
    
#endif

    //post CPControlTextDidEndEditingNotification
    [self textDidEndEditing:[CPNotification notificationWithName:CPControlTextDidEndEditingNotification object:self userInfo:nil]];

    if ([self sendsActionOnEndEditing])
        [self sendAction:[self action] to:[self target]];    

    return YES;
}

- (void)mouseDown:(CPEvent)anEvent
{
    // Don't track! (ever?)
    if ([self isEditable] && [self isEnabled])
        return [[self window] makeFirstResponder:self];
    else
        return [[self nextResponder] mouseDown:anEvent];
}

/*!
    Returns the string the text field.
*/
- (id)objectValue
{
    return [super objectValue];
}

/*
    @ignore
*/
- (void)_setStringValue:(id)aValue
{
    [super setObjectValue:String(aValue)];
    [self _updatePlaceholderState];
}

- (void)setObjectValue:(id)aValue
{
    [super setObjectValue:aValue];

#if PLATFORM(DOM)
    if (CPTextFieldInputOwner === self)
        [self _inputElement].value = aValue;
#endif

    [self _updatePlaceholderState];
}

- (void)_updatePlaceholderState
{
    var string = [self stringValue];

    if ((!string || string.length === 0) && ![self hasThemeState:CPThemeStateEditing])
        [self setThemeState:CPTextFieldStatePlaceholder];
    else
        [self unsetThemeState:CPTextFieldStatePlaceholder];
}

/*!
    Sets a placeholder string for the receiver.  The placeholder is displayed until editing begins,
    and after editing ends, if the text field has an empty string value
*/
-(void)setPlaceholderString:(CPString)aStringValue
{
    if (_placeholderString === aStringValue)
        return;
    
    _placeholderString = aStringValue;

    // Only update things if we need to show the placeholder
    if ([self hasThemeState:CPTextFieldStatePlaceholder])
    {
        [self setNeedsLayout];
        [self setNeedsDisplay:YES];
    }
}

/*!
    Returns the receiver's placeholder string
*/
- (CPString)placeholderString
{
    return _placeholderString;
}

/*!
    Size to fit has two behavior, depending on if the receiver is an editable text field or not.
    
    For non-editable text fields (typically, a label), sizeToFit will change the frame of the 
    receiver to perfectly fit the current text in stringValue in the current font, and respecting
    the current theme values for content-inset, min-size, and max-size.
    
    For editable text fields, sizeToFit will ONLY change the HEIGHT of the text field. It will not 
    change the width of the text field. You can use setFrameSize: with the current height to set the 
    width, and you can get the size of a string with [CPString sizeWithFont:]. 
    
    The logic behind this decision is that most of the time you do not know what content will be placed
    in an editable text field, so you want to just choose a fixed width and leave it at that size. 
    However, since you don't know how tall it needs to be if you change the font, sizeToFit will still be
    useful for making the textfield an appropriate height.
*/

- (void)sizeToFit
{
    var size = [([self stringValue] || " ") sizeWithFont:[self currentValueForThemeAttribute:@"font"]],
        contentInset = [self currentValueForThemeAttribute:@"content-inset"],
        minSize = [self currentValueForThemeAttribute:@"min-size"],
        maxSize = [self currentValueForThemeAttribute:@"max-size"];

    size.width = MAX(size.width + contentInset.left + contentInset.right, minSize.width);
    size.height = MAX(size.height + contentInset.top + contentInset.bottom, minSize.height);

    if (maxSize.width >= 0.0)
        size.width = MIN(size.width, maxSize.width);

    if (maxSize.height >= 0.0)
        size.height = MIN(size.height, maxSize.height);

    if ([self isEditable])
        size.width = CGRectGetWidth([self frame]);

    [self setFrameSize:size];
}

/*!
    Select all the text in the CPTextField.
*/
- (void)selectText:(id)sender
{
#if PLATFORM(DOM)
    var element = [self _inputElement];
    
    if (element.parentNode === _DOMElement && ([self isEditable] || [self isSelectable]))
        window.setTimeout(function() { element.select(); }, 0);
#endif
}

#pragma mark Setting the Delegate

- (void)setDelegate:(id)aDelegate
{
    var defaultCenter = [CPNotificationCenter defaultCenter];
    
    //unsubscribe the existing delegate if it exists
    if (_delegate)
    {
        [defaultCenter removeObserver:_delegate name:CPControlTextDidBeginEditingNotification object:self];
        [defaultCenter removeObserver:_delegate name:CPControlTextDidChangeNotification object:self];
        [defaultCenter removeObserver:_delegate name:CPControlTextDidEndEditingNotification object:self];
    }
    
    _delegate = aDelegate;
    
    if ([_delegate respondsToSelector:@selector(controlTextDidBeginEditing:)])
        [defaultCenter
            addObserver:_delegate
               selector:@selector(controlTextDidBeginEditing:)
                   name:CPControlTextDidBeginEditingNotification
                 object:self];
    
    if ([_delegate respondsToSelector:@selector(controlTextDidChange:)])
        [defaultCenter
            addObserver:_delegate
               selector:@selector(controlTextDidChange:)
                   name:CPControlTextDidChangeNotification
                 object:self];
    
    
    if ([_delegate respondsToSelector:@selector(controlTextDidEndEditing:)])
        [defaultCenter
            addObserver:_delegate
               selector:@selector(controlTextDidEndEditing:)
                   name:CPControlTextDidEndEditingNotification
                 object:self];

}

- (id)delegate
{
    return _delegate;
}

- (CGRect)contentRectForBounds:(CGRect)bounds
{
    var contentInset = [self currentValueForThemeAttribute:@"content-inset"];
    
    if (!contentInset)
        return bounds;
    
    bounds.origin.x += contentInset.left;
    bounds.origin.y += contentInset.top;
    bounds.size.width -= contentInset.left + contentInset.right;
    bounds.size.height -= contentInset.top + contentInset.bottom;
    
    return bounds;
}

- (CGRect)bezelRectForBounds:(CFRect)bounds
{
    var bezelInset = [self currentValueForThemeAttribute:@"bezel-inset"];

    if (_CGInsetIsEmpty(bezelInset))
        return bounds;
    
    bounds.origin.x += bezelInset.left;
    bounds.origin.y += bezelInset.top;
    bounds.size.width -= bezelInset.left + bezelInset.right;
    bounds.size.height -= bezelInset.top + bezelInset.bottom;
    
    return bounds;
}

- (CGRect)rectForEphemeralSubviewNamed:(CPString)aName
{
    if (aName === "bezel-view")
        return [self bezelRectForBounds:[self bounds]];
    
    else if (aName === "content-view")
        return [self contentRectForBounds:[self bounds]];
    
    return [super rectForEphemeralSubviewNamed:aName];
}

- (CPView)createEphemeralSubviewNamed:(CPString)aName
{
    if (aName === "bezel-view")
    {
        var view = [[CPView alloc] initWithFrame:_CGRectMakeZero()];

        [view setHitTests:NO];
        
        return view;
    }
    else
    {
        var view = [[_CPImageAndTextView alloc] initWithFrame:_CGRectMakeZero()];
        //[view setImagePosition:CPNoImage];
        
        return view;
    }
    
    return [super createEphemeralSubviewNamed:aName];
}

- (void)layoutSubviews
{
    var bezelView = [self layoutEphemeralSubviewNamed:@"bezel-view"
                                           positioned:CPWindowBelow
                      relativeToEphemeralSubviewNamed:@"content-view"];
      
    if (bezelView)
        [bezelView setBackgroundColor:[self currentValueForThemeAttribute:@"bezel-color"]];
    
    var contentView = [self layoutEphemeralSubviewNamed:@"content-view"
                                             positioned:CPWindowAbove
                        relativeToEphemeralSubviewNamed:@"bezel-view"];

    if (contentView)
    {
        [contentView setHidden:[self hasThemeState:CPThemeStateEditing]];

        var string = "";
        
        if ([self hasThemeState:CPTextFieldStatePlaceholder])
            string = [self placeholderString];
        else
        {
            string = [self stringValue];

            if ([self isSecure])
                string = secureStringForString(string);
        }

        [contentView setText:string];

        [contentView setTextColor:[self currentValueForThemeAttribute:@"text-color"]];
        [contentView setFont:[self currentValueForThemeAttribute:@"font"]];
        [contentView setAlignment:[self currentValueForThemeAttribute:@"alignment"]];
        [contentView setVerticalAlignment:[self currentValueForThemeAttribute:@"vertical-alignment"]];
        [contentView setLineBreakMode:[self currentValueForThemeAttribute:@"line-break-mode"]];
        [contentView setTextShadowColor:[self currentValueForThemeAttribute:@"text-shadow-color"]];
        [contentView setTextShadowOffset:[self currentValueForThemeAttribute:@"text-shadow-offset"]];
    }
}

@end

var secureStringForString = function(aString)
{
    // This is true for when aString === "" and null/undefined.
    if (!aString)
        return "";
    return Array(aString.length).join(CPSecureTextFieldCharacter);
}


var CPTextFieldIsEditableKey            = "CPTextFieldIsEditableKey",
    CPTextFieldIsSelectableKey          = "CPTextFieldIsSelectableKey",
    CPTextFieldIsBorderedKey            = "CPTextFieldIsBorderedKey",
    CPTextFieldIsBezeledKey             = "CPTextFieldIsBezeledKey",
    CPTextFieldBezelStyleKey            = "CPTextFieldBezelStyleKey",
    CPTextFieldDrawsBackgroundKey       = "CPTextFieldDrawsBackgroundKey",
    CPTextFieldLineBreakModeKey         = "CPTextFieldLineBreakModeKey",
    CPTextFieldBackgroundColorKey       = "CPTextFieldBackgroundColorKey",
    CPTextFieldPlaceholderStringKey     = "CPTextFieldPlaceholderStringKey";

@implementation CPTextField (CPCoding)

/*!
    Initializes the textfield with data from a coder.
    @param aCoder the coder from which to read the textfield data
    @return the initialized textfield
*/
- (id)initWithCoder:(CPCoder)aCoder
{
    self = [super initWithCoder:aCoder];
    
    if (self)
    {
        [self setEditable:[aCoder decodeBoolForKey:CPTextFieldIsEditableKey]];
        [self setSelectable:[aCoder decodeBoolForKey:CPTextFieldIsSelectableKey]];

        [self setDrawsBackground:[aCoder decodeBoolForKey:CPTextFieldDrawsBackgroundKey]];

        [self setTextFieldBackgroundColor:[aCoder decodeObjectForKey:CPTextFieldBackgroundColorKey]];

        [self setPlaceholderString:[aCoder decodeObjectForKey:CPTextFieldPlaceholderStringKey]];
    }
    
    return self;
}

/*!
    Encodes the data of this textfield into the provided coder.
    @param aCoder the coder into which the data will be written
*/
- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];
    
    [aCoder encodeBool:_isEditable forKey:CPTextFieldIsEditableKey];
    [aCoder encodeBool:_isSelectable forKey:CPTextFieldIsSelectableKey];
    
    [aCoder encodeBool:_drawsBackground forKey:CPTextFieldDrawsBackgroundKey];
    
    [aCoder encodeObject:_textFieldBackgroundColor forKey:CPTextFieldBackgroundColorKey];
    
    [aCoder encodeObject:_placeholderString forKey:CPTextFieldPlaceholderStringKey];
}

@end

