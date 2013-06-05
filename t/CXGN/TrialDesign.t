use strict;
use warnings;

use Test::More tests=>10;

BEGIN {use_ok('CXGN::TrialDesign');}
BEGIN {use_ok('Moose');}
BEGIN {use_ok('MooseX::FollowPBP');}
BEGIN {use_ok('Moose::Util::TypeConstraints');}
BEGIN {use_ok('Try::Tiny');}
BEGIN {use_ok('R::YapRI::Base');}
BEGIN {use_ok('R::YapRI::Data::Matrix');}

my @stock_names = ("A","B","C");

ok(my $trial_design = CXGN::TrialDesign->new(), "Create TrialDesign object");
ok($trial_design->set_stock_list(\@stock_names), "Set stock names for trial design");
is_deeply($trial_design->get_stock_list(),\@stock_names, "Get stock names for trial design");


