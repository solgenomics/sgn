
use strict;

use Test::WWW::Mechanize;
use Test::More;

if (!$ENV{SGN_TEST_SERVER}) { die "Need SGN_TEST_SERVER"; }

my $m = Test::WWW::Mechanize->new();

my $tests = 0;

$m->get_ok($ENV{SGN_TEST_SERVER}."/cview/");
$tests++;
$m->content_contains("Interactive maps");
$tests++;
my @map_links = $m->find_all_links( url_regex => qr/map.pl/);
foreach my $map (@map_links) { 
    my $link_text = $map->text();

    $m->follow_link_ok( {text=>$map->text() });
    $tests++;

    $m->content_contains("Map statistics");
    $tests++;

    my @chr_links = $m->find_all_links(url_regex => qr/view_chromosome.pl/);

#    if (@chr_links) { $m->follow_link_ok({ text=>$chr_links[0]->text() }); $tests++;}
#    $tests++;

    $m->back();

    if ($m->content() =~ /Overlay/) { 
	my %form = ( 
	    form_name => 'overlay_form',
	    fields => { 
		map_id=> 9,
		hilite => "1 50 foo",
		force => 1,
	    }
	    );
	
	$m->submit_form_ok(\%form, "submit overlay form");
	$tests++;
	$m->back();
    }
	
    $m->back();
}
    

done_testing($tests);
