use strict;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
                                     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     tooltipped_text
    /;
use CXGN::People::Person;
use CXGN::Chado::Organism;
use CXGN::Tools::Text ;

use Bio::Chado::Schema;

my $page = CXGN::Page->new("SGN Organism detail", "Naama");
my ($organism_id, $force) = $page->get_encoded_arguments("organism_id", "force");
    


my $dbh = CXGN::DB::Connection->new();

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() },
					  { on_connect_do => ['SET search_path TO public'],
					  },);

my $organism = CXGN::Chado::Organism->new($schema, $organism_id);
if (!$organism) { $page->message_page("No organism exists for identifier $organism_id!"); }
if (!$organism_id || (!$organism_id  =~ /^\d+$/) ){$page->message_page("'$organism_id' is not a valid identifier!") ; } 

my $name = $organism->get_species();
my $taxon = $organism->get_taxon();
my $common_name = $organism->get_group_common_name(); 

##this should be an Ajax editable div
my $description = CXGN::Tools::Text::format_field_text($organism->get_comment() ); #the description was copied from sgn_organism to the comment field
##

my @synonyms= $organism->get_synonyms();
my $synonym_list;

foreach my $synonym ( @synonyms) {
    $synonym_list .= $synonym . "<br />";
}
my $details = info_table_html('Name'     => $name.($taxon ? " ($taxon)" : ''),
			      'Common name' => $common_name,
			      'Description' => $description,
			      'Synonyms'    => $synonym_list,
			      '__border'    =>0,
    );

$page->header("SGN Organism page for $taxon $name");
print  page_title_html(($taxon ? ucfirst($taxon).": $name" : $name));

print  info_section_html(title=> 'Basic information', contents=>$details);


our $taxonomy=undef;
$taxonomy = get_parentage($organism);

print info_section_html(title=>'Taxonomy' , contents=>$taxonomy);


my $accessions;
my @dbxrefs = $organism->get_dbxrefs();
my $solcyc_link;

foreach my $dbxref (@dbxrefs) {
    my $accession = $dbxref->accession();
    my ($db) = $dbxref->search_related("db");
    my $db_name = $db->name();
    my $full_url=$db->urlprefix . $db->url();
    
    if ($db_name =~ m/(DB:)(.*)/ ) {
	$db_name = $2;
	$db_name =~ s/_/ /g;
	
	$accessions .= qq|<a href= "$full_url$accession">$db_name ID: $accession</a ><br />|;
    }
    if ( $db_name eq 'SolCyc_by_species' ) {
	my $solcyc = $accession;
	$solcyc =~ s/\///g;
	$solcyc =~ s/$solcyc/\u\L$solcyc/g;
	$solcyc = $solcyc . "Cyc";
	$solcyc_link = "See <a href=\"$full_url$accession\">$solcyc</a>";
    }
}
print info_section_html(title       => 'Accessions',
			contents    => $accessions,
			collapsible => 1 );
#############################################################################

my $na= qq| <span class="ghosted">N/A</span> |;
my $genomic= info_table_html('Ploidy'      => $organism->get_ploidy() || $na,
			     'Genome size' => $organism->get_genome_size() || $na,
			     'Chromosome number'=> $organism->get_chromosome_number() || $na,
    );

my $maps;
my @map_data= $organism->get_map_data();
foreach my $info (@map_data) {
    my $map_id = $info->[1];
    my $short_name = $info->[0]; 
    $maps .="<a href=\"/cview/map.pl?map_id=$map_id\">$short_name</a><br />";
}
#$maps = "<div> $maps </div> " if $maps;
my $map_list = info_table_html('Available maps' => $maps || $na,
			       '__border' => 0,
    );

my $loci_count = $organism->get_loci_count() ;
my $loci_list = qq|<a href= "/search/locus_search.pl?&w8e4_common_name=$common_name">$loci_count loci</a>| ;
$loci_list = $na if !$loci_count;
my $loci = info_table_html("Available loci (for $common_name species)" => $loci_list, "__border" => 0);

print info_section_html(title       => 'Genomic details',
			contents    => $genomic .  $map_list . $loci,
			collapsible => 1,
    );


#############################################################################

my @libraries= $organism->get_library_list();
my $lib_count= scalar(@libraries);
my $library_info;
foreach my $lib (@libraries) { 
    $library_info .= qq|<a href="/content/library_info.pl?library=$lib\">$lib</a> | ;
}
$library_info = $na if !$lib_count ;

#my $est_count= $organism->get_est_count() || 0; #this query is very slow!
#my $est_link='';# qq |<a href=/search/direct_search.pl?search=est>$est_count</a>| ;

my $attribution = $organism->get_est_attribution();


my $transcript = info_table_html("Libraries ($lib_count)" => $library_info ,
				 "Data attribution" => $attribution,
				 "__border" => 0 
    );


print info_section_html(title       => 'Transcriptomic details',
			contents    => $transcript,
			collapsible => 1,
                        collapsed   => 0);



###################################################################
print info_section_html(title       => 'Metabolic details',
			contents    => $solcyc_link || $na,
			collapsible => 1,
                        collapsed   => 0);


#####################################################################

my $pheno_count= $organism->get_phenotype_count();

my $pheno_list = qq|<a href="/search/phenotype_search.pl?wee9_common_name=$common_name">$pheno_count</a>| ;
$pheno_list = $na if !$pheno_count;
my $phenotypes = info_table_html("Available phenotypes (for $common_name species)" => $pheno_list, "__border" => 0);


print info_section_html(title       => 'Phenomic details',
			contents    => $phenotypes,
			collapsible => 1,
                        collapsed   => 0);


#####################################################################

$page->footer();



sub get_parentage {
  
    my $organism=shift;
    my $parent= $organism->get_parent();
    if ($parent) {
	my $species= $parent->get_species();
	my $taxon= $parent->get_taxon();
	my $comma = ", " if $parent->get_parent() || '';
	$taxonomy = $comma . tooltipped_text($species, $taxon) . $taxonomy ;
	
	$taxonomy = get_parentage($parent);
    }
    return  $taxonomy;
}
