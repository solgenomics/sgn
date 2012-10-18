
=head1 NAME

solqtl.t - Tests for /phenome/qtl_analysis.pl &   /phenome/qtl.pl

This page takes a few minutes to run R computations.

=head1 DESCRIPTION

Tests for /phenome/qtl_analysis.pl &   /phenome/qtl.pl

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use SGN::Test qw/qsub_is_configured/;

{
    local $TODO = "qsub not configured properly" if !qsub_is_configured();
    my $mech = SGN::Test::WWW::Mechanize->new;


############################## 
/phenome/qtl_analysis.pl page 
############################## 


    $mech->get_ok(
        '/phenome/qtl_analysis.pl?population_id=12&cvterm_id=39945',
        ' got a qtl_analysis.pl page. (In case of failure, try to run it again. Takes 2 - 4 min to run R computations)' );

    $mech->content_contains($_)
      for (
        'Population details',
        'QTLs',
        'Phenotype frequency distribution',
        'Download data',
        'Publication(s)',
        'User comments',
      );


    my @qtl_images = $mech->find_all_images(alt_regex => qr/chromosome/i );
    cmp_ok( scalar(@qtl_images), '>=', 12, 'got 12 or more qtl map images' );

   $mech->content_contains( 'lines', 'frequency distribution plot generated');
   $mech->content_contains( 'Trait data', 'Phenotype data table generated');
   $mech->content_contains( 'Abstract', 'abstract content');
   $mech->content_contains( 'QTL genotype probability method',  'Legend for QTL map: key');
   $mech->content_contains( 'Based on 95%',  'Legend for QTL map: value');
   $mech->content_contains( 'Abstract', 'abstract content for qtl pub');
   $mech->content_contains( 'Standard deviation', 'descriptive statistics for trait phenotype data');


   my $phenotype_download_link =
      $mech->find_link( text_regex => qr/phenotype data/i );
    ok( $phenotype_download_link, 'got a phenotype data download link' );

    my $url = defined $phenotype_download_link ? $phenotype_download_link->url : '';

    $url ? $mech->links_ok( $url, 'phenotype data download link works' ) : ok(0, 'no phenotype url found');

    cmp_ok( length( $mech->content ),
        '>=', 1000,
        'got at least 1KB of data from the phenotype data download' );

    my $genotype_download_link = $mech->find_link( text_regex => qr/genotype data/i );

    ok( $genotype_download_link, 'got a genotype data  download link' );

    if ($genotype_download_link) {
        $mech->links_ok($genotype_download_link->url, 'genotype data download link works' );
    } else {
        ok(0, 'no genotype download link');
    }
    cmp_ok( length( $mech->content ),
        '>=', 1000,
        'got at least 1KB of data from the genotype data download' );



#################### 
/phenome/qtl.pl page 
#################### 

    $mech->get_ok(
    '/phenome/qtl.pl?population_id=12&term_id=39945&chr=3&peak_marker=T0581&lod=3.6&qtl=../data/qtl.png',
    'got a qtl detail page (/phenome/qtl.pl).'
    );

    $mech->content_contains($_)
      for (
        'QTL map',
        'QTL 95%',
        'QTL markers\' genomic matches',
        'Browse QTL region',
        'QTL markers\' genetic positions',
        'Genetic map',
        'User comments',
      );
    my $qtl_image = $mech->find_image( alt_regex => qr/qtl for/i );
    ok( $qtl_image, 'There is a qtl image' )

}

done_testing;
