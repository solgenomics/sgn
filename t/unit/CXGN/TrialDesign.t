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
my $fieldmap_row_number = 2;
my $plot_layout_format = "serpentine";

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "Create TrialDesign object");
$trial_design->set_trial_name("TESTTRIAL");
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
ok($trial_design->set_plot_layout_format($plot_layout_format), "Set layout format for trial design");
is_deeply($trial_design->get_plot_layout_format(),$plot_layout_format, "Get layout format for trial design");
ok($trial_design->set_fieldmap_row_number($fieldmap_row_number), "Set row number for trial design");
is_deeply($trial_design->get_fieldmap_row_number(),$fieldmap_row_number, "Get row number for trial design");
$trial_design->set_fieldmap_col_number(2);

# tests for CRD
#
$trial_design->set_number_of_reps(2);
ok($trial_design->set_design_type("CRD"), "Set design type to CRD");
ok($trial_design->calculate_design(), "Calculate CRD trial design");
ok(%design = %{$trial_design->get_design()}, "Get CRD trial design");
ok($design{$plot_start_number}->{block_number} == 1, "Block number for first plot in CRD is 1");
ok($design{$plot_start_number+((scalar(@stock_names)-1)*$plot_number_increment)}->{block_number} == 1, "Block number for last plot in CRD is 1");
ok($design{'101'}->{row_number} == 1, "First plot row_number is 1");
ok($design{'101'}->{col_number} == 1, "First plot col_number is 1");

# tests for RCBD
#
ok($trial_design->set_number_of_blocks($number_of_blocks), "Set number of blocks for trial design");
is_deeply($trial_design->get_number_of_blocks(),$number_of_blocks, "Get number of blocks for trial design");
ok($trial_design->set_design_type("RCBD"), "Set design type to RCBD");
ok($trial_design->calculate_design(), "Calculate RCBD trial design");
ok(%design = %{$trial_design->get_design()}, "Get RCBD trial design");
print STDERR "RCDB DESIGN 1:";
foreach my $k (sort keys %design) {
    print STDERR $k." ".Dumper($design{$k});
}

is($design{'101'}->{row_number}, 1, "First plot row_number is 1");
is($design{'101'}->{col_number}, 1, "First plot col_number is 1");
is(scalar(keys %design), scalar(@stock_names) * $number_of_blocks,"Result of RCBD design has a number of plots equal to the number of stocks times the number of blocks");

print STDERR $stock_names[0] ."($plot_start_number) vs. ".$design{$plot_start_number}->{stock_name}."\n";
#ok($design{$plot_start_number}->{stock_name} eq $stock_names[0],"First plot has correct stock name");
print "stock_number $design{$plot_start_number}->{stock_name}\n";
ok($design{$plot_start_number}->{block_number} == 1, "First plot is in block 1");

print STDERR "PLOT START NUMBER: $plot_start_number, #STOCK ".scalar(@stock_names)." , PLOT # $plot_number_increment\n";

# check next block
#
my $next_block_plot_number = $plot_start_number+((scalar(@stock_names)-1)+ 100); #next block
print STDERR "INDEX = $next_block_plot_number\n";
print STDERR "DESING OF : ".Dumper($design{$next_block_plot_number})."\n";
print STDERR "LENGTH : ".$design{$next_block_plot_number}->{block_number}."\n"; # zero indexed, need to substract 1

my $length = $design{$next_block_plot_number}->{block_number};
is($length, 2, "Block 1 is the right length");
is($design{$next_block_plot_number}->{block_number}, 2, "Block 2 starts after block 1");
#is($design{$plot_start_number+$plot_number_increment}->{stock_name}, $stock_names[1], "Second plot has correct stock name");

# check last block
#
my $last_block_number = $plot_start_number+((scalar(@stock_names)-1) + 100 * ($number_of_blocks-1)) ; # $plot_number_increment);

print STDERR "LAST BLOCK INDEX: $last_block_number\n";
print STDERR "DESIGN OF $last_block_number = ".Dumper($design{$last_block_number});

#tests for constructing plot names from plot start number, increment, prefix and suffix
ok($design{$plot_start_number}->{plot_name} =~ /$plot_name_prefix/, "Plot names contain prefix");
ok($design{$plot_start_number}->{plot_name} =~ /$plot_name_suffix/, "Plot names contain suffix");
ok($trial_design->set_plot_start_number(1), "Change plot start number for trial design to 1");
ok($trial_design->set_plot_number_increment(1), "Change plot number increment for trial design to 1");
ok($trial_design->calculate_design(), "Calculate design with plot start number and increment set to 1");
ok(%design = %{$trial_design->get_design()}, "Get trial design with plot start number and increment set to 1");
#is($design{1}->{stock_name}, $stock_names[0],"First plot has correct stock name when plot number and increment are 1");
#is($design{2}->{stock_name}, $stock_names[1],"Second plot has correct stock name when plot number and increment are 1");
#is($design{3}->{stock_name}, $stock_names[2],"Third plot has correct stock name when plot number and increment are 1");

###
ok($trial_design->set_plot_start_number(-2), "Change plot start number for trial design to -2");
ok($trial_design->calculate_design(), "Calculate trial design with a negative plot start number");
ok(%design = %{$trial_design->get_design()}, "Get trial design with a negative plot start number");
#ok($design{-2}->{stock_name} eq $stock_names[0],"First plot has correct stock name with a negative plot start number");
#ok($design{-1}->{stock_name} eq $stock_names[1],"Second plot has correct stock name with a negative plot start number");
#ok($design{0}->{stock_name} eq $stock_names[2],"Third plot has correct stock name with a negative plot start number");
#ok($design{1}->{stock_name} eq $stock_names[3],"Fourth plot has correct stock name with a negative plot start number");



#tests for Alpha Lattice design (fail)
ok($trial_design->set_design_type("Alpha"), "Set design type to Alpha Lattice");
ok($trial_design->set_block_size($block_size), "Set block size for trial design");
is_deeply($trial_design->get_block_size(),$block_size, "Get block size for trial design");
ok($trial_design->set_number_of_reps($number_of_reps), "Set number of reps for trial design");
is_deeply($trial_design->get_number_of_reps(),$number_of_reps, "Get number of reps for trial design");
ok($trial_design->calculate_design(), "Calculate Alpha Lattice trial design");
ok(%design = %{$trial_design->get_design()}, "Get Alpha trial design");
$trial_design->set_block_size(2);
throws_ok { $trial_design->calculate_design() } '/Block size must be greater than 2/', 'Block size is larger than 2 test for alpha lattice design';
#throws_ok { $trial_design->calculate_design() } '/is not divisible by the block size/', 'Does not allow number of stocks that is not divisible by block size';
#print STDERR "OLD LIST SIZE = ".scalar(@stock_names).", new : ".scalar(@{$trial_design->get_stock_list()})."\n";
is(scalar(@stock_names), scalar(@{$trial_design->get_stock_list()}), "new stock list size test");
$trial_design->set_block_size($block_size);
$trial_design->set_number_of_reps(1);
throws_ok { $trial_design->calculate_design() } '/Number of reps for alpha lattice design must be 2 or greater/', 'Does not allow less than 2 reps for alpha lattice design';
$trial_design->set_number_of_reps($number_of_reps);

#tests for Alpha Lattice design (pass)
@stock_names = ("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T");
ok($trial_design->set_stock_list(\@stock_names), "Set stock names for trial design");
is_deeply($trial_design->get_stock_list(),\@stock_names, "Get stock names for trial design");
ok($trial_design->set_design_type("Alpha"), "Set design type to Alpha Lattice");
ok($trial_design->set_block_size(4), "Set block size for trial design");
#is_deeply($trial_design->get_block_size(),$block_size, "Get block size for trial design");
ok($trial_design->set_number_of_reps(4), "Set number of reps for trial design");
#is_deeply($trial_design->get_number_of_reps(),$number_of_reps, "Get number of reps for trial design");
ok($trial_design->set_plot_start_number($plot_start_number), "Set plot start number for trial design");
is_deeply($trial_design->get_plot_start_number(),$plot_start_number, "Get plot start number for trial design");
ok($trial_design->set_plot_number_increment($plot_number_increment), "Set plot number increment for trial design");
is_deeply($trial_design->get_plot_number_increment(),$plot_number_increment, "Get plot number increment for trial design");
ok($trial_design->calculate_design(), "Calculate Alpha Lattice trial design");
ok(%design = %{$trial_design->get_design()}, "Get Alpha trial design");
ok($design{'101'}->{row_number} == 1, "First plot row_number is 1");
ok($design{'101'}->{col_number} == 1, "First plot col_number is 1");
#print STDERR "Alpha Lattice". Dumper \%design;


#tests for Augmented design
$trial_design->set_number_of_blocks(5);
ok($trial_design->set_design_type("Augmented"), "Set design type to Augmented");
ok($trial_design->set_control_list(\@control_names), "Set control names for trial design");
is_deeply($trial_design->get_control_list(),\@control_names, "Get control names for trial design");
ok($trial_design->set_maximum_block_size($maximum_block_size), "Set maximum block size for trial design");
is_deeply($trial_design->get_maximum_block_size(),$maximum_block_size, "Get maximum block size for trial design");
ok($trial_design->calculate_design(), "Calculate Augmented trial design");


#tests for MAD design
#$trial_design->set_number_of_rows(10);
#$trial_design->set_block_row_numbers(2);
#$trial_design->set_block_col_numbers(2);
#$trial_design->set_number_of_blocks(5);
#ok($trial_design->set_design_type("MAD"), "Set design type to Augmented");
#ok($trial_design->set_control_list(\@control_names), "Set control names for trial design");
#is_deeply($trial_design->get_control_list(),\@control_names, "Get control names for trial design");
#ok($trial_design->set_maximum_block_size($maximum_block_size), "Set maximum block size for trial design");
#is_deeply($trial_design->get_maximum_block_size(),$maximum_block_size, "Get maximum block size for trial design");
#ok($trial_design->calculate_design(), "Calculate Augmented trial design");

done_testing();
