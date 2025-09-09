package CXGN::Trial::TrialDesign;

=head1 NAME

CXGN::Trial::TrialDesign - a module to create a trial design using the R CRAN package Agricolae.

=head1 USAGE

 my $trial_design = CXGN::Trial::TrialDesign->new();
 $trial_design->set_trial_name("blabla");
 $trial_design->set_stock_list( qw | A B C D |);
 $trial_design->set_seedlot_hash(\%seedlothash);
 $trial_design->set_control_list( qw | E F |);
 $trial_design->set_number_of_blocks(3);
 $trial_design->set_randomization_method("RCBD");
 if ($trial_design->calculate_design()) {  # true if no error
    $design = $trial_design->get_design();
 }

=head1 DESCRIPTION

This module uses the the R CRAN package "Agricolae" to calculate experimental designs for field layouts.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)
 Aimin Yan (ay247@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use POSIX;
use List::Util 'max';

with 'MooseX::Object::Pluggable';

has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', clearer => 'clear_trial_name');

has 'stock_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_stock_list', clearer => 'clear_stock_list');

has 'seedlot_hash' => (isa => 'HashRef', is => 'rw', predicate => 'has_seedlot_hash', clearer => 'clear_seedlot_hash');

has 'control_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_control_list', clearer => 'clear_control_list');

has 'control_list_crbd' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_control_list_crbd', clearer => 'clear_control_list_crbd');

has 'number_of_blocks' => (isa => 'Int', is => 'rw', predicate => 'has_number_of_blocks', clearer => 'clear_number_of_blocks');

has 'block_row_numbers' => (isa => 'Int', is => 'rw', predicate => 'has_block_row_numbers', clearer => 'clear_block_row_numbers');

has 'block_col_numbers' => (isa => 'Int', is => 'rw', predicate => 'has_block_col_numbers', clearer => 'clear_block_col_numbers');

has 'number_of_rows' => (isa => 'Int',is => 'rw',predicate => 'has_number_of_rows',clearer => 'clear_number_of_rows');

has 'number_of_cols' => (isa => 'Int',is => 'rw',predicate => 'has_number_of_cols',clearer => 'clear_number_of_cols');

has 'number_of_reps' => (isa => 'Int', is => 'rw', predicate => 'has_number_of_reps', clearer => 'clear_number_of_reps');

has 'block_size' => (isa => 'Int', is => 'rw', predicate => 'has_block_size', clearer => 'clear_block_size');

has 'greenhouse_num_plants' => (isa => 'ArrayRef[Int]', is => 'rw', predicate => 'has_greenhouse_num_plants', clearer => 'clear_greenhouse_num_plants');

has 'maximum_block_size' => (isa => 'Int', is => 'rw', predicate => 'has_maximum_block_size', clearer => 'clear_maximum_block_size');

has 'plot_name_prefix' => (isa => 'Str', is => 'rw', predicate => 'has_plot_name_prefix', clearer => 'clear_plot_name_prefix');

has 'plot_name_suffix' => (isa => 'Str', is => 'rw', predicate => 'has_plot_name_suffix', clearer => 'clear_plot_name_suffix');

has 'plot_start_number' => (isa => 'Int', is => 'rw', predicate => 'has_plot_start_number', clearer => 'clear_plot_start_number', default => 1);

has 'plot_number_increment' => (isa => 'Int', is => 'rw', predicate => 'has_plot_number_increment', clearer => 'clear_plot_number_increment', default => 1);


subtype 'PlotNumberingSchemeType',
    as 'Str',
    where { $_ eq "block_based" || $_ eq "consecutive" },
    message { "The string $_ is not a valid plot numbering scheme. Currently allowed are 'block_based' or 'consecutive'"};

has 'plot_numbering_scheme' => (isa => 'Maybe[PlotNumberingSchemeType]', is => 'rw', default => 'block_based'); # so far, either block_based or consecutive


has 'randomization_seed' => (isa => 'Int', is => 'rw', predicate => 'has_randomization_seed', clearer => 'clear_randomization_seed');

has 'blank' => ( isa => 'Str', is => 'rw', predicate=> 'has_blank' );

has 'fieldmap_col_number' => (isa => 'Int',is => 'rw',predicate => 'has_fieldmap_col_number',clearer => 'clear_fieldmap_col_number');

has 'fieldmap_row_number' => (isa => 'Int',is => 'rw',predicate => 'has_fieldmap_row_number',clearer => 'clear_fieldmap_row_number');

has 'plot_layout_format' => (isa => 'Str', is => 'rw', predicate => 'has_plot_layout_format', clearer => 'clear_plot_layout_format');

has 'treatments' => (isa => 'HashRef', is => 'rw', predicate => 'has_treatments', clearer => 'clear_treatments');

has 'num_plants_per_plot' => (isa => 'Int',is => 'rw',predicate => 'has_num_plants_per_plot',clearer => 'clear_num_plants_per_plot');

has 'num_seed_per_plot' => (isa => 'Int',is => 'rw',predicate => 'has_num_seed_per_plot',clearer => 'clear_num_seed_per_plot');

has 'replicated_stock_no' => (isa => 'Int',is => 'rw',predicate => 'has_replicated_stock_no',clearer => 'clear_replicated_stock_no');

has 'unreplicated_stock_no' => (isa => 'Int',is => 'rw',predicate => 'has_unreplicated_stock_no',clearer => 'clear_unreplicated_stock_no');

has 'num_of_replicated_times' => (isa => 'Int',is => 'rw',predicate => 'has_num_of_replicated_times',clearer => 'clear_num_of_replicated_times');

has 'sub_block_sequence' => (isa => 'Str', is => 'rw', predicate => 'has_sub_block_sequence', clearer => 'clear_sub_block_sequence');

has 'block_sequence' => (isa => 'Str', is => 'rw', predicate => 'has_block_sequence', clearer => 'clear_block_sequence');

has 'col_in_design_number' => (isa => 'Int',is => 'rw',predicate => 'has_col_in_design_number',clearer => 'clear_col_in_design_number');

has 'row_in_design_number' => (isa => 'Int',is => 'rw',predicate => 'has_row_in_design_number',clearer => 'clear_row_in_design_number');

has 'westcott_col' => (isa => 'Int',is => 'rw',predicate => 'has_westcott_col',clearer => 'clear_westcott_col');

has 'westcott_col_between_check' => (isa => 'Int',is => 'rw',predicate => 'has_westcott_col_between_check',clearer => 'clear_westcott_col_between_check');

has 'westcott_check_1' => (isa => 'Str',is => 'rw',predicate => 'has_westcott_check_1',clearer => 'clear_westcott_check_1');

has 'westcott_check_2' => (isa => 'Str',is => 'rw',predicate => 'has_westcott_check_2',clearer => 'clear_westcott_check_2');

subtype 'RandomizationMethodType',
  as 'Str',
  where { $_ eq "Wichmann-Hill" || $_ eq  "Marsaglia-Multicarry" || $_ eq  "Super-Duper" || $_ eq  "Mersenne-Twister" || $_ eq  "Knuth-
TAOCP" || $_ eq  "Knuth-TAOCP-2002"},
  message { "The string, $_, was not a valid randomization method"};

has 'randomization_method' => (isa => 'RandomizationMethodType', is => 'rw', default=> "Mersenne-Twister");

subtype 'DesignType',
  as 'Str',
  where { $_ eq "CRD" || $_ eq "RCBD" || $_ eq "RRC" || $_ eq "DRRC" || $_ eq "URDD" || $_ eq "Alpha" || $_ eq "Lattice" || $_ eq "Augmented" || $_ eq "MAD" || $_ eq "genotyping_plate" || $_ eq "greenhouse" || $_ eq "p-rep" || $_ eq "splitplot" || $_ eq "Westcott" || $_ eq "Analysis" },
  message { "The string, $_, was not a valid design type" };

has 'design_type' => (isa => 'DesignType', is => 'rw', predicate => 'has_design_type', clearer => 'clear_design_type');

has 'replicated_accession_no' => (isa => 'Int', is => 'rw', predicate => 'has_replicated_accession_no' );

has 'unreplicated_accession_no' => (isa => 'Maybe[Int]', is => 'rw', predicate => 'has_unreplicated_accession_no');

has 'tempfile' => (isa => "Str", is => 'rw', required => 0);

has 'backend' => (isa => "Str", is => 'rw', required => 0);

has 'submit_host' => (isa => "Str", is => 'rw', required => 0);

has 'temp_base' => (isa => "Str", is => 'rw', required => 0);

sub get_design {
    my $self = shift;
    #print STDERR Dumper $self->{design};
     return $self->{design};
}


sub calculate_design {
    my $self = shift;

    my $design;

    if ($self->has_design_type()) {
	my $design_type = $self->get_design_type();
	if ($design_type eq "p-rep") { $design_type="Prep"; }
	print STDERR "DESIGN TYPE = ".$design_type."\n";
	$self->load_plugin($design_type);
	$design = $self->create_design();
    }

    if ($design) {
	$self->{design} = $design;
	return 1;
    }
    else  {
	return 0;
    }
}

sub isint {
  my $val = shift;
  return ($val =~ m/^\d+$/);
}


sub validate_field_colNumber {
    my $colNum = shift;
    if (isint($colNum)){

	return $colNum;
    } else {
	die "Choose a different row number for field map generation. The product of number of stocks and rep when divided by row number should give an integer\n";
	return;
    }

}

sub _convert_plot_numbers {
  my $self = shift;
  my $plot_numbers_ref = shift;
  my $rep_numbers_ref = shift;
  my $number_of_reps = shift;
  my @plot_numbers = @{$plot_numbers_ref};
  my @rep_numbers = @{$rep_numbers_ref};
  my $total_plot_count = scalar(@plot_numbers);
  my $rep_plot_count = $total_plot_count / $number_of_reps;
  my $first_plot_number = 1;

  if ($self->get_plot_numbering_scheme() eq "block_based") {
      print STDERR "Block based number selected - Providing plot based numbers.\n";
      my $plot_increment;
      if ($rep_plot_count > 999) {
	  $plot_increment = 10000;
	  $first_plot_number = 10001;
      } elsif ($rep_plot_count > 99) {
	  $plot_increment = 1000;
	  $first_plot_number = 1001;
      } elsif ($rep_plot_count > 9) {
	  $plot_increment = 100;
	  $first_plot_number = 101;
      } else {
	  $plot_increment = 10;
	  $first_plot_number = 1;
      }
      my $idx = 0;
      for (my $i = 0; $i < $number_of_reps; $i++) {
	  for (my $j = 0; $j < $rep_plot_count; $j++) {
	      if ($i == 0) {
		  $plot_numbers[$idx] = $first_plot_number + $j;
		  $idx++;
	      } else {
		  $plot_numbers[$idx] = $plot_increment + $first_plot_number + $j;
		  $idx++;
	      }
	  }
	  if ($i > 0) {
	      $plot_increment += $plot_increment;
	  }
      }
  }
  else {
      print STDERR "consecutive plot numbers selected - generating consecutive numbers...\n";
      
      for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
	  my $plot_number;
	  my $first_plot_number;
	  if($self->has_plot_start_number || $self->has_plot_number_increment){
	      if ($self->has_plot_start_number()){
		  $first_plot_number = $self->get_plot_start_number();
	      } else {
		  $first_plot_number = 1;
	      }
	      if ($self->has_plot_number_increment()){
		  $plot_number = $first_plot_number + ($i * $self->get_plot_number_increment());
	      }
	      else {
		  $plot_number = $first_plot_number + $i;
	      }
	  }
	  else {
	      $plot_number = $plot_numbers[$i];
	  }
	  $plot_numbers[$i] = $plot_number;
      }
  }

  print STDERR "PLOT NUMBERS GENERATED: ".Dumper(\@plot_numbers);
  return \@plot_numbers;
}

# the function below should be split up and moved to the relevant plugin...
#
sub _build_plot_names {
    my $self = shift;
    my $design_ref = shift;
    my %design = %{$design_ref};
    my $prefix = '';
    my $suffix = '';
    my $trial_name = $self->get_trial_name;

    if ($self->has_plot_name_prefix()) {
        $prefix = $self->get_plot_name_prefix()."-";
    }
    if ($self->has_plot_name_suffix()) {
        $suffix = $self->get_plot_name_suffix();
    }

    foreach my $key (keys %design) {
	$trial_name ||="";
	my $block_number = $design{$key}->{block_number};
	my $stock_name = $design{$key}->{stock_name};
	my $rep_number = $design{$key}->{rep_number};
	$design{$key}->{plot_number} = $key;

	if ($self->get_design_type() eq "RCBD") {  # as requested by IITA (Prasad)
	    my $plot_num_per_block = $design{$key}->{plot_num_per_block};
	    $design{$key}->{plot_number} = $design{$key}->{plot_num_per_block};
	    #$design{$key}->{plot_name} = $prefix.$trial_name."_rep_".$rep_number."_".$stock_name."_".$block_number."_".$plot_num_per_block."".$suffix;
        $design{$key}->{plot_name} = $prefix.$trial_name."-rep".$rep_number."-".$stock_name."_".$plot_num_per_block."".$suffix;
	}
	elsif ($self->get_design_type() eq "Augmented") {
      my $plot_num_per_block = $design{$key}->{plot_num_per_block};
	    $design{$key}->{plot_name} = $prefix.$trial_name."-plotno".$key."-block".$block_number."-".$stock_name."_".$plot_num_per_block."".$suffix;
	}
    elsif ($self->get_design_type() eq "greenhouse") {
        $design{$key}->{plot_name} = $prefix.$trial_name."_".$stock_name."_".$key.$suffix;
    }
	else {
      my $plot_num_per_block = $design{$key}->{plot_num_per_block};
      $design{$key}->{plot_name} = $prefix.$trial_name."-rep".$rep_number."-".$stock_name."_".$plot_num_per_block."".$suffix;
	    #$design{$key}->{plot_name} = $prefix.$trial_name."_".$key.$suffix;
	}

        if($design{$key}->{subplots_names}){
            my $nums = $design{$key}->{subplots_names};
            my @named_subplots;
            foreach (@$nums){
                push @named_subplots, $design{$key}->{plot_name}."_subplot_".$_;
            }
            $design{$key}->{subplots_names} = \@named_subplots;
        }
    }

    #print STDERR Dumper(\%design);

    return \%design;
}

sub _check_controls_and_accessions_lists {
    my $self = shift;
    my @stock_list = $self->get_stock_list() ? @{$self->get_stock_list()} : ();
    my @control_list_crbd = $self->get_control_list_crbd() ? @{$self->get_control_list_crbd()} : ();
    my %control_names_lookup = map { $_ => 1 } @control_list_crbd;
    foreach my $stock_name_iter (@stock_list) {
        if (exists($control_names_lookup{$stock_name_iter})) {
            #die "Names in accessions list cannot be used also as controls. Please use separate lists for your controls and your accessions. The following accession is in both lists and is a problem: $stock_name_iter\n";
        }
    }
}

1;
