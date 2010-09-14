/*******************************************************************************************************************

=head1 NAME

DynamicPreviewPane.js: continuously updated preview area with text taken from a specified form field and custom-processed

=head1 SYNOPSIS

The DynamicPreviewPane object acts as a namespace.

Field names starting with underscores are internal.

Dependencies: MochiKit.

=head1 AUTHOR

Evan Herbst

Updated 1 / 11 / 07

=head1 DESCRIPTION

=head2 Functions

=over 3

=cut
*******************************************************************************************************************/

//include required modules
//tried doing this with an array of strings for module names; no idea why that doesn't go -- Evan
if(typeof(JSAN) != 'undefined')
{
	JSAN.use("MochiKit.DOM", []);
	JSAN.use("MochiKit.Signal", []);
}
try //assume that each required module X.Y creates an object named X.Y
{
	if(typeof MochiKit.DOM == 'undefined') throw '';
	if(typeof MochiKit.Signal == 'undefined') throw '';
}
catch(x)
{
	throw "DynamicPreviewPane requires the following modules: MochiKit.DOM, MochiKit.Signal";
}


DynamicPreviewPane =
{

//internal constants
_styleTagClass: 'dynamic_previewpane_styles',
_previewPaneClass: 'dynamic_preview_pane',

//internal variables
_pane2sourceID: {}, //map preview-pane element IDs to their source IDs
_pane2sourceType: {}, //map preview-pane element IDs to the content types of their sources

/*

=item _getDocumentHead ()

return the HEAD node in the current document

=cut
*/
_getDocumentHead: function()
{
	return MochiKit.DOM.getFirstElementByTagAndClassName('head', null);
},

/*

=item _styleText ()

return a string with all the CSS required by this library

=cut
*/
_styleText: function()
{
	return 'div.' + this._previewPaneClass + ' {border: 1px solid #888}';
},

/*

=item _includePreviewPaneStyles ()

add a STYLE element with our CSS to the HEAD of the current document,
unless there's already a STYLE with the class name this library uses

=cut
*/
_includePreviewPaneStyles: function()
{
	var head = this._getDocumentHead();
	var ourStyles = MochiKit.DOM.getFirstElementByTagAndClassName('style', this._styleTagClass, head);
	if(ourStyles == null)
	{
		var styleNode = MochiKit.DOM.createDOM('style', {'type': 'text/css', 'class': this._styleTagClass}, this._styleText());
		head.appendChild(styleNode);
	}
},

/********************************************************************************************
* CONVERSION FUNCTIONS FOR VARIOUS SOURCE TYPES
********************************************************************************************/

//match info for source types
HTML: 'html',
DELIMITED_LIST: 'list',
_DELIMITED_LIST_REGEXP: null, //allow for specification of list delimiters as 'list(DELIMITERS)'

/*

=item _convertHTML ()

convert text from an HTML source according to SGN's HTML input rules and
return the resulting string

Arguments:
   sourceHTML - input string

=cut
*/
_convertHTML: function(sourceHTML)
{
/*
[Koni]
# Quick, dirty hack method of defenestrating disallowed HTML tags in 
# research interest statements: replace allowed tags with a marker string,
# then delete all tokens of the form "<[^>]+>", then replace the marker string
# with the original tag. 
#
# Using the marker string allows us to "save" the information about the tag
# that is allowed -- changing it to a token that won't match the "<[^>]+>"
# pattern. Using a random marker string prevents a user learning (through a
# website error or something that reveals a static marker string) the marker
# and trying to insert illegal tags by typing the marker into their statement
# manually. This is further guarded against by only recognizing marker strings
# with allowed tags encoded. (Yes, I am paranoid)
#
# The main problem with this is if someone happens to use both a literal "<"
# and a matching ">" in their research statement -- if that happens, the
# text flanked by these will be deleted -- they'll need to use &lt; and &gt;
# instead.

Update: removed randomly generated marker string as unnecessary -- Evan
*/
	sourceHTML = sourceHTML.replace(/<(\/?)([pbi]|br)>/g, "%%$1-$2-MARKER%%"); //just hope nobody actually uses text with this format
	sourceHTML = sourceHTML.replace(/\<[^>]+\>/g, ""); //remove all disallowed tags
	sourceHTML = sourceHTML.replace(/%%(\/?)-([pbi]|br)-MARKER%%/g, "<$1$2>");
	return sourceHTML;
},

/*

=item _convertDelimitedList ()

convert text from a list source, inserting newlines instead of delimiters for nice online display

Arguments:
   delimiters - list of delimiting characters
   sourceText - input string
	
=cut
*/
_convertDelimitedList: function(delimiters, sourceText)
{
	var regexp = new RegExp("[" + delimiters + "]+", "g");
	sourceText = sourceText.replace(regexp, "<br />");
	return sourceText;
},

/*

=item _getConversionFunctorForSourceType ()

return a functor whose apply() function takes one argument, the text to be converted

Arguments:
   sourceType - content type to be processed by the returned functor
	
=cut
*/
_getConversionFunctorForSourceType: function(sourceType)
{
	//DynamicPreviewPane initialization
	if(this._DELIMITED_LIST_REGEXP == null)
		this._DELIMITED_LIST_REGEXP = new RegExp(this.DELIMITED_LIST + '\\((.*)\\)', '');

	if(sourceType == this.HTML) return this._convertHTML;
	var matchInfo = sourceType.match(this._DELIMITED_LIST_REGEXP);
	//if the match was successful, matchInfo is an array with matched subexpressions starting at index 1
	if(matchInfo != null) return function(sourceText) {return DynamicPreviewPane._convertDelimitedList(matchInfo[1], sourceText);}
	alert("DynamicPreviewPane can't find conversion function for unknown source type '" + sourceType + "'");
},

/*

=item _updatePreviewPane ()

will be called with 'this' having the properties of the preview pane element
(as well as possibly some others?)

Arguments:
   event - not sure, but I think that's what gets passed; its type prints as 'object'; anyway, it isn't used

update the preview pane to have the same text as its source(s), put through a custom processing function

=cut
*/
_updatePreviewPane: function(event)
{
	var textSource = MochiKit.DOM.getElement(DynamicPreviewPane._pane2sourceID[this.id]);
	var sourceType = DynamicPreviewPane._pane2sourceType[this.id];
	this.innerHTML = DynamicPreviewPane._getConversionFunctorForSourceType(sourceType)(textSource.value);
},

/*

=item createPreviewPane ()

Arguments:
   sourceType - a string describing the content type provided by the source; should be one of the DynamicPreviewPane constants
   textSourceID - an element that can use the 'onchange' event, such as an <input type=text> or a <textarea>
   paneParentID - the element under which the preview pane (a DIV) will be put

include the required CSS if it doesn't seem to be in the document already

=cut
*/
createPreviewPane: function(sourceType, textSourceID, paneParentID)
{
	//include our CSS only if it isn't already
	this._includePreviewPaneStyles();
	
	var paneParent = MochiKit.DOM.getElement(paneParentID);
	var previewPane = MochiKit.DOM.DIV({'class': this._previewPaneClass, 'id': textSourceID + '_src_preview_pane'}, ''); //give it an empty text node for a child so the child will exist
	this._pane2sourceID[previewPane.id] = textSourceID;
	this._pane2sourceType[previewPane.id] = sourceType;
	paneParent.appendChild(previewPane);
	MochiKit.Signal.connect(textSourceID, 'onkeyup', previewPane, this._updatePreviewPane);
	
	//initialize preview pane
	this._updatePreviewPane.apply(previewPane);
}

/*
=back

=cut
*/

}; //end HTMLPreviewPane
