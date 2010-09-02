#!usr/bin/perl
use warnings;
use strict;

use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People;
use CXGN::Tools::WebImageCache;
use CXGN::Phenome::Locus;
use GD::Graph::lines; 
use GD::Graph::linespoints; 
use GD::Graph::area;
use GD::Graph::bars;
use CatalystX::GlobalContext '$c';

use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
                                     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     html_alternate_show
                                    /;
my $dbh = CXGN::DB::Connection->new();
my $logged_sp_person_id = CXGN::Login->new($dbh)->verify_session();

my $page = CXGN::Page->new("Phenome annotation stats","Naama");

$page->header();

my $form = CXGN::Page::WebForm->new();

my @lstats=CXGN::Phenome::Locus->get_locus_stats( $dbh );


my $image= get_graph(@lstats);
print info_section_html(title   => 'Locus stats',
			    contents => $image,
			);

$page->footer();

sub get_graph {
    my @stats=@_;
    my $basepath = $c->config->{"basepath"};
    my $tempfile_dir = $c->config->{"tempfiles_subdir"};
    my $cache = CXGN::Tools::WebImageCache->new(1);
    $cache->set_basedir($basepath);
    $cache->set_temp_dir($tempfile_dir."/temp_images");
    $cache->set_key("Locus_num");
    #$cache->set_map_name("locusnum");
    
    $cache->set_force(1);
    if (! $cache->is_valid()) { 
	
	my $graph = GD::Graph::area->new(600,400);
	$graph->set(
		    x_label           => 'Date',
		    y_label           => 'Number of loci',
		    title             => 'SGN locus database',
		    #cumulate         =>'true',
		    y_max_value       => 7000,
		    #y_tick_number     => 8,
		    #y_label_skip      => 2
		    ) or die $graph->error;
	
	for my $i ( 0 .. $#stats ) {
	    my $aref = $stats[$i];
	    my $n = @$aref - 1;
	    for my $j ( 0 .. $n ) {
		print STDERR "elt $i $j is $stats[$i][$j]\n";
	    }
	}
	
		
	$graph->set_title_font('gdTinyFont');
	my @bar_clr = ("orange");
	
	
	$cache->set_image_data($graph->plot(\@stats)->png);
	
    }
    
    my $image = $cache->get_image_tag();
    my $title = "SGN locus database";
    return $image;
}

