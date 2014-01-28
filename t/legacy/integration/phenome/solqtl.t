
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
#/phenome/qtl_analysis.pl page 
############################## 
print STDERR "\n\n.....starting to test /phenome/qtl_analysis.pl.....\n\n";  

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
#/phenome/qtl.pl page 
#################### 
    print STDERR "\n\n.....starting to test /phenome/qtl.pl.....\n\n";                 
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
    ok( $qtl_image, 'There is a qtl image' );

###########################
# lib/SGN/Controller/Qtl.pm
###########################

print STDERR "\n\n.....starting to test qtl search related pages.....\n\n";

use_ok(  'SGN::Controller::Qtl'  )
    or BAIL_OUT('could not include SGN::Controller::Qtl');
 
$mech->get_ok("/search/qtl", "Got qtl search page");
$mech->get_ok("/qtl/search", "Got qtl search page, another url");
$mech->get_ok("/qtl/search/results?trait=fruit+shape", "Got qtl search results page");
$mech->get_ok("/qtl/search/help", "Got qtl search help page");

print STDERR "\n\n.....starting to test qtl data submission webforms.....\n\n"; 

$mech->get_ok("/qtl/form", "intro qtl data submission webform");
$mech->get_ok("/qtl/form/intro", "intro qtl data submission webform -intro");
$mech->get_ok("/qtl/form/pop_form", "population detail -- qtl data submission webform");
$mech->get_ok("/qtl/form/trait_form/12", "trait data -- qtl data submission webform");
$mech->get_ok("/qtl/form/pheno_form/12", "phenotype data -- qtl data submission webform");
$mech->get_ok("/qtl/form/geno_form/12", "genotype data -- qtl data submission webform");
$mech->get_ok("/qtl/form/stat_form/12", "statistical parameters -- qtl data submission webform");
$mech->get_ok("/qtl/form/confirm/12", "confirmation-- qtl data submission webform");

print STDERR "\n\n.....starting to test traits list pages.....\n\n"; 

$mech->get_ok("/qtl/traits/H", "qtl traits list page");
$mech->get_ok("/qtl/submission/guide/", "qtl submission guide page");

print STDERR "\n\n.....starting to test qtl population page.....\n\n";
$mech->get_ok("/qtl/view/12", "Got qtl population page - old url");
$mech->get_ok("/qtl/population/12", "Got qtl population page");
$mech->content_contains("Population summary", "there is population summary section");
$mech->content_contains("Set statistical parameters", "there is statistical parameters section");
$mech->content_contains("Analyze QTLs", "there is list of traits section");
$mech->content_contains("Pearson correlation", "there is correlation section");
$mech->content_contains("Download", "there is data download section");
$mech->content_contains("Set your own QTL analysis parameters", "interactive statistics interface loaded");

ok($mech->find_image(alt_regex => qr/run solQTL/i ), "Got atleast one trait for solQTL");
my @links_to_solqtl = $mech->find_all_links( text_regex => qr/run solQTL/i );
my $traits = scalar(@links_to_solqtl);
cmp_ok($traits, '>=', 1, "this population has $traits traits for QTL analysis");

ok($mech->find_image(alt_regex => qr/correlation/i ), "Got correlation heatmap");    
$mech->content_contains("Acronyms key", "Got trait acronyms key");


#$mech->with_test_level( process => sub {
#      my ($res, $c) = ctx_request("qtl/view/12");     
#      my $controller = SGN->Controller("Qtl");
#      
#});

}

done_testing;
