use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use SGN::Test::WWW::Mechanize;
use Test::More;

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->while_logged_in_all(sub {
      my $urls = {
        "phenome claim locus" => "/phenome/claim_locus_ownership.pl",
        "phenome annot stats" => "/phenome/annot_stats.pl",
      };
      validate_urls($urls, $ENV{ITERATIONS} || 1, $mech );
});


my %urls = (

        "gene search"                              => "/search/locus_search.pl?w8e4_any_name_matchtype=contains&w8e4_any_name=dwarf&w8e4_common_name=&w8e4_phenotype=&w8e4_locus_linkage_group=&w8e4_ontology_term=&w8e4_editor=&w8e4_genbank_accession=",
        "locus detail"                             => "/phenome/locus_display.pl?locus_id=428",

        "Locus ajax form"                          => "/jsforms/locus_ajax_form.pl",
        "Locus editors"                            => "/phenome/editors_note.pl",

        "phenotype search"                         => "/search/phenotype_search.pl?wee9_phenotype=&wee9_individual_name=&wee9_population_name=",
        "phenotype individual detail"              => "/phenome/individual.pl?individual_id=7530",
        "phenotype population detail"              => "/phenome/population.pl?population_id=12",

        "QTL detail page"                          => "/phenome/qtl.pl?population_id=12&term_id=47515&chr=7&&peak_marker=SSR286&lod=3.9&qtl=/documents/tempfiles/temp_images/1a1a5391641c653884fbc9d6d8be5c90.png",
        "QTL individuals list page"                => "/phenome/indls_range_cvterm.pl?cvterm_id=47515&lower=151.762&upper=162.011&population_id=12",

        "qtl search"                        => "/search/direct_search.pl?search=qtl",
        "trait search"                        => "/search/direct_search.pl?search=trait",

       );

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );


done_testing;


