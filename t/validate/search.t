use strict;
use warnings;

use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "direct qtl search"     => "/search/direct_search.pl?search=qtl",
        "qtl_search"            => "/cgi-bin/search/qtl_search.pl",
        "qtl search foo"        => "/search/qtl_search.pl?wf1a_cvterm_name=foo",
        "unigene search"        => "/search/direct_search.pl?search=unigene",
        "unigene search 2"      => "/search/ug-ad2.pl?w9e3_page=0&w9e3_sequence_name=SGN-U231977&w9e3_clone_name=&w9e3_membersrange=gt&w9e3_members1=&w9e3_members2=&w9e3_annotation=&w9e3_annot_type=blast&w9e3_lenrange=gt&w9e3_len1=&w9e3_len2=&w9e3_unigene_build_id=any",
        "unigene detail"        => "/search/unigene.pl?unigene_id=SGN-U231977&w9e3_page=0&w9e3_annot_type=blast&w9e3_unigene_build_id=any",
        "unigene detail 2"      => "/search/unigene.pl?unigene_id=345356&force_image=1",
        "unigene detail 3"      => "/search/unigene.pl?unigene_id=CGN-U124510",
        "unigene build"         => "/search/unigene_build.pl?id=46",
        'unigene list by annot' => '/search/all_unig_for_annot.pl?match_id=308546&search_type=blast_search',
        "est search page"       => "/search/direct_search.pl?search=est",
        "est search"            => "/search/est.pl?request_from=0&request_id=SGN-E234234&request_type=7&search=Search",
        "est detail page"       => "/search/est.pl?request_from=0&request_id=SGN-E234234&request_type=7&search=Search",
        'chado cvterm page'     => '/chado/cvterm.pl?cvterm_id=47499',
        "family search page"    => "/search/direct_search.pl?search=family",
        "family search"         => "/search/family_search.pl?wa82_family_id=22081",
        "family detail page"    => "/search/family.pl?family_id=22081",
        "library search page"   => "/search/direct_search.pl?search=library",
        "library search"        => "/search/library_search.pl?w5c4_term=leaf",
        "Phenotype search"      => "/search/direct_search.pl?search=phenotypes",
        "image search"          => "/search/image_search.pl?wad1_description_filename_composite=&wad1_submitter=&wad1_image_tag=",
        "SGN pubs"              => "/help/publications.pl",
        "glossary search"       => "/search/glossarysearch.pl",
        "people search page"    => "/search/direct_search.pl?search=directory",
        "people search"         => "/solpeople/people_search.pl?wf7d_first_name=&wf7d_last_name=&wf7d_organization=&wf7d_country=USA&wf7d_research_interests=&wf7d_research_keywords=&wf7d_sortby=last_name",
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
