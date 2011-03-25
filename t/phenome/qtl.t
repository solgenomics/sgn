
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
    $mech->get_ok( '/search/direct_search.pl?search=qtl',
        'QTL/Trait search page' );
    $mech->content_contains("QTL search");

#test trait index links
#my @trait_index_links = $mech->find_all_links( url_regex => qr !/chado/trait_list.pl?!);
#my $traits_num = scalar(@trait_index_links);
#$mech->links_ok(\@trait_index_links, "checking $traits_num trait index links ");

    $mech->get_ok( '/chado/trait_list.pl?index=H', 'a trait index page' );
    $mech->content_contains('Traits beginning with');

    #qtl help page
    $mech->follow_link_ok({ url_regex => qr!/help/qtl_search_help\.pl! });
    $mech->content_contains('Search the database using a trait name');
    $mech->back or die;

    # check on one of the 'browse by population' links
    $mech->follow_link_ok({ url_regex => qr/cvterm.pl/, n => 1 },
        'a link from the QTL search page to a cvterm works' );

    #my $pop_num = scalar(@population_links);
    #$mech->links_ok(\@population_links, "checking $pop_num population links");

    # population page
    $mech->follow_link_ok(
        { url_regex => qr/population_indls/ },
        'Population page' );
    $mech->content_contains($_)
      for (
        'Population Details',
        'QTL(s)',
        'Phenotype Frequency Distribution',
        'User comments'
      );

    # Phenotype data download page
    my $phenotype_download_link =
      $mech->find_link( text_regex => qr/phenotype data/i );
    ok( $phenotype_download_link, 'got a phenotype data  download link' );
    $mech->links_ok( [$phenotype_download_link],
        'phenotype data download link works' );
    cmp_ok( length( $mech->content ),
        '>=', 1000,
        'got at least 1KB of data from the phenotype data download' );

    # Genotype data download page
    my $genotype_download_link =
      $mech->find_link( text_regex => qr/genotype data/i );
    ok( $genotype_download_link, 'got a genotype data  download link' );
    $mech->links_ok( [$genotype_download_link],
        'genotype data download link works' );
    cmp_ok( length( $mech->content ),
        '>=', 1000,
        'got at least 1KB of data from the genotype data download' );

    # test the correlation analysis output( heatmap ) on the population page
  #   $mech->content_contains('Pearson Correlation Analysis');
  #   my $heatmap = $mech->find_image( alt_regex => qr/heatmap/ );
  #   ok( $heatmap, 'population page has a heatmap image' );

  # SKIP: {
  #       skip 'no heatmap found', 2 unless $heatmap;
  #       like( $heatmap->url, qr/heatmap_\d+-\w+\.png$/,
  #           'heatmap image url looks plausible' );
  #       $mech->get_ok( $heatmap->url, 'heatmap URL is fetchable' );
  #   }

    $mech->back;

    #test the correlation download link on the population page
    # my $correlation_download_link = $mech->find_link(
    #     text_regex => qr/Correlation coefficients and p-values table/i );
    # ok( $correlation_download_link, 'got a correlation download link' );
    # $mech->links_ok( [$correlation_download_link],
    #     'correlation download link works' );
    # cmp_ok( length( $mech->content ),
    #     '>=', 1000,
    #     'got at least 1KB of data from the correlation table download' );

    my $qtl_analysis_link = $mech->find_link( url_regex =>
          qr !qtl_analysis.pl?population_id=12&cvterm_id=39945! );
    $mech->links_ok( [$qtl_analysis_link], 'a link to qtl_analysis.pl' );

    # verify that we are on what looks like a qtl_analysis page
    $mech->get_ok(
        '/phenome/qtl_analysis.pl?population_id=12&cvterm_id=39945',
        ' a qtl_analysis.pl page' );
    $mech->content_contains($_)
      for (
        'Population Details',
        'QTLs',
        'Phenotype Frequency Distribution',
        'Phenotype Data',
        'Literature Annotation',
        'QTL genotype probability method',
      );

    # check a qtl.pl page
    my $qtl_link = $mech->find_link( url_regex =>
          qr !/phenome/qtl.pl?population_id=12&term_id=39945&chr=3! );
    $mech->links_ok( [$qtl_link], 'qtl.pl page' );
    $mech->get_ok( $qtl_link,
        'a qtl.pl page link from the qtl_analysis.pl' );

    # check a indls_range_cvterm.pl ( Links on frequency distributions)
    my $fd_bar_link =
      $mech->find_link( url_regex =>
          qr !/phenome/indls_range_cvterm.pl?population_id=12&cvterm_id=39945!
      );
    $mech->links_ok( [$fd_bar_link], 'indls_range_cvterm.pl page' );
    $mech->get_ok( $fd_bar_link,
'a link on a bar of a frequency distribution on the qtl_analysis.pl '
    );

    # find all the qtl.pl links on the page
    #    my @qtl_pl_links = $mech->find_all_links( url_regex => qr!/qtl.pl! );
    #    ok( scalar(@qtl_pl_links) > 0, 'got some qtl.pl links' );

  TODO: {
        local $TODO =
          'testing the literature annotation links needs to be implemented!';
        ok( 0, 'testing literature annotation links' );
    }

# find and test the link to the map in cview, then go back to the population page
#my $map_link = $mech->find_link( url_regex => qr!cview/map.pl! );
#ok( $map_link, 'population page has a cview/map.pl link' );
#$mech->links_ok( [$map_link], 'map link appears to be correct' );

# check the trait cvterm links against the qtl_analysis links
#my @cvterm_links = $mech->find_all_links( url_regex => qr!/cvterm.pl! );
#my @indl_links   = $mech->find_all_links( url_regex => qr!/qtl_analysis.pl! );
#is( scalar(@cvterm_links), scalar(@indl_links), 'same number of qtl_analysis links as cvterm links' );

    # follow the first link to an individual page
    #$mech->get_ok( $indl_links[0]->url, 'first individual link works' );

  TODO: {
        local $TODO = 'need to test qtl.pl page, and links thereon';
        ok( 0, 'qtl.pl page needs to be tested' );
    }

    # test population and genotype download links
  TODO: {
        local $TODO =
'need to implement testing of population download and genotype download links';
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
