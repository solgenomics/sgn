use strict;
use warnings;
use Test::More;

use lib 't/lib';

use SGN::Test qw/ qsub_is_configured /;
use SGN::Test::WWW::Mechanize;
use Catalyst::Test 'SGN';



BEGIN {
  use_ok(  'SGN::Controller::Qtl'  )
    or BAIL_OUT('could not include SGN::Controller::Qtl');
}

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get_ok("/search/qtl", "Got qtl search page");
$mech->get_ok("/qtl/search", "Got qtl search page, another url");
$mech->get_ok("/qtl/search/results?trait=fruit+shape", "Got qtl search results page");
$mech->get_ok("/qtl/search/help", "Got qtl search help page");

$mech->get_ok("/qtl/form", "intro qtl data submission webform");
$mech->get_ok("/qtl/form/intro", "intro qtl data submission webform -intro");
$mech->get_ok("/qtl/form/pop_form", "population detail -- qtl data submission webform");
$mech->get_ok("/qtl/form/trait_form/12", "trait data -- qtl data submission webform");
$mech->get_ok("/qtl/form/pheno_form/12", "phenotype data -- qtl data submission webform");
$mech->get_ok("/qtl/form/geno_form/12", "genotype data -- qtl data submission webform");
$mech->get_ok("/qtl/form/stat_form/12", "statistical parameters -- qtl data submission webform");
$mech->get_ok("/qtl/form/confirm/12", "confirmation-- qtl data submission webform");

$mech->get_ok("/qtl/traits/H", "qtl traits list page");
$mech->get_ok("/qtl/submission/guide/", "qtl submission guide page");

{
local $TODO = 'qsub not configured' unless qsub_is_configured();
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

}

#$mech->with_test_level( process => sub {
#      my ($res, $c) = ctx_request("qtl/view/12");     
#      my $controller = SGN->Controller("Qtl");
#      
#});



done_testing;

