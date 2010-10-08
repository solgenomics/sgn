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
        "homepage"                                 => "/",

        "gene search"                              => "/search/locus_search.pl?w8e4_any_name_matchtype=contains&w8e4_any_name=dwarf&w8e4_common_name=&w8e4_phenotype=&w8e4_locus_linkage_group=&w8e4_ontology_term=&w8e4_editor=&w8e4_genbank_accession=",
        "locus detail"                             => "/phenome/locus_display.pl?locus_id=428",
        "phenotype search"                         => "/search/phenotype_search.pl?wee9_phenotype=&wee9_individual_name=&wee9_population_name=",
        "phenotype individual detail"              => "/phenome/individual.pl?individual_id=7530",
        "phenotype population detail"              => "/phenome/population.pl?population_id=12",

        "QTL detail page"                          => "/phenome/qtl.pl?population_id=12&term_id=47515&chr=7&l_marker=SSR286&p_marker=SSR286&r_marker=CD57&lod=3.9&qtl=/documents/tempfiles/temp_images/1a1a5391641c653884fbc9d6d8be5c90.png",
        "QTL individuals list page"                => "/phenome/indls_range_cvterm.pl?cvterm_id=47515&lower=151.762&upper=162.011&population_id=12",
        "qtl/traits search"                        => "/search/direct_search.pl?search=cvterm_name",

        'tomato bac tpf'                           => '/sequencing/agp.pl',
        'tomato bac tpf'                           => '/sequencing/tpf.pl',
        'tomato bac tpf chr 12'                    => '/sequencing/tpf.pl?chr=12',

        "unigene search"                           => "/search/direct_search.pl?search=unigene",
        "unigene search 2"                           => "/search/ug-ad2.pl?w9e3_page=0&w9e3_sequence_name=SGN-U231977&w9e3_clone_name=&w9e3_membersrange=gt&w9e3_members1=&w9e3_members2=&w9e3_annotation=&w9e3_annot_type=blast&w9e3_lenrange=gt&w9e3_len1=&w9e3_len2=&w9e3_unigene_build_id=any",
        "unigene detail"                           => "/search/unigene.pl?unigene_id=SGN-U231977&w9e3_page=0&w9e3_annot_type=blast&w9e3_unigene_build_id=any",
        "unigene detail 2"                         => "/search/unigene.pl?unigene_id=345356&force_image=1",
        "unigene build"                            => "/search/unigene_build.pl?id=46",
        'unigene standalone six-frame translation' => '/tools/sixframe_translate.pl?unigene_id=573435',

        "est search page"                          => "/search/direct_search.pl?search=est",
        "est search"                               => "/search/est.pl?request_from=0&request_id=SGN-E234234&request_type=7&search=Search",
        "est detail page"                          => "/search/est.pl?request_from=0&request_id=SGN-E234234&request_type=7&search=Search",
        'chado cvterm page'                        => '/chado/cvterm.pl?cvterm_id=47499',

        "family search page"                       => "/search/direct_search.pl?search=family",
        "family search"                            => "/search/family_search.pl?wa82_family_id=22081",
        "family detail page"                       => "/search/family.pl?family_id=22081",
        "library search page"                      => "/search/direct_search.pl?search=library",
        "library search"                           => "/search/library_search.pl?w5c4_term=leaf",
        "library detail page"                      => "/content/library_info.pl?library=MXLF",

        "people search page"                       => "/search/direct_search.pl?search=directory",
        "people search"                            => "/solpeople/people_search.pl?wf7d_first_name=&wf7d_last_name=&wf7d_organization=&wf7d_country=USA&wf7d_research_interests=&wf7d_research_keywords=&wf7d_sortby=last_name",
        "people detail page"                       => "/solpeople/personal-info.pl?sp_person_id=208&action=view",

        "genome browser bac list"                  => "/genomes/Solanum_lycopersicum/genome_data.pl?chr=2",
        # "Gbrowse example"                        => "/gbrowse/gbrowse/tomato_bacs/?name=C02HBa0016A12.1",
        "BLAST page"                               => "/tools/blast/",

        "Tree Browser input page"                  => "/tools/tree_browser/",
        "Tree Browser sample tree"                 => "/tools/tree_browser/?tree_string=%281%3A0%2E020058%2C%28%28%28%28%28%282%3A0%2E051985%2C6%3A0%2E002761%29%3A0%2E027131%2C11%3A0%2E405224%29%3A0%2E042208%2C15%3A0%2E067923%29%3A0%2E046508%2C%288%3A1%2E655e%2D08%2C10%3A0%2E155643%29%3A0%2E083277%29%3A0%2E096957%2C9%3A0%2E119609%29%3A0%2E124781%2C%28%283%3A0%2E066341%2C%28%28%284%3A0%2E013384%2C7%3A0%2E007637%29%3A0%2E019214%2C%2016%3A0%2E085744%29%3A0%2E020811%2C12%3A0%2E025839%29%3A0%2E168755%29%3A0%2E086288%2C13%3A0%2E170910%29%3A0%2E016660%29%3A0%2E027472%2C%285%3A0%2E005652%2C14%3A0%2E043026%29%3A0%2E014920%29%3B",

        "insitu db"                                => "/insitu/",
        "insitu search page"                       => "/insitu/search.pl",
        "insitu search"                            => "/insitu/search.pl?w773_experiment_name=&w773_exp_tissue=&w773_exp_stage=&w773_exp_description=&w773_probe_name=&w773_probe_identifier=&w773_image_name=&w773_image_description=&w773_person_first_name=&w773_person_last_name=&w773_organism_name=&w773_common_name=#",
        "insitu detail page"                       => "/insitu/detail/experiment.pl?experiment_id=89&action=view",


        "biosource detail page for sample"         => "/biosource/sample.pl?id=1",

        "Locus ajax form"                          => "/jsforms/locus_ajax_form.pl",
        "Locus editors"                            => "/phenome/editors_note.pl",
        "Phenotype search"                         => "/search/direct_search.pl?search=phenotypes",
        "SNP search markers"                       => "/search/markers/snp.pl",

        'sol100 page'                              => '/organism/sol100/view',
        "SGN data overview"                        => "/organism/all/view",

        "outreach index"                           => "/outreach/",
        "organism page for tomato"                 => "/chado/organism.pl?organism_id=1",
        "image search"                             => "/search/image_search.pl?wad1_description_filename_composite=&wad1_submitter=&wad1_image_tag=",
        "bac registry"                             => "/sequencing/bac_registry_discrepancies.pl",
        "SGN pubs"                                 => "/help/publications.pl",
        "glossary search"                          => "/search/glossarysearch.pl",
        "contact"                                  => "/tools/contact.pl",
        "seed BAC guidelines"                      => '/solanaceae-project/seed_bac_selection.pl',
        "caps designer input"                      => '/tools/caps_designer/caps_input.pl',
        "intron finder"                            => '/tools/intron_detection/find_introns.pl',
        "display intron"                           => '/tools/intron_detection/display_introns.pl',
        "about clustal file"                       => '/about/clustal_file.pl',

        'fastmapping tool front page'              => '/tools/fastmapping/index.pl',
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );


done_testing;


