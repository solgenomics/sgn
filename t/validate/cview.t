use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "cview index page"                         => "/cview/index.pl",
        "map overview F2-2000"                     => "/cview/map.pl?map_id=9",
        "comparative mapviewer"                    => "/cview/view_chromosome.pl?map_version_id=39",
        "map overview FISH map"                    => "/cview/map.pl?map_id=13",
        "physical map overview"                    => "/cview/map.pl?map_id=p9",
        "agp map overview"                         => "/cview/map.pl?map_id=agp",
);

skip_contig_map_or_not( \%urls );

validate_urls(\%urls, $ENV{ITERATIONS} || 1);

done_testing;

##########

sub skip_contig_map_or_not {
    my $urls = shift;
    my $url  = "/cview/map.pl?map_id=c9";
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get($url);
    return if $mech->content =~ m/No database found/;

    $urls->{'Contig map'} = $url;
}
