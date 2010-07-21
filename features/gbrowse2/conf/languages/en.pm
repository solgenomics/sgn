# do not remove the { } from the top and bottom of this page!!!
{

 CHARSET =>   'ISO-8859-1',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'Genome browser',

   SEARCH_INSTRUCTIONS => <<END,
<b>Search</b> using a sequence name, gene name,
locus%s, or other landmark. The wildcard
character * is allowed.
END

   NAVIGATION_INSTRUCTIONS => <<END,
<br><b>Navigate</b> by clicking one of the rulers to center on a location, or click and drag to
select a region. Use the Scroll/Zoom buttons to change magnification
and position.
END

   EDIT_INSTRUCTIONS => <<END,
Edit your uploaded annotation data here.
You may use tabs or spaces to separate fields,
but fields that contain whitespace must be contained in
double or single quotes.
END

   SHOWING_FROM_TO => '%s from %s:%s..%s',

   INSTRUCTIONS      => 'Instructions',

   HIDE              => 'Hide',

   SHOW              => 'Show',

   SHOW_INSTRUCTIONS => 'Show instructions',

   HIDE_INSTRUCTIONS => 'Hide instructions',

   SHOW_HEADER       => 'Show banner',

   HIDE_HEADER       => 'Hide banner',

   LANDMARK => 'Landmark or Region',

   BOOKMARK => 'Bookmark this',

   EXPORT => 'Export as...',

   IMAGE_LINK => '...low-res PNG image',

   SVG_LINK   => '...editable SVG image',

   PDF_LINK   => '...high-res PDF',
   
   DUMP_GFF   => '...GFF annotation table',

   DUMP_SEQ   => '...FASTA sequence file',

   FILTER     => 'Filter',

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
timeouts, please press the red "Reset" button.
END

   GO       => 'Go',

   FIND     => 'Find',

   SEARCH   => 'Search',

   DUMP     => 'Download',

   HIGHLIGHT   => 'Highlight',

   ANNOTATE     => 'Annotate',

   SCROLL   => 'Scroll/Zoom',

   RESET    => 'Reset to defaults',

   FLIP     => 'Flip',

   DOWNLOAD_FILE    => 'Download File',

   DOWNLOAD_DATA    => 'Download Data',

   DOWNLOAD         => 'Download',

   DISPLAY_SETTINGS => 'Display Settings',

   TRACKS   => 'Tracks',

   SELECT_TRACKS   => 'Select Tracks',

   TRACK_SELECT   => 'Search for Specific Tracks',

   TRACK_NAME     => 'Track name',

   EXTERNAL_TRACKS => '<i>External tracks italicized</i>',

   OVERVIEW_TRACKS => '<sup>*</sup>Overview track',

   REGION_TRACKS => '<sup>**</sup>Region track',

   EXAMPLES => 'Examples',

   REGION_SIZE => 'Region Size (bp)',

   HELP     => 'Help',

   HELP_WITH_BROWSER     => 'Help with this browser',

   HELP_FORMAT => 'Help with uploading',

   CANCEL   => 'Cancel',

   ABOUT    => 'About GBrowse...',

   ABOUT_DSN    => 'About this database...',

   ABOUT_ME    => 'Show my user ID...',

   ABOUT_NAME   => 'About <i>%s</i>...',

   REDISPLAY   => 'Redisplay',

   CONFIGURE   => 'Configure...',

   CONFIGURE_TRACKS   => 'Configure tracks...',

   SELECT_SUBTRACKS   => '%d of %d subtracks selected',

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

   CLEAR       => 'Clear',

   UPDATE      => 'Update',

   UPDATE_TRACKS => 'Update Tracks',

   UPDATE_SETTINGS => 'Update Appearance',

   DUMPS       => 'Reports &amp; Analysis',

   DATA_SOURCE => 'Data Source',

   UPLOAD_TRACKS=>'Add custom tracks',

   USERDATA_TABLE=>'Upload and share tracks',

   USERIMPORT_TABLE=>'Import tracks',

   UPLOAD_TITLE=> 'Upload your own data',

   UPLOAD_FILE => 'Upload a track file',

   IMPORT_TRACK => 'Import a track URL',

   NEW_TRACK    => 'Create a new track',

   FROM_TEXT    => 'From text',

   FROM_FILE    => 'From a file',

   REMOVE       => 'Remove',

   KEY_POSITION => 'Key position',

   BROWSE      => 'Browse...',

   UPLOAD      => 'Upload',

   NEW         => 'New...',

   REMOTE_TITLE => 'Add remote annotations',

   REMOTE_URL   => 'Enter remote track URL',

   REMOTE_URL_HELP => 'Enter the URL of a remote DAS track, GBrowse track, or internet-accessible track definition file.',

   UPDATE_URLS  => 'Update',

   PRESETS      => '--Choose Preset URL--',

   FEATURES_TO_HIGHLIGHT => 'Highlight feature(s) (feature1 feature2...)',

   REGIONS_TO_HIGHLIGHT => 'Highlight regions (region1:start..end region2:start..end)',

   FEATURES_TO_HIGHLIGHT_HINT => 'Hint: use feature@color to select the color, as in \'NUT21@lightblue\'',

   REGIONS_TO_HIGHLIGHT_HINT  => 'Hint: use region@color to select the color, as in \'Chr1:10000..20000@lightblue\'',

   NO_TRACKS    => '*none*',

   FEATURES_CLIPPED => 'Showing %s of %s features',

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

   NAME           => 'Name',
   TYPE           => 'Type',
   DESCRIPTION    => 'Description',
   POSITION       => 'Position',
   SCORE          => 'Match Score',

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

   LIMIT  => 'Max. features to show',

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

   OK                 => 'OK',

   CLOSE_WINDOW => 'Close this window',

   TRACK_DESCRIPTIONS => 'Track Descriptions & Citations',

   BUILT_IN           => 'Tracks Built into this Server',

   EXTERNAL           => 'External Annotation Tracks',

   ACTIVATE           => 'Please activate this track in order to view its information.',

   NO_EXTERNAL        => 'No external features loaded.',

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

 TOO_BIG   => 'Detailed view is limited to %s. Click and drag on one of the scalebars to make a smaller selection.',

 PURGED    => "Can't find the file named %s.  Perhaps it has been purged?.",

 NO_LWP    => "This server is not configured to fetch external URLs.",

 FETCH_FAILED  => "Could not fetch %s: %s.",

 TOO_MANY_LANDMARKS => '%d landmarks.  Too many to list.',

 SMALL_INTERVAL    => 'Resizing small interval to %s bp',

 NO_SOURCES        => 'There are no readable data sources configured.  Perhaps you do not have permission to view them.',

 ADD_YOUR_OWN_TRACKS => 'Add custom tracks',

 INVALID_SOURCE    => 'The source named %s is invalid.',

 NO_SEGMENT        => 'No genomic region selected.',

 BACKGROUND_COLOR  => 'Fill color',

 FG_COLOR          => 'Line color',

 HEIGHT           => 'Height',

 PACKING          => 'Packing',

 GLYPH            => 'Shape',

 LINEWIDTH        => 'Line width',

 STRANDED         => 'Show strand',

 DEFAULT          => '(default)',

 DYNAMIC_VALUE    => 'Dynamically calculated',

 CHANGE           => 'Change',

 DRAGGABLE_TRACKS  => 'Draggable tracks',

 CACHE_TRACKS      => 'Cache tracks',

 SHOW_TOOLTIPS     => 'Show tooltips',

 OPTIONS_RESET     => 'All page settings have been reset to their default values',

 OPTIONS_UPDATED   => 'A new site configuration is in effect; all page settings have been reset to their defaults',

 SEND_TO_GALAXY    => 'Export to Galaxy',

 NO_DAS            => 'Installation error: Bio::Das module must be installed for DAS URLs to work. Please inform this site\'s webmaster.',

 SHOW_OR_HIDE_TRACK => '<b>Show or hide this track</b>',

 KILL_THIS_TRACK    => '<b>Turn off this track</b>',

 CONFIGURE_THIS_TRACK   => '<b>Configure this track</b>',

 DOWNLOAD_THIS_TRACK   => '<b>Download this track</b>',

 ABOUT_THIS_TRACK   => '<b>About this track</b>',

#  SUBTRACKS_SHOWN    => 'This track contains selectable subtracks:',

 SHOW_SUBTRACKS     => '<b>Select subtracks</b>',

 SHOWING_SUBTRACKS  => '(<i>Showing %d of %d subtracks</i>)',

 SHARE_THIS_TRACK   => '<b>Share this track</b>',

 SHARE_ALL          => 'Share these tracks',

 SHARE              => 'Share %s',

 SHARE_INSTRUCTIONS_BOOKMARK => <<END,
To <b>share</b> this track with another user, copy the URL below and
send it to him or her.
END

 SHARE_INSTRUCTIONS_ONE_TRACK => <<END,
To <b>export</b> this track to a different GBrowse genome browser,
first copy the URL below, then go to the other GBrowse, 
select the "Upload and Share Tracks" tab and
paste the URL into the "Import tracks" section at the bottom.
END

 SHARE_INSTRUCTIONS_ALL_TRACKS => <<END,
To export all currently selected tracks to another GBrowse genome
browser, first copy the URL below, then go to the other GBrowse,
select the "Upload and Share Tracks" tab and
paste the URL into the "Import tracks" section at the bottom.
END

 SHARE_DAS_INSTRUCTIONS_ONE_TRACK => <<END,
To export this track with another genome browser using 
the <a href="http://www.biodas.org" target="_new">
Distributed Annotation System (DAS)</a> first copy the URL below, 
then go to the other browser and enter it as a new DAS source.
<i>Quantitative tracks ("wiggle" files) and uploaded files can not
be shared using DAS.</i>
END

 SHARE_DAS_INSTRUCTIONS_ALL_TRACKS => <<END,
To export all currently selected tracks with another genome browser
using the <a href="http://www.biodas.org" target="_new"> Distributed
Annotation System (DAS)</a> first copy the URL below, then go to the
other browser and enter it as a new DAS source. <i>Quantitative tracks
("wiggle" files) and uploaded files can not be shared using DAS.</i>
END

    MAIN_PAGE          => 'Browser',
    CUSTOM_TRACKS_PAGE => 'Upload and Share Tracks',
    SETTINGS_PAGE      => 'Preferences',

    DOWNLOAD_TRACK_DATA_REGION => 'Download track data across region %s',
    DOWNLOAD_TRACK_DATA_CHROM => 'Download track data across ENTIRE chromosome %s',
    DOWNLOAD_TRACK_DATA_ALL => 'Download ALL DATA for this track',

};
