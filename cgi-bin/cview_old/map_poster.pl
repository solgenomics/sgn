
use strict;

use CXGN::DB::Connection;
use CXGN::Cview::MapFactory;
use CXGN::Cview::MapOverviews::Generic;
use CXGN::Cview;

my $map_id = 9;

my $dbh = CXGN::DB::Connection->new();
my $map_factory = CXGN::Cview::MapFactory->new($dbh);
my $map = $map_factory->create({map_id=>$map_id}); 
my $overview = CXGN::Cview::MapOverviews::Generic->new($map);

$overview->set_image_width(2400);
$overview->set_image_height(1000);
$overview->set_chr_height(600);



$overview->render();

my $chr_ref = $overview->get_chromosomes();

foreach my $chr (@$chr_ref) { 
    my @markers = $chr->get_markers();
    foreach my $m (@markers) { 

	if ($m->get_confidence() ==3) { 
	    $m->show_label();
	    $m->set_color(255, 0 ,0);
	}
	else { 
	    $m->set_color(100, 100, 100);
	}
	if ($m->isa("CXGN::Cview::Marker::SequencedBAC")) { 
	    $m->show_label();
	    print STDERR $m->get_marker_name()." is a sequenced BAC\n"; 

	}
    }
    
}

$overview->get_file_png("map_poster_$map_id.png");





