use strict;
use CXGN::Page;
my $page=CXGN::Page->new('help.html','html2pl converter');
$page->header('GBrowse help ');
print<<END_HEREDOC;



<h1><a href="/gbrowse/">GBrowse</a> help</h1>

<p>GBrowse is a graphical annotation viewer which displays computational analyses and features on a clone.</p>

<h2>Selecting a region</h2>


<p>To select a clone to view, enter its name in the text
field labeled "Clone name".</p>

<h3>The overview and detail panels</h3>

<p>If the clone is found in the database, the browser will display it in two
graphical panels:</p>

<center>
<img src="/documents/gbrowse/images/help/overview+detail.gif" align="middle" alt="" />
</center>

<dl>
  <dt><b>Overview panel</b></dt>
  <dd>This panel displays the sequence as a whole.
      A red rectangle indicates the region that is
      displayed in the detail panel.  This rectangle may appear as
      a single line if the detailed region is relatively small.</dd>
  <dt><b>Detail panel</b></dt>
  <dd>This panel displays a zoomed-in view corresponding
      to the overview's red rectangle.  The detail panel consists of
      one or more tracks showing annotations and other features that
      have been placed on the genome.  The detail panel is described
      at length later.</dd>
</dl>

<p>If the requested landmark is not found, the browser will display a
message to this effect.</p>

<!-- #include-classes -->

<h3>Viewing a precise region</h3>

<p>You can view a precise region around a landmark by searching for
<i>landmark:start..stop</i>, where <i>start</i> and <i>stop</i> are
the start and stop positions of the sequence relative to the landmark.
The beginning of the feature is position 1.  In the case of complex
features, such as genes, the "beginning" is defined by the database
administrator.</p>

<p>This offset notation will work correctly for negative strand features
as well as positive strand features.  The coordinates are always
relative to the feature itself.</p>

<h3>Searching for keywords</h3>

<p>Anything you type into the search field that
isn't recognized as a landmark will be treated as a full text search
across the feature database.  This will find comments or other feature
notations that match the typed text.</p>

<p>If successfull, the browser will present you with a list of possible
matching landmarks and their comments.  You will then be asked to
select one to view.</p>

<h2>Navigation</h2>

<img src="/documents/gbrowse/images/help/navbar.gif" align="right" alt="" />

<p>Once a region is displayed, you can navigate through it in a number of
ways:</p>

<dl>
  <dt><b>Scroll left or right with the &lt;&lt;, &lt;,
      &gt; and &gt;&gt; buttons</b></dt>
  <dd>These buttons, which appear in the "Scroll/Zoom" section of the
      screen, will scroll the detail panel to the left or right.  The
      <b>&lt;&lt;</b> and <b>&gt;&gt;</b> buttons scroll an entire
      screen's worth, while <b>&lt;</b> and <b>&gt;</b> scroll a
      half screen.</dd>
  <dt><b>Zoom in or out using the "Show XXX Kbp" menu.</b></dt>
  <dd>Use menu that appears in the center of the "Scroll/Zoom" section
      to change the zoom level.  The menu item name indicates the
      number of base pairs to show in the detail panel.  For example,
      selecting the item "100 Kbp" will zoom the detail panel so as
      to show a region 100 Kbp wide.</dd>
  <dt><b>Make fine adjustments on the zoom level using the "-" and
      "+" buttons.</b></dt>
  <dd>Press the <b>-</b> and <b>+</b> buttons to change the zoom level
      by small increments (usually 10-20\%, depending on how the
      browser is configured).</dd>
  <dt><img src="/documents/gbrowse/images/help/detail_scale.gif" align="right" alt="" />
      <b>Recenter the detail panel by clicking on its scale</b></dt>
  <dd>The scale at the top of the detail panel is live.  Clicking on
      it will recenter the detail panel around the location you
      clicked.  This is a fast and easy way to make fine adjustments
      in the displayed region.</dd>
  <dt><b>Get information on a feature by clicking on it</b></dt>
  <dd>Clicking on a feature in the detail view will link to a page
      that displays more information about it.</dd>
  <dt><img src="/documents/gbrowse/images/help/overview.gif" align="right" alt="" />
      <b>Jump to a new region by clicking on the overview panel</b></dt>
  <dd>Click on the overview panel to immediately jump
      to the corresponding region of the genome. This will only work if you are working with a zoomed-in view.</dd>
</dl>

<h2><a name="detail">The detail panel</a></h2>

<p>The detailed view is composed of a number of distinct tracks which
stretch horizontally from one end of the display to another.  Each
track corresponds to a different type of genomic feature, and is
distinguished by a distinctive graphical shape and color.</p>

<center>
<img src="/documents/gbrowse/images/help/detail.gif" align="middle" alt="" />
</center>

<h3>Customizing the detail panel</h3>

<p>You can customize the detailed display in a number of ways:</p>

<dl>
  
  <dt><b>Change the properties and order of the tracks using the "Set track options" button</b></dt>
  <dd><br /><img src="/documents/gbrowse/images/help/track+settings.gif" border="1" alt="" /></dd>
  <dd><br />This will bring up a window that has detailed settings for each of the tracks.
      Toggle the checkbox in the "Show" column to turn the track on
      and off (this is the same as changing the checkbox in the Search
      Settings area). Change the popup menu in the "Format" column to
      alter the appearance of the corresponding track.  Options include:
      <i>Compact</i> which forces all items in the track onto a single overlapping line without
      labels or descriptions; <i>Expand</i>, which causes items to bump each other so that
      they don't collide; and <i>Expand &amp; Label</i>, which causes items to be labeled
      with their names and a brief description.  The default, <i>Auto</i> will choose compact
      mode if there are too many features on the track, or one of the expanded modes if there
      is sufficient room.  Any changes you make are remembered the next time you visit the browser.
      Press <b>Accept Changes and Return...</b> when you are satisfied with the current options.<br /><br />
      The last column of the track options window allows you to change the order of the
      tracks.  The popup menu lists all possible feature types in alphabetic order.  Select
      the feature type you wish to assign to the track.  The window should refresh with the
      adjusted order automatically, but if it doesn't, select the <b>Update Image</b> button to see the
      new order.</dd>
</dl>      

<h2><a href="/gbrowse/">Get started with GBrowse</a></h2><br />



END_HEREDOC
$page->footer();
