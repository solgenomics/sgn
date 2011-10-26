use strict;
use warnings;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;
use Test::More;

my $m = SGN::Test::WWW::Mechanize->new();

my $tests = 0;

$m->get_ok("/cview/");
$tests++;
$m->content_contains("Interactive maps");
$tests++;
my @map_links = $m->find_all_links( url_regex => qr/map.pl/ );

foreach my $map ( @map_links ) {
    my $link_text = $map->text();

    # skip maps with non-numeric ids if local data not available
    #
    if ($map->url =~ /map.*?id=[a-zA-Z]+/ && $m->test_level() ne 'remote' ) {
	diag("Skipping $link_text\n");
	next();
    }

    diag "following '$link_text' link";

    $m->follow_link_ok( { text => $map->text() } );
    $tests++;

    $m->content_contains("Map statistics");
    $tests++;

    my @chr_links = $m->find_all_links( url_regex => qr/view_chromosome.pl/ );

#    if (@chr_links) { $m->follow_link_ok({ text=>$chr_links[0]->text() }); $tests++;}
#    $tests++;

    $m->back();

    if ( $m->content() =~ /Overlay/ ) {
        my %form = (
            form_name => 'overlay_form',
            fields    => {
                map_id => 9,
                hilite => "1 50 foo",
                force  => 1,
            }
        );
        $m->submit_form_ok( \%form, "submit overlay form" );
        $tests++;
        $m->back();
    }

    $m->back();
}

done_testing($tests);
