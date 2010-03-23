use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      page_title_html
				      columnar_table_html
				      info_table_html
				      modesel
				      html_break_string
				    );
use CXGN::People;
use CXGN::Chado::Organism;
use Bio::Chado::Schema;

my $page   =  CXGN::Page->new("SOL100 sequencing project","Naama");
my $dbh = CXGN::DB::Connection->new();

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() },
					  { on_connect_do => ['SET search_path TO public'],
					  },);

my @species= ('Solanum lycopersicum', 'Solanum pennellii', 'Solanum pimpinellifolium',  'Solanum galapagense');
my $info;
my @details;
foreach my $s (@species ) {
    
    my $o =  CXGN::Chado::Organism::get_organism_by_species($s, $schema);
    if ($o) {
	my $organism_id = $o->organism_id();
	my $organism_link .= qq| <a href="/chado/organism.pl?organism_id=$organism_id">$s</a> |; 
	
	
	push @details,
	[
	 map { $_ } (
	     $organism_link,  "PERSON/GROUP INFO",
	     "PROJECT METADATA",
	 )
	];
    
	
    } else {
	print STDERR "NO ORGANISM FOUND FOR SPECIES $s  !!!!!!!!!!!\n\n";
    }
}


$info = columnar_table_html(
    headings => [
	'Species', 'Sequencer', 'Project',
    ],
    data         => \@details,
    __alt_freq   => 2,
    __alt_width  => 1,
    __alt_offset => 3,
    );

$page->header();

print page_title_html("SOL100 sequencing project\n");

print info_section_html(
    title       => 'Species',
    contents     => $info,
    collapsible => 1,
    );


$page->footer();
