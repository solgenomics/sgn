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





$mech->with_test_level( process => sub {
      my ($res, $c) = ctx_request("qtl/view/12");     
      my $controller = SGN->Controller("Qtl");
      
});

done_testing;
