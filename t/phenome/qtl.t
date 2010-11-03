
=head1 NAME

qtl.t - tests for cgi-bin/qtl.pl

=head1 DESCRIPTION

Tests for cgi-bin/qtl.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use URI::FromHash 'uri';

use SGN::Test::WWW::Mechanize;


{
    my $mech = SGN::Test::WWW::Mechanize->new;

    # go to the QTL search page
    $mech->get_ok('/search/direct_search.pl?search=cvterm_name');
    $mech->content_contains("QTL (trait) search");

    # click on one of the 'browse traits' links
    $mech->follow_link_ok( { text_regex => qr/QTL Tomato/, n => 1 }, 'click on the first link to a QTL population' );

    # check that the link took us to what looks like a population page
    $mech->content_contains('Population:');
    $mech->content_contains('Population Details');
    $mech->content_contains('Literation Annotation', 'seem to have a literature annotation section' );

  TODO: {
        local $TODO = 'testing the literature annotation links needs to be implemented!';
        ok( 0, 'testing literature annotation links' );
    }

    # find and test the link to the map in cview, then go back to the population page
    my $map_link = $mech->find_link( url_regex => qr!cview/map.pl! );
    ok( $map_link, 'population page has a cview/map.pl link' );
    $mech->links_ok( [$map_link], 'map link appears to be correct' );
    $mech->back;

    # check the trait cvterm links against the population_indl links
    my @cvterm_links = $mech->find_all_links( url_regex => qr!/cvterm.pl! );
    my @indl_links   = $mech->find_all_links( url_regex => qr!/population_indls.pl! );
    is( scalar(@cvterm_links), scalar(@indl_links), 'same number of population_indl links as cvterm links' );

    # test that the page includes the correlation analysis and heatmap
    $mech->content_contains('Pearson Correlation Analysis');
    my $heatmap = $mech->find_image( alt_regex => qr/heatmap/ );
    ok( $heatmap, 'population pagae has a heatmap image' );
    like( $heatmap->url, qr/heatmap_\d+-\w+\.png$/, 'heatmap image url looks plausible' );
    $mech->get_ok( $heatmap->url, 'heatmap URL is fetchable' );
    $mech->back;

    #test the correlation download link
    my $correlation_download_link = $mech->find_link( text_regex => qr/Correlation coefficients and p-values table/i );
    ok( $correlation_download_link, 'got a correlation download link' );
    $mech->links_ok( [$correlation_download_link], 'correlation download link works' );
    is( $mech->content_type, 'text/plain', 'got the correct plaintext content type for the correlation table download' );
    cmp_ok( length( $mech->content ), '>=', 1000, 'got at least 1KB of data from the correlation table download' );
    $mech->back;

    # follow the first link to an individual page
    $mech->links_ok( [ $indl_links[0] ], 'first individual link works' );

    # verify that we are on what looks like a population_indl page
    $mech->content_contains($_) for (
        'Population Details',
        'QTLs',
        'Phenotype Frequency Distribution',
        'Phenotype Data',
        'Literature Annotation',
        'QTL genotype probability method',
        'LOD threshold',
       );

    # find all the qtl.pl links on the page
    my @qtl_pl_links = $mech->find_link( url_regex => qr!/qtl.pl! );
    ok( @qtl_pl_links > 0, 'got some qtl.pl links' );
  TODO: {
        local $TODO = 'need to test qtl.pl page, and links thereon';
        ok( 0, 'qtl.pl page needs to be tested' );
    }


    # test population and genotype download links
  TODO: {
        local $TODO = 'need to implement testing of population download and genotype download links';
        ok( 0, 'need to test population and genotype download links' );
    }

    # test indls_range_cvterm links
  TODO: {
        local $TODO = 'need to implement testing of indls_range_cvterm links';
        ok( 0, 'need to test indls_range_cvterm links' );
    }


    # test individual.pl links
  TODO: {
        local $TODO = 'need to implement testing of individual.pl links';
        ok( 0, 'need to test individual.pl links' );
    }

}

done_testing;
