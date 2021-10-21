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

my $design_type = "CRD";
my %design;
my $plot_start_number;
my @stock_names;
my $number_of_replicated_accession = 119;
my $number_of_unreplicated_accession = 200;
my $num_of_replicated_times = 4;
my $sub_block_sequence = '13, 1';
my $block_sequence = '13, 2';
my $col_in_design_number = 26;
my $row_in_design_number = 26;
my @stock_list = (1..319);

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "Create TrialDesign object");
$trial_design->set_trial_name("TESTTRIAL");
ok($trial_design->set_replicated_accession_no($number_of_replicated_accession), "Set replicated accessions for trial design");
is_deeply($trial_design->get_replicated_accession_no(),$number_of_replicated_accession, "Get replicated accessions for trial design");
ok($trial_design->set_unreplicated_accession_no($number_of_unreplicated_accession), "Set unreplicated accessions for trial design");
is_deeply($trial_design->get_unreplicated_accession_no(),$number_of_unreplicated_accession, "Get unreplicated accessions for trial design");
ok($trial_design->set_num_of_replicated_times($num_of_replicated_times), "Set number of replicated times for trial design");
is_deeply($trial_design->get_num_of_replicated_times(),$num_of_replicated_times, "Get number of replicated times for trial design");
ok($trial_design->set_sub_block_sequence($sub_block_sequence), "Set sub-block sequence for trial design");
is_deeply($trial_design->get_sub_block_sequence(),$sub_block_sequence, "Get sub-block sequence for trial design");
ok($trial_design->set_block_sequence($block_sequence), "Set block sequence for trial design");
is_deeply($trial_design->get_block_sequence(),$block_sequence, "Get block sequence for trial design");
ok($trial_design->set_col_in_design_number($col_in_design_number), "Set columns for trial design");
is_deeply($trial_design->get_col_in_design_number(),$col_in_design_number, "Get columns for trial design");
ok($trial_design->set_row_in_design_number($row_in_design_number), "Set rows for trial design");
is_deeply($trial_design->get_row_in_design_number(),$row_in_design_number, "Get rows for trial design");
ok($trial_design->set_stock_list(\@stock_list), "Set stock names for trial design");
is_deeply($trial_design->get_stock_list(),\@stock_list, "Get stock names for trial design");
ok($trial_design->set_design_type("p-rep"), "Set design type to p-rep");



 SKIP: {

     print STDERR "SKIPPING...\n";
     skip "DiGGer not installed, skipping", 6, unless ( -e $ENV{R_LIBS_USER}."/DiGGer";					       
     ok($trial_design->calculate_design(), "Calculate p-rep trial design");
     ok(%design = %{$trial_design->get_design()}, "Get p-rep trial design");
     ok($design{'1'}->{row_number} == 1, "First plot row_number is 1");
     ok($design{'1'}->{col_number} == 1, "First plot col_number is 1");
     is(scalar(keys %design), $row_in_design_number * $col_in_design_number, "Result of p-rep design has a number of plots equal to the product of row and column number in the design");
     print STDERR $stock_names[0] ."($plot_start_number) vs. ".$design{$plot_start_number}->{stock_name}."\n";
     print STDERR Dumper \%design;
};

done_testing();
