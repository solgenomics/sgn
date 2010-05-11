use strict;
use warnings;
use English;

use Data::Dumper;

use File::Find;
use FindBin;
use File::Spec::Functions;
use File::Basename;
use File::Temp;

use HTML::Lint;
use List::Util qw/min shuffle/;

my %urls;
my %forbidden_urls;
my $forbidden_file;
BEGIN {
#    our @page_urls;

    %urls = (
	     "homepage" => "/",
	     "contig map" => "/cview/map.pl?map_id=c9",
             "map overview F2-2000" => "/cview/map.pl?map_id=9",
             "comparative mapviewer" => "/cview/view_chromosome.pl?map_version_id=39",
             "map overview FISH map" => "/cview/map.pl?map_id=13",
	"physical map overview" => "/cview/map.pl?map_id=p9",
	"agp map overview" => "/cview/map.pl?map_id=agp", 
             "gene search" => "/search/locus_search.pl?w8e4_any_name_matchtype=contains&w8e4_any_name=dwarf&w8e4_common_name=&w8e4_phenotype=&w8e4_locus_linkage_group=&w8e4_ontology_term=&w8e4_editor=&w8e4_genbank_accession=",
             "locus detail" => "/phenome/locus_display.pl?locus_id=428",
             "phenotype search" => "/search/phenotype_search.pl?wee9_phenotype=&wee9_individual_name=&wee9_population_name=",
	     "phenotype individual detail" => "/phenome/individual.pl?individual_id=7530",
	     "phenotype population detail" => "/phenome/population.pl?population_id=12", 
	     "QTL analysis page" => "/phenome/population_indls.pl?population_id=12&cvterm_id=47515",
	     "QTL detail page"=>"/phenome/qtl.pl?population_id=12&term_id=47515&chr=7&l_marker=SSR286&p_marker=SSR286&r_marker=CD57&lod=3.9&qtl=/documents/tempfiles/temp_images/1a1a5391641c653884fbc9d6d8be5c90.png",
	     "QTL individuals list page"=>"/phenome/indls_range_cvterm.pl?cvterm_id=47515&lower=151.762&upper=162.011&population_id=12",
	     "qtl/traits search" => "/search/direct_search.pl?search=cvterm_name",
             "unigene search" => "/search/ug-ad2.pl?w9e3_page=0&w9e3_sequence_name=SGN-U231977&w9e3_clone_name=&w9e3_membersrange=gt&w9e3_members1=&w9e3_members2=&w9e3_annotation=&w9e3_annot_type=blast&w9e3_lenrange=gt&w9e3_len1=&w9e3_len2=&w9e3_unigene_build_id=any",
             "unigene detail" => "/search/unigene.pl?unigene_id=SGN-U231977&w9e3_page=0&w9e3_annot_type=blast&w9e3_unigene_build_id=any",
             "unigene build" => "/search/unigene_build.pl?id=46",
             'unigene standalone six-frame translation' => '/tools/sixframe_translate.pl?unigene_id=573435',
             "marker search page" => "/search/direct_search.pl?search=markers",
             "marker search" => "/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=&w822_mapped=on&w822_species=Any&w822_protos=Any&w822_colls=Any&w822_chromos=Any&w822_pos_start=&w822_pos_end=&w822_confs=-1&w822_maps=Any&w822_submit=Search",
             "marker detail rflp" => "/search/markers/markerinfo.pl?marker_id=109",
             "marker view rflp" => "/search/markers/view_rflp.pl?marker_id=538",
             "marker detail ssr" => "/search/markers/markerinfo.pl?marker_id=1151",
             "marker detail caps" => "/search/markers/markerinfo.pl?marker_id=6469",
             "bac search page" => "/search/direct_search.pl?search=bacs",
             "bac search" => "/maps/physical/clone_search.pl?w98e_page=0&w98e_id=&w98e_seqstatus=&w98e_estlenrange=gt&w98e_estlen1=&w98e_estlen2=&w98e_genbank_accession=&w98e_chromonum=&w98e_end_annotation=&w98e_map_id=&w98e_offsetrange=gt&w98e_offset1=&w98e_offset2=&w98e_linkage_group_name=&w98e_il_project_id=&w98e_il_bin_name=",
             "bac detail page" => "/maps/physical/clone_info.pl?id=3468&w98e_page=0&w98e_seqstatus=complete",
             "bac detail page 2" => "/maps/physical/clone_info.pl?id=119416",
             "est search page" => "/search/direct_search.pl?search=est",
             "est search" => "/search/est.pl?request_from=0&request_id=SGN-E234234&request_type=7&search=Search",
             "est detail page" => "/search/est.pl?request_from=0&request_id=SGN-E234234&request_type=7&search=Search",
             "family search page" => "/search/direct_search.pl?search=family",
             "family search" => "/search/family_search.pl?wa82_family_id=22081",
             "family detail page" => "/search/family.pl?family_id=22081",
             "library search page"=> "/search/direct_search.pl?search=library",
             "library search" => "/search/library_search.pl?w5c4_term=leaf",
             "library detail page" => "/content/library_info.pl?library=MXLF",
             "people search page" => "/search/direct_search.pl?search=directory",
             "people search" => "/solpeople/people_search.pl?wf7d_first_name=&wf7d_last_name=&wf7d_organization=&wf7d_country=USA&wf7d_research_interests=&wf7d_research_keywords=&wf7d_sortby=last_name",
             "people detail page" => "/solpeople/personal-info.pl?sp_person_id=208&action=view",
             "tomato genome data home" => "/tomato/genome_data.pl",
             "genome browser bac list" => "/tomato/genome_data.pl?chr=2",
             # "Gbrowse example" => "/gbrowse/gbrowse/tomato_bacs/?name=C02HBa0016A12.1",
             "BLAST page" => "/tools/blast/",
             "Tree Browser input page" => "/tools/tree_browser/",
             "Tree Browser sample tree" => "/tools/tree_browser/?tree_string=%281%3A0%2E020058%2C%28%28%28%28%28%282%3A0%2E051985%2C6%3A0%2E002761%29%3A0%2E027131%2C11%3A0%2E405224%29%3A0%2E042208%2C15%3A0%2E067923%29%3A0%2E046508%2C%288%3A1%2E655e%2D08%2C10%3A0%2E155643%29%3A0%2E083277%29%3A0%2E096957%2C9%3A0%2E119609%29%3A0%2E124781%2C%28%283%3A0%2E066341%2C%28%28%284%3A0%2E013384%2C7%3A0%2E007637%29%3A0%2E019214%2C%2016%3A0%2E085744%29%3A0%2E020811%2C12%3A0%2E025839%29%3A0%2E168755%29%3A0%2E086288%2C13%3A0%2E170910%29%3A0%2E016660%29%3A0%2E027472%2C%285%3A0%2E005652%2C14%3A0%2E043026%29%3A0%2E014920%29%3B",
             "insitu db" => "/insitu/",
             "insitu search page" => "/insitu/search.pl",
             "insitu search" => "/insitu/search.pl?w773_experiment_name=&w773_exp_tissue=&w773_exp_stage=&w773_exp_description=&w773_probe_name=&w773_probe_identifier=&w773_image_name=&w773_image_description=&w773_person_first_name=&w773_person_last_name=&w773_organism_name=&w773_common_name=#",
             "insitu detail page" => "/insitu/detail/experiment.pl?experiment_id=89&action=view",
	     "alignment viewer input page" => "/tools/align_viewer/",
	     "gem search page for templates" => "/search/direct_search.pl?search=template",
	     "gem search page for experiments" => "/search/direct_search.pl?search=experiment",
	     "gem search page for platforms" => "/search/direct_search.pl?search=platform",
	     "gem results page for templates" => "/search/gem_template_search.pl?w616_template_parameters=AB",
	     "gem results page for experiments" => "/search/gem_experiment_search.pl?w932_experiment_parameters=leaf",
	     "gem results page for platforms" => "/search/gem_platform_search.pl?w4b9_template_parameters=affy",
	     "gem detail page for template" => "/gem/template.pl?id=65",
	     "gem detail page for platform" => "/gem/platform.pl?id=1",
	     "gem detail page for experimental design" => "/gem/experimental_design.pl?id=1",
	     "gem detail page for experiment" => "/gem/experiment.pl?id=1",
	     "gem detail page for target" => "/gem/target.pl?id=49",
	     "biosource detail page for sample" => "/biosource/sample.pl?id=1",
	    );


    ### adds to the urls all of the .pl scripts in cgi-bin
    # this is off by default, turn on with AUTO_URLS=1 env variable
    if( $ENV{AUTO_URLS} ) {
        my $cgi_bin = "$FindBin::RealBin/../cgi-bin";
        die "cgi-bin dir $cgi_bin does not exist" unless -d $cgi_bin;
        find( { wanted => sub {
                    if( /\.pl$/ ) {
                        s/^$cgi_bin//;
                        $urls{"zz(auto) $_"} = $_;
                    }
                },
                no_chdir => 1,
              },
              $cgi_bin
            );
    }

    ### open and parse the list of all the URLs that should return 403 Forbidden
    $forbidden_file = $FindBin::RealBin.'/validate_all.expect403';
    open my $fu, '<', $forbidden_file or die "$! opening $forbidden_file";
    while(<$fu>) {
        chomp;
        $forbidden_urls{$_} = 1;
    }
    close $fu;

}

use CXGN::VHost::Test;

#@page_urls = (shift @page_urls);

my $iteration_count;
use Test::More tests =>
	 scalar(keys %urls)*3*($iteration_count = $ENV{ITERATIONS} || 1)
	 + scalar(keys %forbidden_urls)*0;

my $dump_tempdir;
sub make_dump_tempdir {
    my $d = File::Temp->newdir( catdir( File::Spec->tmpdir, 'validate_error_dump-XXXXXX'), CLEANUP => 0 );
    diag "made dump tempdir '$d'";
    return $d;
}

foreach my $test_name ( shuffle((sort keys %urls) x $iteration_count) ) {
    my $url = $urls{$test_name};
#    print "$url\n";
    my $r = request( $url );

    my $rc = $r->code;

    ok( $rc == 200 || $rc == 403, "$test_name returned either OK or forbidden" )
        or do {
            diag "fetch actually returned code '$rc': $ENV{SGN_TEST_SERVER}$url";
            if( $ENV{DUMP_ERROR_CONTENT} ) {
                if( eval { require Digest::Crc32 } ) {
                $dump_tempdir ||= make_dump_tempdir();
                my $script = $r->request->uri->path;
                $script =~ s/.//;
                $script =~ s/\W+/_/g;
                my $params = $r->request->uri->query;
                $params = $params ? sprintf('%x',Digest::Crc32->new->strcrc32($params)) : '0';
                my $dump_filename = "${script}_${params}.dump";
                $dump_filename = catfile( $dump_tempdir, $dump_filename);
                my $dump_out = IO::File->new( $dump_filename, 'w')
                    or die "$! opening dumpfile $dump_filename for diagnostic dump\n";
                $dump_out->print("FROM URL: $url\n\n");
                $dump_out->print($r->content);
                diag "fetched content dumped to $dump_filename";
            } else {
                diag "Cannot include Digest::CRC32 for error content dump.  Skipping.";
            }
            } else {
                diag "error dump skipped, set DUMP_ERROR_CONTENT=1 to enable error dump files\n";
            }
        };

    if( $rc == 200 ) { #< successful request
      SKIP: {
            skip 'SKIP_HTML_LINT env set', 2 if $ENV{SKIP_HTML_LINT};
            my $lint = HTML::Lint->new;
            $lint->parse( $r->content );
            my @e = $lint->errors;
            my $e_cnt = @e;

            my $max_errors_to_show = 4;

            is( scalar @e, 0, "$test_name HTML validates" )
                or diag( "first " . min($e_cnt,$max_errors_to_show) ." of $e_cnt errors:\n",
                         (map {$_->as_string."\n"} @e[0..min($max_errors_to_show,$#e)]),
                         "NOTE: above line numbers refer to the HTML output.\nTo see full error list, run: view_lint.pl '$ENV{SGN_TEST_SERVER}$url'\n"
                       );

            unlike( $r->content, qr/timed out/i, "$test_name does not seem to have timed out" )
                or diag "fetch from URL $url seems to have timed out";
        }

    } elsif( $rc == 403 ) {
        ok( $forbidden_urls{$url}, "$test_name returned 403, and its url is correctly listed in $forbidden_file" );
        ok( $r->content =~ /Forbidden/ && length($r->content) < 1000, 'content looks appropriately forbidding' );
    }
    else {
        SKIP: { skip 'because of invalid return code '.$rc, 2 };
    }
#     unlike( $content,
#             qr/Sorry, there was an error handling your request/,

#         );
}

$dump_tempdir
    and diag "failing output dumped to $dump_tempdir"


