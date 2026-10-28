use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Dumper;

BEGIN {use_ok('CXGN::Trial::TrialDesign');}

BEGIN {require_ok('Moose');}
BEGIN {require_ok('MooseX::FollowPBP');}
BEGIN {require_ok('Moose::Util::TypeConstraints');}
BEGIN {require_ok('R::YapRI::Base');}
BEGIN {require_ok('R::YapRI::Data::Matrix');}
BEGIN {require_ok('POSIX');}

my $design_type = "splitplot";
my %design;
my $plot_start_number;
my @stock_names;
my $treatments = {'test treatment|EXPERIMENT_TREATMENT:0000002' => [0,1]};
my @stock_list = (1..10);
my $number_of_blocks = 2;
my $layout_format = "zigzag";
my $num_plants_per_plt = 5;

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "Create TrialDesign object");
$trial_design->set_trial_name("SPLITPLOTTESTTRIAL");
ok($trial_design->set_stock_list(\@stock_list), "Set stock names for trial design");
is_deeply($trial_design->get_stock_list(),\@stock_list, "Get stock names for trial design");
ok($trial_design->set_treatments($treatments), "Set treatments for trial design");
is_deeply($trial_design->get_treatments(),$treatments, "Get treatments for trial design");
ok($trial_design->set_number_of_blocks($number_of_blocks), "Set num blocks for trial design");
is_deeply($trial_design->get_number_of_blocks(),$number_of_blocks, "Get num blocks for trial design");
ok($trial_design->set_plot_layout_format($layout_format), "Set zigzag for trial design");
is_deeply($trial_design->get_plot_layout_format(),$layout_format, "Get zigzag for trial design");
ok($trial_design->set_num_plants_per_plot($num_plants_per_plt), "Set num_plants_per_plt for trial design");
is_deeply($trial_design->get_num_plants_per_plot(),$num_plants_per_plt, "Get num_plants_per_plt for trial design");

ok($trial_design->set_design_type($design_type), "Set design type");
ok($trial_design->calculate_design(), "Calculate trial design");
ok(%design = %{$trial_design->get_design()}, "Get trial design");
is($design{'1004'}->{plot_number}, "1004");
print STDERR scalar(keys %design)."\n";
is(scalar(keys %design), 21, "Result of design");
print STDERR Dumper \%design;

done_testing();