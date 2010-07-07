
use strict;
use warnings;

use CXGN::Page;
use CXGN::DB::Connection;

my $page = CXGN::Page->new();
my ($map_id, $map_version_id, $size, $hilite, $physical, $force) = $page->get_encoded_arguments("map_id", "map_version_id", "size", "hilite", "physical", "force");

my $dbh = CXGN::DB::Connection->new();

my $referer = ($page->get_request()->uri()) ."?". ($page->get_request->args());

my $tempdir = $c->tempfiles_subdir('cview');


$c->forward_to_mason_view('/cview/map/index.mas', dbh=>$dbh, map_version_id=>$map_version_id, map_id=>$map_id, hilite=>$hilite, physical=>$physical, size=>$size, referer=>$referer, force=>$force, tempdir=>$tempdir, basepath => $c->get_conf('basepath'));

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

###### Historic SGN comment
######    
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
