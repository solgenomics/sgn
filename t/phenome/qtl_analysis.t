
=head1 NAME

qtl_analysis.t - tests for cgi-bin/phenome/qtl_analysis.pl

=head1 DESCRIPTION

Tests for cgi-bin/phenome/qtl_analysis.pl


=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    $mech->get_ok(
        '/phenome/qtl_analysis.pl?population_id=12&cvterm_id=39945',
        ' got a qtl_analysis.pl page' );

    $mech->content_contains($_)
      for (
        'Population Details',
        'QTLs',
        'Phenotype Frequency Distribution',
        'Phenotype Data',
        'Literature Annotation',
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
   
    $mech->links_ok( $phenotype_download_link->url,
        'phenotype data download link works' );
    
    cmp_ok( length( $mech->content ),
        '>=', 1000,
        'got at least 1KB of data from the phenotype data download' );

    my $genotype_download_link =
      $mech->find_link( text_regex => qr/genotype data/i );
    
    ok( $genotype_download_link, 'got a genotype data  download link' );
    
    $mech->links_ok($genotype_download_link->url,
        'genotype data download link works' );
    
    cmp_ok( length( $mech->content ),
        '>=', 1000,
        'got at least 1KB of data from the genotype data download' );
   
}

done_testing;
