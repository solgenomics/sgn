# do not remove the { } from the top and bottom of this page!!!
{

 CHARSET =>   'ISO-8859-1',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'Genome browser',

   SEARCH_INSTRUCTIONS => <<END,
Search using a sequence name, gene name,
locus%s, or other landmark. The wildcard
character * is allowed.
END

   NAVIGATION_INSTRUCTIONS => <<END,
To center on a location, click the ruler. Use the Scroll/Zoom buttons
to change magnification and position.
END

   EDIT_INSTRUCTIONS => <<END,
Edit your uploaded annotation data here.
You may use tabs or spaces to separate fields,
but fields that contain whitespace must be contained in
double or single quotes.
END

   SHOWING_FROM_TO => 'Showing %s from %s, positions %s to %s',

   INSTRUCTIONS      => 'Instructions',

   HIDE              => 'Hide',

   SHOW              => 'Show',

   SHOW_INSTRUCTIONS => 'Show instructions',

   HIDE_INSTRUCTIONS => 'Hide instructions',

   SHOW_HEADER       => 'Show banner',

   HIDE_HEADER       => 'Hide banner',

   LANDMARK => 'Landmark or Region',

   BOOKMARK => 'Bookmark this',

   IMAGE_LINK => 'Link to Image',

   SVG_LINK   => 'High-res Image',

   SVG_DESCRIPTION => <<END,
<p>
The following link will generate this image in Scalable Vector
Graphic (SVG) format.  SVG images offer several advantages over
raster based images such as jpeg or png.
</p>
<ul>
<li>fully resizable with no loss in resolution
<li>editable feature-by-feature in common vector-based graphics applications
<li>if necessary, can be converted to EPS for publication submission
</ul>
<p>
To view SVG images, you will need an SVG capable browser, the 
Adobe SVG browser plugin, or an SVG viewing or editing application such
as Adobe Illustrator.
</p>
<p>
Adobe's SVG browser plugin: <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>
<br />
Linux users may wish to explore the <a href="http://xml.apache.org/batik/">Batik SVG Viewer</a>.
</p>
<p>
<a href="%s" target="_blank">View SVG image in a new browser window</a></p>
<p>
To save this image to your disk, control-click (Macintosh) or
right-click (Windows) and select the option to save link to disk.
</p>   
END

   IMAGE_DESCRIPTION => <<END,
<p>
To create an embedded image of this view, cut and paste this
URL into an HTML page:
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
The image will look like this:
</p>
<p>
<img src="%s" />
</p>

<p>
If only the overview (chromosome or contig view) is showing, try
reducing the size of the region.
</p>
END

   TIMEOUT  => <<'END',
Your request timed out.  You may have selected a region that is too large to display.
Either turn off some tracks or try a smaller region.  If you are experiencing persistent
timeouts, please press the "Reset" button.
END

   GO       => 'Go',

   FIND     => 'Find',

   SEARCH   => 'Search',

   DUMP     => 'Download',

   HIGHLIGHT   => 'Highlight',

   ANNOTATE     => 'Annotate',

   SCROLL   => 'Scroll/Zoom',

   RESET    => 'Reset',

   FLIP     => 'Flip',

   DOWNLOAD_FILE    => 'Download File',

   DOWNLOAD_DATA    => 'Download Data',

   DOWNLOAD         => 'Download',

   DISPLAY_SETTINGS => 'Display Settings',

   TRACKS   => 'Tracks',

   EXTERNAL_TRACKS => '<i>External tracks italicized</i>',

   OVERVIEW_TRACKS => '<sup>*</sup>Overview track',

   REGION_TRACKS => '<sup>**</sup>Region track',

   EXAMPLES => 'Examples',

   REGION_SIZE => 'Region Size (bp)',

   HELP     => 'Help',

   HELP_FORMAT => 'Help with File Format',

   CANCEL   => 'Cancel',

   ABOUT    => 'About...',

   REDISPLAY   => 'Redisplay',

   CONFIGURE   => 'Configure...',

   CONFIGURE_TRACKS   => 'Configure tracks...',

   EDIT       => 'Edit File...',

   DELETE     => 'Delete File',

   EDIT_TITLE => 'Enter/Edit Annotation data',

   IMAGE_WIDTH => 'Image Width',

   BETWEEN     => 'Between',

   BENEATH     => 'Beneath',

   LEFT        => 'Left',

   RIGHT       => 'Right',

   TRACK_NAMES => 'Track Name Table',

   ALPHABETIC  => 'Alphabetic',

   VARYING     => 'Varying',

   SHOW_GRID    => 'Show grid',

   SET_OPTIONS => 'Configure tracks...',

   CLEAR_HIGHLIGHTING => 'Clear highlighting',

   UPDATE      => 'Update Image',

   DUMPS       => 'Reports &amp; Analysis',

   DATA_SOURCE => 'Data Source',

   UPLOAD_TRACKS=>'Add your own tracks',

   UPLOAD_TITLE=> 'Upload your own annotations',

   UPLOAD_FILE => 'Upload a file',

   KEY_POSITION => 'Key position',

   BROWSE      => 'Browse...',

   UPLOAD      => 'Upload',

   NEW         => 'New...',

   REMOTE_TITLE => 'Add remote annotations',

   REMOTE_URL   => 'Enter Remote Annotation URL',

   UPDATE_URLS  => 'Update URLs',

   PRESETS      => '--Choose Preset URL--',

   FEATURES_TO_HIGHLIGHT => 'Highlight feature(s) (feature1 feature2...)',

   REGIONS_TO_HIGHLIGHT => 'Highlight regions (region1:start..end region2:start..end)',

   FEATURES_TO_HIGHLIGHT_HINT => 'Hint: use feature@color to select the color, as in \'NUT21@lightblue\'',

   REGIONS_TO_HIGHLIGHT_HINT  => 'Hint: use region@color to select the color, as in \'Chr1:10000..20000@lightblue\'',

   NO_TRACKS    => '*none*',

   FILE_INFO    => 'Last modified %s.  Annotated landmarks: %s',

   FOOTER_1     => <<END,
Note: This page uses cookies to save and restore preference information.
No information is shared.
END

   FOOTER_2    => 'Generic genome browser version %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => 'The following %d regions match your request.',

   POSSIBLE_TRUNCATION  => 'Search results are limited to %d hits; list may be incomplete.',

   MATCHES_ON_REF => 'Matches on %s',

   SEQUENCE        => 'sequence',

   SCORE           => 'score=%s',

   NOT_APPLICABLE => 'n/a',

   BP             => 'bp',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => 'Settings for %s',

   UNDO     => 'Undo Changes',

   REVERT   => 'Revert to Defaults',

   REFRESH  => 'Refresh',

   CANCEL_RETURN   => 'Cancel Changes and Return...',

   ACCEPT_RETURN   => 'Accept Changes and Return...',

   OPTIONS_TITLE => 'Track Options',

   SETTINGS_INSTRUCTIONS => <<END,
The <i>Show</i> checkbox turns the track on and off. The
<i>Compact</i> option forces the track to be condensed so that
annotations will overlap. The <i>Expand</i> and <i>Hyperexpand</i>
options turn on collision control using slower and faster layout
algorithms. The <i>Expand</i> &amp; <i>label</i> and <i>Hyperexpand
&amp; label</i> options force annotations to be labeled. If
<i>Auto</i> is selected, the collision control and label options will
be set automatically if space permits. To change the track order use
the <i>Change Track Order</i> popup menu to assign an annotation to a
track. To limit the number of annotations of this type shown, change
the value of the <i>Limit</i> menu.
END

   TRACK  => 'Track',

   TRACK_TYPE => 'Track Type',

   SHOW => 'Show',

   FORMAT => 'Format',

   LIMIT  => 'Limit',

   ADJUST_ORDER => 'Adjust Order',

   CHANGE_ORDER => 'Change Track Order',

   AUTO => 'Auto',

   COMPACT => 'Compact',

   EXPAND => 'Expand',

   EXPAND_LABEL => 'Expand & Label',

   HYPEREXPAND => 'Hyperexpand',

   HYPEREXPAND_LABEL =>'Hyperexpand & label',

   NO_LIMIT    => 'No limit',

   OVERVIEW    => 'Overview',

   EXTERNAL    => 'External',

   ANALYSIS    => 'Analysis',

   GENERAL     => 'General',

   DETAILS     => 'Details',

   REGION      => 'Region',

   ALL_ON      => 'All on',

   ALL_OFF     => 'All off',

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => 'Close this window',

   TRACK_DESCRIPTIONS => 'Track Descriptions & Citations',

   BUILT_IN           => 'Tracks Built into this Server',

   EXTERNAL           => 'External Annotation Tracks',

   ACTIVATE           => 'Please activate this track in order to view its information.',

   NO_EXTERNAL        => 'No external features loaded.',

   NO_CITATION        => 'No additional information available.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => 'About %s',

 BACK_TO_BROWSER => 'Back to Browser',

 PLUGIN_SEARCH_1   => '%s (via %s search)',

 PLUGIN_SEARCH_2   => '&lt;%s search&gt;',

 CONFIGURE_PLUGIN   => 'Configure',

 BORING_PLUGIN => 'This plugin has no extra configuration settings.',

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => 'The landmark named <i>%s</i> is not recognized. See the help pages for suggestions.',

 TOO_BIG   => 'Detailed view is limited to %s.  Click in the overview to select a region %s wide.',

 PURGED    => "Can't find the file named %s.  Perhaps it has been purged?.",

 NO_LWP    => "This server is not configured to fetch external URLs.",

 FETCH_FAILED  => "Could not fetch %s: %s.",

 TOO_MANY_LANDMARKS => '%d landmarks.  Too many to list.',

 SMALL_INTERVAL    => 'Resizing small interval to %s bp',

 NO_SOURCES        => 'There are no readable data sources configured.  Perhaps you do not have permission to view them.',

};
