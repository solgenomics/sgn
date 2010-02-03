use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
                                     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     tooltipped_text
    /;

use CXGN::Chado::Organism;

use Bio::Chado::Schema;


# Script to display the major data content of sgn
# Naama Menda, Sept 2009
#


my $page = CXGN::Page->new("SGN data overview page", "Naama");
my ($force) = $page->get_encoded_arguments("force");
    


my $dbh = CXGN::DB::Connection->new();

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() },
					  { on_connect_do => ['SET search_path TO public'],
					  },);

$page->header("SGN data overview");
print  page_title_html("SGN data overview");


print <<EOF;
	<h3>SGN data overview</h3>
	    <p>
	    This page presents a summary of all currently available data on SGN sorted by species.
	    For a view of our database schema, go <a href="/data/schemas/index.html">here</a>.
	    For more details about available maps, loci, libraries, ESTs, metabolic annotation and 
	    phenotypes accessions, see the species of interest.
	    </p>
    <b>List of species currently in the database</b><br /><br />

EOF

my $type = 'web visible';
my $cvterm = $schema->resultset("Cv::Cvterm")->search( { name => $type } )->first();

my ($sol_species, $rub_species, $planta_species);

if ($cvterm) {
    my $cvterm_id = $cvterm->get_column('cvterm_id');

    my @organisms= $schema->resultset("Organism::Organismprop")->search(
	{ type_id => $cvterm_id } )->search_related('organism');
    my %sol=();
    my %rub=();
    my %planta=();
    foreach my $organism(@organisms) {

	my $species = $organism->get_column('species');
	my $genus= $organism->get_column('genus');
	my $organism_id = $organism->get_column('organism_id');
	my $o=CXGN::Chado::Organism->new($schema, $organism_id);
	my $root_tax=$o->get_organism_by_tax('family');
	if ($root_tax) {
	    my $family = $root_tax->species();
	    $sol{$species}= $organism_id if $family eq 'Solanaceae' ;
	    $rub{$species}= $organism_id if $family eq  'Rubiaceae' ;
	    $planta{$species}= $organism_id if $family eq  'Plantaginaceae' ;
	}
    }
    foreach my $s( sort keys %sol ) {
	my $id= $sol{$s};
	$sol_species .= qq|<a href="/chado/organism.pl?organism_id=$id">$s</a><br /><br />|;
    }
    foreach my $s( sort keys %rub ) {
	my $id= $rub{$s};
	$rub_species .= qq|<a href="/chado/organism.pl?organism_id=$id">$s</a><br /><br />|;
    }
    foreach my $s( sort keys %planta ) {
	my $id= $planta{$s};
	$planta_species .= qq|<a href="/chado/organism.pl?organism_id=$id">$s</a><br /><br />|;
    }
}

print  info_section_html(title=>"Solanaceae", contents=>$sol_species);

print  info_section_html(title=>"Rubiaceae", contents=>$rub_species);

print  info_section_html(title=>"Plantaginaceae", contents=>$planta_species);


$page->footer();


__END__
	
