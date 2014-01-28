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

if (@map_links < 2 )  { 
    diag("too few maps in database to test viewmaps.");
}
else {
    # try test a comparison of the first two maps.
    #
    my $map_name1 = $map_links[0]->text();
    my $map_name2 = $map_links[1]->text();

    # skip maps with non-numeric ids if local data not available
    #
    if ( ($map_links[0]->url =~ /map.*?id=[a-zA-Z]+/ || $map_links[1]->url =~ /map.*?id=[a-zA-z]+/) && ($m->test_level() ne 'remote') ) {
	diag("Skipping $map_name1 / $map_name2 comparison\n");
	
    }
    else { 
	my $id1 = $map_links[0]->url();
	$id1=~s/.*map_id=(\d+).*/$1/;
	my $id2 = $map_links[1]->url();
	$id2=~s/.*map_id=(\d+).*/$1/g;
	$m->get_ok("/cview/view_maps.pl?center_map_version_id=$id1&right_map_version_id=$id2");
	$tests++;	
    }
}

done_testing($tests);
