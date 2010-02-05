
use SGN::Context;
use CXGN::Page;
use CXGN::DB::Connection;

my $page = CXGN::Page->new();
my ($map_id, $map_version_id, $size, $hilite, $physical, $force) = $page->get_encoded_arguments("map_id", "map_version_id", "size", "hilite", "physical", "force");

my $dbh = CXGN::DB::Connection->new();

my $c = SGN::Context->new();

$c->forward_to_mason_view('/cview/map/index.mas', dbh=>$dbh, map_version_id=>$map_version_id, map_id=>$map_id, hilite=>$hilite, physical=>$physical, size=>$size, force=>$force);

######################################################################
#
#  Program:  $Id$
#  Author:   $Author$
#  Date:     $Date$
#  Version:  1.0
#  CHECKOUT TAG: $Name:  $
#  Usage:    (via Apache()) map.pl ? map_id=INT
#
#  This program automatically produces top pages for each of the maps
#  handled by the SGN mapping tool, Mapviewer.
#
######################################################################

=head1 NAME

map.pl - display top level map web page

=head1 DESCRIPTION

A script that displays a web page with an overview graph of a map, an abstract and some statistics about the map, using map_id or map_version_id as a parameter. 

Older versions of this script accepted other parameters, such as the mysterious legacy_id or the more cumbersome map short name. Support for these has been scrapped. Sorry!

As well, older versions supported a parameter called "physical", which then, through some inextricable hack displayed a physical map. This parameter has been deprecated but is still supported.

On the other hand, a new parameter was added, called "force", which, if set to true, will force the cached images and stats to be re-calculated. Normally, the map overview image and associated image map and the map statistics are cached.

Parameters summary:

=over 15

=item map_id

The map_id of the map to display.

=item map_version_id

the map_version_id of the map to display. Note that map_id and map_version_id are mutually exclusive.

=item hilite

a space separated, url-encoded string that gives the markers to be highlighted.

=item size

the size of the map to display. 0 denotes the standard size (smallest), 10 denotes the largest size.

=item force

if set to true, force the image and map stats caches to be re-calculated.

=back

=head1 AUTHOR(S)

Early versions were written by Robert Ahrens, with later additions by Lukas Mueller and John Binns <zombieite@gmail.com>.

Currently maintained by Lukas Mueller <lam87@cornell.edu>.

=cut

# use strict;

# use Cache::File;
# use File::Spec;
# use URI::Escape;

# use CXGN::DB::Connection;
# use CXGN::Page;
# use CXGN::Page::FormattingHelpers qw(page_title_html blue_section_html tooltipped_text);
# use CXGN::Cview::Map_overviews::Generic;
# use CXGN::People::PageComment;
# use CXGN::VHost;
# use CXGN::Map::Tools;
# use CXGN::Cview::MapFactory;
# use CXGN::Cview::Map::Tools;


# my %marker_info;
# my $vh = CXGN::VHost->new();

# # set up a cache for the map statistics, using Cache::File
# #
# my $cache_file_dir = File::Spec->catfile($vh->get_conf("basepath"), $vh->get_conf("tempfiles_subdir"), "cview", "cache_file");

# tie %marker_info, 'Cache::File', { cache_root => $cache_file_dir };

# # report some unusual conditions to the user.
# #
# my $message = ""; 

# our $page = CXGN::Page -> new( "SGN map", "Lukas");

# $page->jsan_use('MochiKit.Base', 'MochiKit.Async');

# my ($map_id, $map_version_id, $size, $hilite, $physical, $force) = $page->get_encoded_arguments("map_id", "map_version_id", "size", "hilite", "physical", "force");

# my $dbh = CXGN::DB::Connection->new();


# # maintain some backwards compatibility. The physical parameter is deprecated, but
# # we still support it...
# #
# if ($physical==1) { $map_id= "p".$map_id; }

# # if the map_id was supplied, convert immediately to map_version_id
# #
# if ($map_id && !$map_version_id) { 
#     $map_version_id = CXGN::Cview::Map::Tools::find_current_version($dbh, $map_id);
# }


# # get the map data using the CXGN::Map API.
# #
# my $map_factory = CXGN::Cview::MapFactory->new($dbh);
# my $map = $map_factory ->create({ map_version_id => $map_version_id });

# if (!$map) { missing_map_page(); }

# # adjust the size parameter, which scales the size of the map overview image.
# # 
# my $enlarge_button_disabled = "";
# my $shrink_button_disabled = "";
# my $smaller_size = 0;
# my $larger_size = 0;

# $size ||=0;

# if ($size <= 0) { 
#     $size = 0;
#     $shrink_button_disabled = qq { disabled="1" };
#     $smaller_size = $size;
# }
# else { 
#     $smaller_size = $size - 1;
# }

# if ($size>=10) {
#     $size=10; 
#     $enlarge_button_disabled = qq { disabled="1" };
#     $larger_size = $size;
# }
# else { 
#     $larger_size = $size+ 1;
# }
# $larger_size = 10 if $larger_size > 10;

# my $image_height = 160;
# my $image_width = 820;

# $image_height = $image_height + $image_height * $size /2;

# my $map_fullname = $map->get_long_name();
# my $abstract     = $map->get_abstract();
# my $short_name   = $map->get_short_name();

# my @chr_names = $map->get_chromosome_names();

# my $abstract = $map->get_abstract();

# my $map_image_file="";
# my $image_map = "";

# my $map_overview;


# # create an appropriate overview diagram - physical or generic
# # (the generic will also provide an appropriate overview for the fish map).
# #
# $map_overview = CXGN::Cview::Map_overviews::Generic -> new($map, $force);

# $map_overview->set_image_height($image_height);
# $map_overview->set_image_width($image_width);

# # deal with marker names to be highlighted on the overview diagram
# # (the ones to be requested to be hilited using the hilite feature)
# #
# my @hilite_markers = split /\s+|\,\s*|\;s*/, $hilite;

# foreach my $hm (@hilite_markers) {
#     #print STDERR "Hilite marker $hm...\n";
#     $map_overview -> hilite_marker($hm);
# }

# # generate the marker list for use in the URL links
# #
# my $hilite_encoded = URI::Escape::uri_escape(join (" ", @hilite_markers)); 

# # render the map and get the imagemap
# #
# $map_overview -> render_map();

# my $map_overview_html = $map_overview->get_image_html();

# # get the markers that could not be hilited
# #
# my @markers_not_found = $map_overview -> get_markers_not_found();
# if (@markers_not_found) { 
#         $message .= "The following markers requested for hiliting were not found on this map (click to search on other maps):<br />";
#     foreach my $m (@markers_not_found) { 
# 	$message .= "&nbsp;&nbsp;<a href=\"/search/markers/markersearch.pl?searchtype=exactly&amp;name=$m\">$m</a>";
#     }
#     $message .= "<br />\n";
# }

# # start displaying the page
# #
# $page -> header();

# print page_title_html($short_name);
# print "<div id=\"pagetitle2\"><center><h3>$map_fullname</h3></center></div>";

# if ($message) { 
#     print "<div class=\"boxbgcolor5\"><b>NOTE:</b><br />$message</div>\n";
# }

# print <<HTML;

#     <table summary="outer table" width="100%" border="0"><tr>
#     <td width="10%"><br /></td>
#     <td width="80%">
#     <center>
#     $map_overview_html
#     </center>
#     </td></tr></table>

# HTML


# #
# # add the input box and form for the hilite marker feature
# #    
#     my $hilite_tooltip = tooltipped_text("Highlight marker(s)", "You can highlight markers on the overview graphic by entering them here, separated by spaces");
# my $size_tooltip = tooltipped_text("Image size", "You can increase the size of the overview graph by clicking on the (+) button and decrease it by clicking on (-).");

# print <<HTML;

# <table><tr><td align="left">
#     <div class="indentedcontent">
    
#     <form action="/cview/map.pl?map_version_id=$map_version_id&amp;physical=$physical">

# 	$hilite_tooltip: <input type="text" name="hilite" value="$hilite" size="10" />
# 	<input type="hidden" name="physical" value="$physical" />
# 	<input type="hidden" name="map_version_id" value="$map_version_id" />
#         <input type="hidden" name="size" value="$size" />
# 	<input type="submit" value="Highlight" />
#     </form>
#     </div>
#     </td><td width=400 align="right">$size_tooltip:
# </td><td align="right">
#     <form>
#     <input type="hidden" name="physical" value="$physical" />
#     <input type="hidden" name="map_version_id" value="$map_version_id" />
#     <input type="hidden" name="size" value="$smaller_size" />
#     <input type="hidden" name="hilite" value="$hilite" />
#     <input type="submit" value="-" $shrink_button_disabled />
#     </form>
# </td><td>
#     <form>
#     <input type="hidden" name="physical" value="$physical" />
#     <input type="hidden" name="map_version_id" value="$map_version_id" />
#     <input type="hidden" name="hilite" value="$hilite" />
#     <input type="hidden" name="size" value="$larger_size" />
#     <input type="submit" value="+" $enlarge_button_disabled />
#     </form>
# </td></tr></table>


# HTML


# #
# # print the abstract
# #
#     print blue_section_html("Abstract", "<div class=\"indentedcontent\">$abstract</div><br />") if ($abstract);
# #
# # print a list of links, one per chromosome, and some marker stats
# #


# my $map_stats = qq |     

# 	<table summary="map stats" align="center" border="0">
# 	<tr>
# 	<td valign="middle"><b>Click to view a given chromosome<br /><br /></b></td>
# 	<td width="70">&nbsp;</td>
# 	<td><b>Marker collections:</b><br /><br /></td>
# 	</tr>

	
# 	<tr><td>

#     <table summary="marker stats table" >
#     <tr><td>&nbsp;</td><td>\# markers</td></tr>

# |;
    
# if (!$map_id) {
#     $map_id = CXGN::Cview::Map::Tools::find_map_id_with_version($dbh, $map_version_id);
# }

# my $total_markers=0;
# for (my $i=0; $i<@chr_names; $i++) {
#     my $hash_key = $map_version_id."-".$i;
#     if (!exists($marker_info{$hash_key}) || $force) { 
# 	$marker_info{$hash_key} = $map->get_marker_count($chr_names[$i]);
#     }
#     $map_stats .= "<tr><td><a href=\"/cview/view_chromosome.pl?map_version_id=$map_version_id&amp;chr_nr=$chr_names[$i]&amp;hilite=$hilite_encoded\"><b>Chromosome $chr_names[$i]</b></a></td><td align=\"right\"><a href=\"/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=&w822_mapped=on&w822_species=Any&w822_protos=Any&w822_colls=Any&w822_pos_start=&w822_pos_end=&w822_confs=Any&w822_submit=Search&w822_chromos=$chr_names[$i]&w822_maps=$map_id\">$marker_info{$hash_key}</a></td></tr>\n";
#     $total_markers += $marker_info{$hash_key};
# }
# $map_stats .= qq { <tr><td colspan="2">&nbsp;</td></tr><tr><td><b>Total mapped:</b></td><td align=\"right\"><b>$total_markers</b></td></tr>\n };
# $map_stats .=  "</table>\n";
# my $marker_type_table = "";
# if (!exists($marker_info{$map_version_id}) || $force) { 
#     $marker_info{$map_version_id} = $map->get_map_stats();
# }

# $map_stats .= qq | 

#     </td><td>&nbsp;</td><td valign="middle">$marker_info{$map_version_id}</td></tr>
#     </table>
#     <br /><br />



# |;

# print blue_section_html("Map statistics", $map_stats);

# # add the page comment feature. Only show for maps that have completely 
# # numeric identifiers.
# #
#  if ($map_overview->get_map()->get_id=~/^\d+$/) {

#      my $referer = $page->{request}->uri()."?".$page->{request}->args();
#      my $comment_map_id=0;
#      if ($map_id=~/(\d+)/) {
# 	 $comment_map_id=$1; 
#      }
     
#      print $page->comments_html('map', $comment_map_id, $referer);
#  }


# #print "</td></tr>\n";
# #print "</table>";


# # end page
# #
# $page -> footer();


# sub missing_map_page { 
#     $page->header();
   
#     my $title = page_title_html("The requested map could not be found.");
    
#     print <<HTML;

#     $title

#     <p>
#     All available maps on SGN are listed on the <a href="/cview/">map index page</a>.
#     </p>
#     <p>
#     Please contact <a href="mailto:sgn-feedback\@sgn.cornell.edu">SGN</a> if you think there is a problem.
#     </p>

# HTML

#     $page->footer();


#     exit();
# }
    
# # sub hack_abstract ($$$) {    
# #     # Look.  This is a total hack and that's that.  Let's make no
# #     # bones about it. There is doubtlessly a good way to handle this,
# #     # but in the meantime this sub will allow us to swap in a decent
# #     # abstract for the physical mapping project w/o having to redesign
# #     # code.
# #     my ($abstract, $map, $physical) = @_;
# #     my $vhost_conf=CXGN::VHost->new();
# #     my $physabstractfile = $vhost_conf->get_conf('basepath').$vhost_conf->get_conf('support_data_subdir')."/mapviewer/physicalabstract";
# #     my $overgo_stats_page = '/maps/physical/overgo_stats.pl';
# #     my $overgo_plate_browser = '/maps/physical/list_bacs_by_plate.pl';
# #     my $overgo_explanation = '/maps/physical/overgo_process_explained.pl';

# #     my $map_id = $map->map_id();
# #     my $map_fullname = $map->long_name();
# #     if (! $physical) { $physical = 0; }
    
# #     if (($map_id==9) && ($physical==1)) {
# # 	open PHYSABSTRACT, "<$physabstractfile"
# # 	    or die( "<i>ERROR: Unable to read from $physabstractfile</i>.\n" );
# # 	my @phys_abst = <PHYSABSTRACT>;
# # 	close PHYSABSTRACT;
# # 	$abstract = join("", @phys_abst);
# #         $abstract =~ s/MAPID/$map_id/;
# #     }

# #     if ( $map->has_physical() ) {
	
# # 	if ($physical) {
	    
# # 	    $abstract .= <<PHYSICAL;
	    
# # 	    <p>
# # 		<b>Genetic Map:</b> This map is extracted from the 
# # 		<a href="/cview/map.pl?map_id=$map_id&physical=0">$map_fullname</a>.
# # 		</p>
		
# # 		<p>
# # 		<b>Overgo Data</b> 
# # 		<ul>
# # 		<li>Statistics on the <a href="$overgo_stats_page">Overgo Plating Process</a></li>
# # 		<li><a href="$overgo_explanation">Explanation of the Overgo Plating process</a></li>
# # 		</ul>
	
# # PHYSICAL

# #     }
# # 	else {
# # 	    $abstract .= <<PHYSICAL;
	    
# # 	    <p>
# # 		<b><a href="/cview/map.pl?map_id=$map_id&amp;physical=1">The physical Map</a></b> -- a combined genetic and physical map, showing the association of BACs and BAC contigs to this genetic map
# # 		</p>
		
# # PHYSICAL

# #         }

	
# #     }
# #     return $abstract;
# # }

