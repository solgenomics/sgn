
use strict;
use warnings;

use CXGN::Page;
use CXGN::DB::Connection;

use CatalystX::GlobalContext qw( $c );

my $page = CXGN::Page->new();
my ( $map_id, $map_version_id, $size, $hilite, $physical, $force, $map_items ) =
  $page->get_encoded_arguments(
      qw(
         map_id
         map_version_id
         size
         hilite
         physical
         force
         map_items
        ));

my $dbh = CXGN::DB::Connection->new;

my $referer = $c->request->referer;

$c->forward_to_mason_view(
    '/cview/map/index.mas',
    dbh            => $dbh,
    map_version_id => $map_version_id,
    map_id         => $map_id,
    hilite         => $hilite,
    physical       => $physical,
    size           => $size,
    referer        => $referer,
    force          => $force,
    map_items      => $map_items,
    tempdir        => $c->tempfiles_subdir('cview'),
    basepath       => $c->path_to(),
);

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
