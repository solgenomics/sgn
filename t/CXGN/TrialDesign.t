use strict;
use warnings;

use Test::More tests=>78;
use Test::Exception;

BEGIN {use_ok('CXGN::TrialDesign');}

BEGIN {require_ok('Moose');}
BEGIN {require_ok('MooseX::FollowPBP');}
BEGIN {require_ok('Moose::Util::TypeConstraints');}
BEGIN {require_ok('R::YapRI::Base');}
BEGIN {require_ok('R::YapRI::Data::Matrix');}
BEGIN {require_ok('POSIX');}

my @stock_names = ("A","B","C","D","E","F","G","H","I","J","K","L");
my @control_names = ("C1","C2","C3");
my $number_of_blocks = 4;
my $number_of_reps = 2;
my $block_size = 3;
my $maximum_block_size = 14;
my $plot_name_prefix = "pre_";
my $plot_name_suffix = "_suf";
my $plot_start_number = 101;
my $plot_number_increment = 10;
my $randomization_method = "Super-Duper";
my $randomization_seed = 1;
my $design_type = "CRD";
my %design;

ok(my $trial_design = CXGN::TrialDesign->new(), "Create TrialDesign object");
ok($trial_design->set_stock_list(\@stock_names), "Set stock names for trial design");
is_deeply($trial_design->get_stock_list(),\@stock_names, "Get stock names for trial design");
ok($trial_design->set_plot_name_prefix($plot_name_prefix), "Set plot name prefix for trial design");
is_deeply($trial_design->get_plot_name_prefix(),$plot_name_prefix, "Get plot name prefix for trial design");
ok($trial_design->set_plot_name_suffix($plot_name_suffix), "Set plot name suffix for trial design");
is_deeply($trial_design->get_plot_name_suffix(),$plot_name_suffix, "Get plot name suffix for trial design");
ok($trial_design->set_plot_start_number($plot_start_number), "Set plot start number for trial design");
is_deeply($trial_design->get_plot_start_number(),$plot_start_number, "Get plot start number for trial design");
ok($trial_design->set_plot_number_increment($plot_number_increment), "Set plot number increment for trial design");
is_deeply($trial_design->get_plot_number_increment(),$plot_number_increment, "Get plot number increment for trial design");
ok($trial_design->set_randomization_method($randomization_method), "Set randomization method for trial design");
is_deeply($trial_design->get_randomization_method(),$randomization_method, "Get randomization method for trial design");
ok($trial_design->set_randomization_seed($randomization_seed), "Set randomization seed for trial design");
is_deeply($trial_design->get_randomization_seed(),$randomization_seed, "Get randomization seed for trial design");
ok($trial_design->set_design_type($design_type), "Set design type for trial design");
is_deeply($trial_design->get_design_type(),$design_type, "Get design type for trial design");

#tests for CRD
ok($trial_design->set_design_type("CRD"), "Set design type to CRD");
ok($trial_design->calculate_design(), "Calculate CRD trial design");
ok(%design = %{$trial_design->get_design()}, "Get CRD trial design");
ok($design{$plot_start_number}->{block_number} == 1, "Block number for first plot in CRD is 1");
ok($design{$plot_start_number+((scalar(@stock_names)-1)*$plot_number_increment)}->{block_number} == 1, "Block number for last plot in CRD is 1");

#tests for RCBD
ok($trial_design->set_number_of_blocks($number_of_blocks), "Set number of blocks for trial design");
is_deeply($trial_design->get_number_of_blocks(),$number_of_blocks, "Get number of blocks for trial design");
ok($trial_design->set_design_type("RCBD"), "Set design type to RCBD");
ok($trial_design->calculate_design(), "Calculate RCBD trial design");
ok(%design = %{$trial_design->get_design()}, "Get RCBD trial design");
ok(scalar(keys %design) == scalar(@stock_names) * $number_of_blocks,"Result of RCBD design has a number of plots equal to the number of stocks times the number of blocks");
ok($design{$plot_start_number}->{stock_name} eq $stock_names[0],"First plot has correct stock name");
ok($design{$plot_start_number}->{block_number} == 1, "First plot is in block 1");
ok($design{$plot_start_number+((scalar(@stock_names)-1)*$plot_number_increment)}->{block_number} == 1, "Block 1 is the right length");
ok($design{$plot_start_number+(scalar(@stock_names)*$plot_number_increment)}->{block_number} == 2, "Block 2 starts after block 1");
ok($design{$plot_start_number+$plot_number_increment}->{stock_name} eq $stock_names[1], "Second plot has correct stock name");

#tests for constructing plot names from plot start number, increment, prefix and suffix
ok($design{$plot_start_number}->{plot_name} eq $plot_name_prefix.$plot_start_number.$plot_name_suffix,"Plot names contain prefix and suffix");
ok($trial_design->set_plot_start_number(1), "Change plot start number for trial design to 1");
ok($trial_design->set_plot_number_increment(1), "Change plot number increment for trial design to 1");
ok($trial_design->calculate_design(), "Calculate design with plot start number and increment set to 1");
ok(%design = %{$trial_design->get_design()}, "Get trial design with plot start number and increment set to 1");
ok($design{1}->{stock_name} eq $stock_names[0],"First plot has correct stock name when plot number and increment are 1");
ok($design{2}->{stock_name} eq $stock_names[1],"Second plot has correct stock name when plot number and increment are 1");
ok($design{3}->{stock_name} eq $stock_names[2],"Third plot has correct stock name when plot number and increment are 1");
ok($trial_design->set_plot_start_number(-2), "Change plot start number for trial design to -2");
ok($trial_design->calculate_design(), "Calculate trial design with a negative plot start number");
ok(%design = %{$trial_design->get_design()}, "Get trial design with a negative plot start number");
ok($design{-2}->{stock_name} eq $stock_names[0],"First plot has correct stock name with a negative plot start number");
ok($design{-1}->{stock_name} eq $stock_names[1],"Second plot has correct stock name with a negative plot start number");
ok($design{0}->{stock_name} eq $stock_names[2],"Third plot has correct stock name with a negative plot start number");
ok($design{1}->{stock_name} eq $stock_names[3],"Fourth plot has correct stock name with a negative plot start number");
ok($trial_design->set_plot_start_number(2), "Change plot start number for trial design to 2");
ok($trial_design->set_plot_number_increment(-1), "Change plot number increment for trial design to -1");
ok($trial_design->calculate_design(), "Calculate trial design with a negative plot number increment");
ok(%design = %{$trial_design->get_design()}, "Get trial design with a negative plot number increment");
ok($design{2}->{stock_name} eq $stock_names[0],"First plot has correct stock name with a negative plot number increment");
ok($design{1}->{stock_name} eq $stock_names[1],"Second plot has correct stock name with a negative plot number increment");
ok($design{0}->{stock_name} eq $stock_names[2],"Third plot has correct stock name with a negative plot number increment");
ok($design{-1}->{stock_name} eq $stock_names[3],"Fourth plot has correct stock name with a negative plot number increment");

#tests for Alpha Lattice design
ok($trial_design->set_design_type("Alpha"), "Set design type to Alpha Lattice");
ok($trial_design->set_block_size($block_size), "Set block size for trial design");
is_deeply($trial_design->get_block_size(),$block_size, "Get block size for trial design");
ok($trial_design->set_number_of_reps($number_of_reps), "Set number of reps for trial design");
is_deeply($trial_design->get_number_of_reps(),$number_of_reps, "Get number of reps for trial design");
ok($trial_design->calculate_design(), "Calculate Alpha Lattice trial design");
$trial_design->set_block_size(2);
throws_ok { $trial_design->calculate_design() } '/Block size must be greater than 2/', 'Does not allow block size of 2 for alpha lattice design';
$trial_design->set_block_size(5);
throws_ok { $trial_design->calculate_design() } '/is not divisible by the block size/', 'Does not allow number of stocks that is not divisible by block size';
$trial_design->set_block_size($block_size);
$trial_design->set_number_of_reps(1);
throws_ok { $trial_design->calculate_design() } '/Number of reps for alpha lattice design must be 2 or greater/', 'Does not allow less than 2 reps for alpha lattice design';
$trial_design->set_number_of_reps($number_of_reps);

#tests for Augmented design
ok($trial_design->set_design_type("Augmented"), "Set design type to Augmented");
ok($trial_design->set_control_list(\@control_names), "Set control names for trial design");
is_deeply($trial_design->get_control_list(),\@control_names, "Get control names for trial design");
ok($trial_design->set_maximum_block_size($maximum_block_size), "Set maximum block size for trial design");
is_deeply($trial_design->get_maximum_block_size(),$maximum_block_size, "Get maximum block size for trial design");
ok($trial_design->calculate_design(), "Calculate Augmented trial design");

#tests for MADII design
ok($trial_design->set_design_type("MADII"), "Set design type to Augmented");
ok($trial_design->set_control_list(\@control_names), "Set control names for trial design");
is_deeply($trial_design->get_control_list(),\@control_names, "Get control names for trial design");
ok($trial_design->set_maximum_block_size($maximum_block_size), "Set maximum block size for trial design");
is_deeply($trial_design->get_maximum_block_size(),$maximum_block_size, "Get maximum block size for trial design");
ok($trial_design->calculate_design(), "Calculate Augmented trial design");
