use strict;
use warnings;
use Test::More;

use lib 't/lib';

use SGN::Test::WWW::Mechanize;
use Catalyst::Test 'SGN';



BEGIN {
  use_ok(  'SGN::Controller::Qtl'  )
    or BAIL_OUT('could not include SGN::Controller::Qtl');
}

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok("qtl/view/12", "Got qtl start page");
$mech->content_contains("Population summary", "there is population summary section");
$mech->content_contains("Set Statistical Parameters", "there is statistical parameters section");
$mech->content_contains("Analyze QTLs", "there is list of traits section");
$mech->content_contains("Pearson Correlation", "there is correlation section");
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

done_testing;
