package CXGN::Trial::TrialDesign;
 
=head1 NAME

CXGN::Trial::TrialDesign - a module to create a trial design using the R CRAN package Agricolae.


=head1 USAGE

 my $trial_design = CXGN::Trial::TrialDesign->new({schema => $schema} );


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
has 'randomization_seed' => (isa => 'Int', is => 'rw', predicate => 'has_randomization_seed', clearer => 'clear_randomization_seed');
has 'blank' => ( isa => 'Str', is => 'rw', predicate=> 'has_blank' );
has 'fieldmap_col_number' => (isa => 'Int',is => 'rw',predicate => 'has_fieldmap_col_number',clearer => 'clear_fieldmap_col_number');
has 'fieldmap_row_number' => (isa => 'Int',is => 'rw',predicate => 'has_fieldmap_row_number',clearer => 'clear_fieldmap_row_number');
has 'plot_layout_format' => (isa => 'Str', is => 'rw', predicate => 'has_plot_layout_format', clearer => 'clear_plot_layout_format');
has 'treatments' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_treatments', clearer => 'clear_treatments');
has 'num_plants_per_plot' => (isa => 'Int',is => 'rw',predicate => 'has_num_plants_per_plot',clearer => 'clear_num_plants_per_plot');
has 'num_seed_per_plot' => (isa => 'Int',is => 'rw',predicate => 'has_num_seed_per_plot',clearer => 'clear_num_seed_per_plot');
has 'replicated_accession_no' => (isa => 'Int',is => 'rw',predicate => 'has_replicated_accession_no',clearer => 'clear_replicated_accession_no');
has 'unreplicated_accession_no' => (isa => 'Int',is => 'rw',predicate => 'has_unreplicated_accession_no',clearer => 'clear_unreplicated_accession_no');
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
  where { $_ eq "CRD" || $_ eq "RCBD" || $_ eq "Alpha" || $_ eq "Lattice" || $_ eq "Augmented" || $_ eq "MAD" || $_ eq "genotyping_plate" || $_ eq "greenhouse" || $_ eq "p-rep" || $_ eq "splitplot" || $_ eq "westcott" },
  message { "The string, $_, was not a valid design type" };

has 'design_type' => (isa => 'DesignType', is => 'rw', predicate => 'has_design_type', clearer => 'clear_design_type');

my $design;

sub get_design {
  return $design;
}

sub calculate_design {
  my $self = shift;
  if (!$self->has_design_type()) {
    return;
  }
  else {
    if ($self->get_design_type() eq "CRD") {
      $design = _get_crd_design($self);
    }
    elsif ($self->get_design_type() eq "RCBD") {
      $design = _get_rcbd_design($self);
    }
    elsif ($self->get_design_type() eq "Alpha") {
      $design = _get_alpha_lattice_design($self);
    }
    elsif ($self->get_design_type() eq "Lattice") {
      $design = _get_lattice_design($self);
    }
    elsif ($self->get_design_type() eq "Augmented") {
       $design = _get_augmented_design($self);
    #  $design = _get_alpha_lattice_design($self);
    }
    elsif ($self->get_design_type() eq "p-rep") {
      $design = _get_p_rep_design($self);
    }
    elsif ($self->get_design_type() eq "westcott") {
      $design = _get_westcott_design($self);
    }

#    elsif ($self->get_design_type() eq "MADII") {
#      $design = _get_madii_design($self);
#    }

    elsif($self->get_design_type() eq "MAD") {
	$design = _get_madiii_design($self);
    }
    elsif ($self->get_design_type() eq "genotyping_plate") {
	$design = $self->_get_genotyping_plate();
    }
#    elsif($self->get_design_type() eq "MADIV") {
#        $design = _get_madiv_design($self);
#    }
    elsif($self->get_design_type() eq "greenhouse") {
        $design = _get_greenhouse_design($self);
    }
    elsif($self->get_design_type() eq "splitplot") {
        $design = _get_splitplot_design($self);
    }
    else {
      die "Trial design" . $self->get_design_type() ." not supported\n";
    }
  }
  if ($design) {
    return 1;
  } else {
    return 0;
  }
}

sub _get_genotyping_plate {
    my $self = shift;
    my %gt_design;
    my @stock_list;

    if ($self->has_stock_list()) {
        @stock_list = @{$self->get_stock_list()};
        my $number_of_stocks = scalar(@stock_list);
        if ($number_of_stocks > $self->get_block_size) {
            die "Too many to fit on one plate! $number_of_stocks > ".$self->get_block_size;
        }
    }
    else {
        die "No stock list specified\n";
    }

    my $blank = $self->get_blank ? $self->get_blank : ' ';

    if ($self->get_block_size == '96'){
        foreach my $row ("A".."H") {
            foreach my $col (1..12) {
                my $well= sprintf "%s%02d", $row, $col;

                if ($well eq $blank) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well."_BLANK",
                        stock_name => "BLANK",
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 1
                    };
                }
                elsif (@stock_list) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well,
                        stock_name => shift(@stock_list),
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 0
                    };
                }
            }
        }
    }
    if ($self->get_block_size == '384'){
        foreach my $row ("A".."P") {
            foreach my $col (1..24) {
                my $well= sprintf "%s%02d", $row, $col;

                if ($well eq $blank) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well."_BLANK",
                        stock_name => "BLANK",
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 1
                    };
                }
                elsif (@stock_list) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well,
                        stock_name => shift(@stock_list),
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 0
                    };
                }
            }
        }
    }

    return \%gt_design;
}

sub isint{
  my $val = shift;
  return ($val =~ m/^\d+$/);
}

sub _validate_field_colNumber {
  my $colNum = shift;
  if (isint($colNum)){
    return $colNum;
  } else {
      die "Choose a different row number for field map generation. The product of number of accessions and rep when divided by row number should give an integer\n";
      return;
  }

}

sub _get_crd_design {
    my $self = shift;
    my %crd_design;
    #$self->set_number_of_blocks(1);
    #%crd_design=%{_get_rcbd_design($self)};
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $number_of_blocks;
    my $number_of_reps;
    my $stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @rep_numbers;
    my @converted_plot_numbers;
    my $number_of_stocks;
    my @control_list_crbd;
    my %control_names_lookup;
    my $fieldmap_row_number;
    my @fieldmap_row_numbers;
    my $fieldmap_col_number;
    my $plot_layout_format;
    my @col_number_fieldmaps;
    if ($self->has_stock_list()) {
        @stock_list = @{$self->get_stock_list()};
        $number_of_stocks = scalar(@stock_list);
    } else {
        die "No stock list specified\n";
    }
    if ($self->has_control_list_crbd()) {
      @control_list_crbd = @{$self->get_control_list_crbd()};
      %control_names_lookup = map { $_ => 1 } @control_list_crbd;
      $self->_check_controls_and_accessions_lists;
    }
    if ($self->has_number_of_reps()) {
        $number_of_reps = $self->get_number_of_reps();
    } else {
        die "Number of reps not specified\n";
    }

    if ($self->has_fieldmap_col_number()) {
      $fieldmap_col_number = $self->get_fieldmap_col_number();
    }
    if ($self->has_fieldmap_row_number()) {
      $fieldmap_row_number = $self->get_fieldmap_row_number();
      my $colNumber = ((scalar(@stock_list) * $number_of_reps)/$fieldmap_row_number);
      $fieldmap_col_number = _validate_field_colNumber($colNumber);

      #if (isint($colNumber)){
        #$fieldmap_col_number = $colNumber;
      #} else {
      #    die "Choose a different row number for field map generation. The product of number of accessions and rep when divided by row number should give an integer\n";
      #}
    }

    if ($self->has_plot_layout_format()) {
      $plot_layout_format = $self->get_plot_layout_format();
    }

    if (scalar(@stock_list)>1) {

        $stock_data_matrix =  R::YapRI::Data::Matrix->new({
            name => 'stock_data_matrix',
            rown => 1,
            coln => scalar(@stock_list),
            data => \@stock_list,
        });
        #print STDERR Dumper $stock_data_matrix;

        $r_block = $rbase->create_block('r_block');
        $stock_data_matrix->send_rbase($rbase, 'r_block');

        $r_block->add_command('library(agricolae)');
        $r_block->add_command('trt <- stock_data_matrix[1,]');
        $r_block->add_command('rep_vector <- rep('.$number_of_reps.',each='.$number_of_stocks.')');
        $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

        if ($self->has_randomization_seed()){
            $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
            $r_block->add_command('crd<-design.crd(trt,rep_vector,serie=3,kinds=randomization_method, seed=randomization_seed)');
        }
        else {
            $r_block->add_command('crd<-design.crd(trt,rep_vector,serie=3,kinds=randomization_method)');
        }
        $r_block->add_command('crd<-crd$book'); #added for agricolae 1.1-8 changes in output
        $r_block->add_command('crd<-as.matrix(crd)');
        $r_block->run_block();
        $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','crd');
        #print STDERR Dumper $result_matrix;

        @plot_numbers = $result_matrix->get_column("plots");
        #print STDERR Dumper \@plot_numbers;

        @rep_numbers = $result_matrix->get_column("r");
        @stock_names = $result_matrix->get_column("trt");
        @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};
        #print STDERR Dumper \@converted_plot_numbers;

        #generate col_number
        if ($plot_layout_format eq "zigzag") {
          if (!$fieldmap_col_number){
            @col_number_fieldmaps = ((1..(scalar(@stock_list))) x $number_of_reps);
          } else {
            @col_number_fieldmaps = ((1..$fieldmap_col_number) x $fieldmap_row_number);
          }
          #print STDERR Dumper(\@col_number_fieldmaps);
        }
        elsif ($plot_layout_format eq "serpentine") {
          if (!$fieldmap_row_number)  {
            for my $rep (1 .. $number_of_reps){
              if ($rep % 2){
                push @col_number_fieldmaps, (1..(scalar(@stock_list)));
              } else {
                push @col_number_fieldmaps, (reverse 1..(scalar(@stock_list)));
              }
            }
          } else {
            for my $rep (1 .. $fieldmap_row_number){
              if ($rep % 2){
                push @col_number_fieldmaps, (1..$fieldmap_col_number);
              } else {
                push @col_number_fieldmaps, (reverse 1..$fieldmap_col_number);
              }
            }
          }
          #@col_number_fieldmaps = (my @cols, (1..(scalar(@stock_list))) x $number_of_reps);
        }

    } else { #only a single stock was given, so no randomization can occur.
        @converted_plot_numbers = (1...$number_of_reps);
        @rep_numbers = (1...$number_of_reps);
        @stock_names = ($stock_list[0]) x $number_of_reps;
    }

    if ($plot_layout_format && !$fieldmap_col_number && !$fieldmap_row_number){
      @fieldmap_row_numbers = sort(@rep_numbers);
    }
    elsif ($plot_layout_format && $fieldmap_row_number){
      @fieldmap_row_numbers = ((1..$fieldmap_row_number) x $fieldmap_col_number);
      @fieldmap_row_numbers = sort {$a <=> $b} @fieldmap_row_numbers;
    }

    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
    for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
        my %plot_info;

        $plot_info{'stock_name'} = $stock_names[$i];
        $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
        if ($plot_info{'seedlot_name'}){
            $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
        }
        $plot_info{'block_number'} = 1;
        $plot_info{'rep_number'} = $rep_numbers[$i];
        $plot_info{'plot_name'} = $converted_plot_numbers[$i];
        $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
        if ($fieldmap_row_numbers[$i]){
          $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
          $plot_info{'col_number'} = $col_number_fieldmaps[$i];
        }
        $crd_design{$converted_plot_numbers[$i]} = \%plot_info;
    }

    #print STDERR Dumper \%crd_design;

    %crd_design = %{_build_plot_names($self,\%crd_design)};
    return \%crd_design;
}

sub _get_westcott_design {
    my $self = shift;
    my %westcott_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $stock_data_matrix;
    my @control_list;
    my %control_names_lookup;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my $westcott_col;
    my $westcott_check_2;
    my $westcott_check_1;
    my $westcott_col_between_check;
    
    if ($self->has_stock_list()) {
      @stock_list = @{$self->get_stock_list()};
    } else {
      die "No stock list specified\n";
    }
    if ($self->has_control_list_crbd()) {
      @control_list = @{$self->get_control_list_crbd()};
      %control_names_lookup = map { $_ => 1 } @control_list;
      $self->_check_controls_and_accessions_lists;
    }
    if ($self->has_westcott_col()) {
      $westcott_col = $self->get_westcott_col();
    }
    if ($self->has_westcott_check_2()) {
      $westcott_check_2 = $self->get_westcott_check_2();
    }
    if ($self->has_westcott_check_1()) {
      $westcott_check_1 = $self->get_westcott_check_1();
    }
    if ($self->has_westcott_col_between_check()) {
      $westcott_col_between_check = $self->get_westcott_col_between_check();
    }
    
    $stock_data_matrix =  R::YapRI::Data::Matrix->new({
        name => 'stock_data_matrix',
        rown => 1,
        coln => scalar(@stock_list),
        data => \@stock_list,
    });
    
    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block'); 
    $r_block->add_command('library(devtools)');
    $r_block->add_command('library(st4gi)');
    $r_block->add_command('geno <-  stock_data_matrix[1,]');
    $r_block->add_command('ch1 <- "'.$westcott_check_1.'"'); 
    $r_block->add_command('ch2 <- "'.$westcott_check_2.'"');
    $r_block->add_command('nc <- '.$westcott_col); 
    if ($westcott_col_between_check){
        $r_block->add_command('ncb <- '.$westcott_col_between_check);
        $r_block->add_command('westcott<-cd.w(geno, ch1, ch2, nc, ncb=ncb)');
    }
    else{
        $r_block->add_command('westcott<-cd.w(geno, ch1, ch2, nc)');
    }
    $r_block->add_command('westcott<-westcott$book');
    $r_block->add_command('westcott<-as.matrix(westcott)');
    $r_block->run_block();
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','westcott');
    @plot_numbers = $result_matrix->get_column("plot");
    @stock_names = $result_matrix->get_column("geno");
    my @row_numbers = $result_matrix->get_column("row");
    my @col_numbers = $result_matrix->get_column("col");
    @block_numbers = $result_matrix->get_column("row");
    
    @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)}; 
    
    my $counting = 0;
    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
    for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
      my %plot_info;

      $plot_info{'seedlot_name'} = $seedlot_hash{$plot_info{'stock_name'}}->[0];
      if ($plot_info{'seedlot_name'}){
          $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
      }
      $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
      $plot_info{'stock_name'} = $stock_names[$i];
      $plot_info{'block_number'} = $block_numbers[$i];
      $plot_info{'plot_name'} = $converted_plot_numbers[$i];
      $plot_info{'row_number'} = $row_numbers[$i];
      $plot_info{'col_number'} = $col_numbers[$i];

      $westcott_design{$converted_plot_numbers[$i]} = \%plot_info;
    }
    %westcott_design = %{_build_plot_names($self,\%westcott_design)};

    return \%westcott_design;   

}

sub _get_p_rep_design {
    my $self = shift;
    my %prep_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my $number_of_replicated_accession;
    my $number_of_unreplicated_accession;
    my $num_of_replicated_times;
    my $sub_block_sequence;
    my $block_sequence;
    my $col_in_design_number;
    my $row_in_design_number;
    
    if ($self->has_stock_list()) {
      @stock_list = @{$self->get_stock_list()};
    } else {
      die "No stock list specified\n";
    }
    if ($self->has_replicated_accession_no()) {
      $number_of_replicated_accession = $self->get_replicated_accession_no();
    } 
    if ($self->has_unreplicated_accession_no()) {
      $number_of_unreplicated_accession = $self->get_unreplicated_accession_no();
    } 
    if ($self->has_num_of_replicated_times()) {
      $num_of_replicated_times = $self->get_num_of_replicated_times();
    } 
    if ($self->has_sub_block_sequence()) {
      $sub_block_sequence = $self->get_sub_block_sequence();
    }
    if ($self->has_block_sequence()) {
      $block_sequence = $self->get_block_sequence();
    }
    if ($self->has_col_in_design_number()) {
      $col_in_design_number = $self->get_col_in_design_number();
    }   
    if ($self->has_row_in_design_number()) {
      $row_in_design_number = $self->get_row_in_design_number();
    }
    
    $stock_data_matrix =  R::YapRI::Data::Matrix->new(
  						       {
  							name => 'stock_data_matrix',
  							rown => 1,
  							coln => scalar(@stock_list),
  							data => \@stock_list,
  						       }
  						      );
                              
    my %stock_data_hash;
    my $count = 0;
    my @counts;
    foreach my $x (@stock_list){
        $count ++;
        push @counts, $count;
    }
    for (my $n=0; $n<scalar(@stock_list); $n++) {
        $stock_data_hash{$counts[$n]} = $stock_list[$n];
    }
    my ($no_row_in_block,$no_block_in_design) = split(',', $block_sequence);
    $no_row_in_block = $no_row_in_block * $col_in_design_number;
    
    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block'); 
    $r_block->add_command('library(DiGGer)');
    $r_block->add_command('library(R.methodsS3)'); 
    $r_block->add_command('library(reshape)');
    $r_block->add_command('library(R.oo)');
    $r_block->add_command('numberOfTreatments <- ' .$stock_data_matrix->{coln}); 
    $r_block->add_command('rowsInDesign <- '.$row_in_design_number); 
    $r_block->add_command('columnsInDesign <- '.$col_in_design_number);
    $r_block->add_command('blockSequence <- list(c('.$block_sequence.'), c('.$sub_block_sequence.'))'); 
    $r_block->add_command('treatRepPerRep <- rep(c(1,'.$num_of_replicated_times.'), c('.$number_of_unreplicated_accession.', '.$number_of_replicated_accession.'))');
    $r_block->add_command('treatGroup <- rep(c(1, 2), c('.$number_of_unreplicated_accession.', '.$number_of_replicated_accession.'))');
    $r_block->add_command('rngSeeds <- c(156, 444)');
    $r_block->add_command('runSearch <- TRUE');
    $r_block->add_command('pRepDesign <- prDiGGer(numberOfTreatments = numberOfTreatments,
                                                rowsInDesign = rowsInDesign,
                                                columnsInDesign = columnsInDesign,
                                                blockSequence = blockSequence,
                                                treatRepPerRep = treatRepPerRep, 
                                                treatGroup = treatGroup, 
                                                rngSeeds = rngSeeds, 
                                                runSearch = runSearch )');
    #$r_block->add_command('pRepDesign <- run(pRepDesign)');                                            
    #$r_block->add_command('designBlock <- desTab(getDesign(pRepDesign), '.$block_sequence.')');  print "PARAMETER: 13\n";
    $r_block->add_command('field_map <- getDesign(pRepDesign)');
    $r_block->add_command('field_map_t <- t(field_map)');
    $r_block->add_command('field_map_melt <- melt(field_map_t)');
    $r_block->add_command('colnames(field_map_melt) <- c("col_number","row_number","trt")');
    $r_block->add_command('rownames(field_map_melt) <- rownames(field_map_melt, do.NULL = FALSE, prefix = "Obs.")');
    $r_block->add_command('dim_trt <- dim(field_map_melt)[1]');
    $r_block->add_command('blockNo <- rep(1:'.$no_block_in_design.', each='.$no_row_in_block.')');
    $r_block->add_command('blockNo <- melt(blockNo)');
    $r_block->add_command('colnames(blockNo) <- c("block")');
    $r_block->add_command('rownames(blockNo) <- rownames(blockNo, do.NULL = FALSE, prefix = "Obs.")');
    $r_block->add_command('blockNo_merge <- match(rownames(field_map_melt), rownames(blockNo) )');
    $r_block->add_command('blockNo_merge <- cbind( field_map_melt, blockNo[blockNo_merge,] )');
    $r_block->add_command('colnames(blockNo_merge) <- c("col_number","row_number","trt","block")');
    $r_block->add_command('rownames(blockNo_merge) <- rownames(blockNo_merge, do.NULL = FALSE, prefix = "Obs.")');
    $r_block->add_command('plot_num <- c(1:dim_trt)');
    $r_block->add_command('plot_num <- t(plot_num)');
    $r_block->add_command('plot_num <- melt(plot_num)');
    $r_block->add_command('colnames(plot_num) <- c("p2","p1","plots")');
    $r_block->add_command('rownames(plot_num) <- rownames(plot_num, do.NULL = FALSE, prefix = "Obs.")');
    #$r_block->add_command('layout_merge <- match(rownames(field_map_melt), rownames(plot_num) )');
    #$r_block->add_command('layout_merge <- cbind( field_map_melt, plot_num[layout_merge,] )');
    $r_block->add_command('layout_merge <- match(rownames(blockNo_merge), rownames(plot_num) )');
    $r_block->add_command('layout_merge <- cbind( blockNo_merge, plot_num[layout_merge,] )');
    $r_block->add_command('layout <- subset(layout_merge, select = c(plots, block, row_number, col_number, trt))');
    $r_block->add_command('pRepDesign <- as.matrix(layout)');
    #$r_block->run_block();
    
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','pRepDesign');
     @plot_numbers = $result_matrix->get_column("plots");
     @stock_names = $result_matrix->get_column("trt");
     my @row_numbers = $result_matrix->get_column("row_number");
     my @col_numbers = $result_matrix->get_column("col_number");
     @block_numbers = $result_matrix->get_column("block");
     @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};
     
     my $counting = 0;
     my %seedlot_hash;
     if($self->get_seedlot_hash){
         %seedlot_hash = %{$self->get_seedlot_hash};
     }
     for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
       my %plot_info;
       $counting++;
       foreach my $key (keys %stock_data_hash){
           if ($stock_names[$i] == $key && $plot_numbers[$i] eq $counting){
               $plot_info{'stock_name'} = $stock_data_hash{$key};
           }
       }
       $plot_info{'seedlot_name'} = $seedlot_hash{$plot_info{'stock_name'}}->[0];
       if ($plot_info{'seedlot_name'}){
           $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
       }
       $plot_info{'block_number'} = $block_numbers[$i];
       $plot_info{'plot_name'} = $converted_plot_numbers[$i];
       $plot_info{'row_number'} = $row_numbers[$i];
       $plot_info{'col_number'} = $col_numbers[$i];

       $prep_design{$converted_plot_numbers[$i]} = \%plot_info;
     }
     %prep_design = %{_build_plot_names($self,\%prep_design)};
     return \%prep_design;

}

sub _get_rcbd_design {
  my $self = shift;
  my %rcbd_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $number_of_blocks;
  my $stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @control_names_crbd;
  my @block_numbers;
  my @converted_plot_numbers;
  my @control_list_crbd;
  my %control_names_lookup;
  my $fieldmap_row_number;
  my @fieldmap_row_numbers;
  my $fieldmap_col_number;
  my $plot_layout_format;
  my @col_number_fieldmaps;

  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_control_list_crbd()) {
    @control_list_crbd = @{$self->get_control_list_crbd()};
    %control_names_lookup = map { $_ => 1 } @control_list_crbd;
    $self->_check_controls_and_accessions_lists;
  }
  if ($self->has_number_of_blocks()) {
    $number_of_blocks = $self->get_number_of_blocks();
  } else {
    die "Number of blocks not specified\n";
  }

  if ($self->has_fieldmap_col_number()) {
    $fieldmap_col_number = $self->get_fieldmap_col_number();
  }
  if ($self->has_fieldmap_row_number()) {
    $fieldmap_row_number = $self->get_fieldmap_row_number();
    my $colNumber = ((scalar(@stock_list) * $number_of_blocks)/$fieldmap_row_number);
    $fieldmap_col_number = _validate_field_colNumber($colNumber);
  }
  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );

  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('rcbd<-design.rcbd(trt,number_of_blocks,serie=3,kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('rcbd<-design.rcbd(trt,number_of_blocks,serie=3,kinds=randomization_method)');
  }
  $r_block->add_command('rcbd<-rcbd$book'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('rcbd<-as.matrix(rcbd)');
  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','rcbd');
  #print STDERR Dumper $result_matrix;
  @plot_numbers = $result_matrix->get_column("plots");
  #print STDERR Dumper \@plot_numbers;
  @block_numbers = $result_matrix->get_column("block");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  #generate col_number

  if ($plot_layout_format eq "zigzag") {
    if (!$fieldmap_col_number){
      @col_number_fieldmaps = ((1..(scalar(@stock_list))) x $number_of_blocks);
    } else {
      @col_number_fieldmaps = ((1..$fieldmap_col_number) x $fieldmap_row_number);
    }
  }
  elsif ($plot_layout_format eq "serpentine") {
    if (!$fieldmap_row_number)  {
      for my $rep (1 .. $number_of_blocks){
        if ($rep % 2){
          push @col_number_fieldmaps, (1..(scalar(@stock_list)));
        } else {
          push @col_number_fieldmaps, (reverse 1..(scalar(@stock_list)));
        }
      }
    } else {
      for my $rep (1 .. $fieldmap_row_number){
        if ($rep % 2){
          push @col_number_fieldmaps, (1..$fieldmap_col_number);
        } else {
          push @col_number_fieldmaps, (reverse 1..$fieldmap_col_number);
        }
      }
    }
  }

  if ($plot_layout_format && !$fieldmap_col_number && !$fieldmap_row_number){
    @fieldmap_row_numbers = (@block_numbers);
  }
  elsif ($plot_layout_format && $fieldmap_row_number){
      @fieldmap_row_numbers = ((1..$fieldmap_row_number) x $fieldmap_col_number);
      @fieldmap_row_numbers = sort {$a <=> $b} @fieldmap_row_numbers;
    }

    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'rep_number'} = $block_numbers[$i];
    $plot_info{'plot_num_per_block'} = $plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    #$plot_info_per_block{}
      if ($fieldmap_row_numbers[$i]){
      $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
      $plot_info{'col_number'} = $col_number_fieldmaps[$i];
    }
    $rcbd_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %rcbd_design = %{_build_plot_names($self,\%rcbd_design)};
  return \%rcbd_design;
}

sub _get_alpha_lattice_design {
  my $self = shift;
  my %alpha_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $block_size;
  my $number_of_blocks;
  my $number_of_reps;
  my $stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @block_numbers;
  my @rep_numbers;
  my @converted_plot_numbers;
  my @control_list_crbd;
  my %control_names_lookup;
  my $fieldmap_row_number;
  my @fieldmap_row_numbers;
  my $fieldmap_col_number;
  my $plot_layout_format;
  my @col_number_fieldmaps;
  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_control_list_crbd()) {
    @control_list_crbd = @{$self->get_control_list_crbd()};
    %control_names_lookup = map { $_ => 1 } @control_list_crbd;
    $self->_check_controls_and_accessions_lists;
  }

  if ($self->has_number_of_reps()) {
    $number_of_reps = $self->get_number_of_reps();
    if ($number_of_reps < 2) {
      die "Number of reps for alpha lattice design must be 2 or greater\n";
    }
  } else {
    die "Number of reps not specified\n";
  }

  if ($self->has_fieldmap_col_number()) {
    $fieldmap_col_number = $self->get_fieldmap_col_number();
  }

  if ($self->has_block_size()) {
    $block_size = $self->get_block_size();
    print STDERR "block size = $block_size\n";
    if ($block_size < 3) {
      die "Block size must be greater than 2 for alpha lattice design\n";
    }
    #	print "stock_list: ".scalar(@stock_list)."block_size: $block_size\n";
    if (scalar(@stock_list) % $block_size != 0) {
      die "Number of stocks (".scalar(@stock_list).") for alpha lattice design is not divisible by the block size ($block_size)\n";
	}
#     else {
# 		my $dummy_var = scalar(@stock_list) % $block_size;
# 		my $stocks_to_add = $block_size - $dummy_var;
# #		print "$stock_list\n";
# 		foreach my $stock_list_rep(1..$stocks_to_add) {
# 			push(@stock_list, $stock_list[0]);
# 		}
#         print STDERR Dumper(\@stock_list);
# 		$self->set_stock_list(\@stock_list);
# 	}

    $number_of_blocks = scalar(@stock_list)/$block_size;
     if ($number_of_blocks < $block_size) {
       die "The number of blocks ($number_of_blocks) for alpha lattice design must not be less than the block size ($block_size)\n";
     }
    } else {
     die "No block size specified\n";
   }

  if ($self->has_fieldmap_row_number()) {
    $fieldmap_row_number = $self->get_fieldmap_row_number();
      my $colNumber = ((scalar(@stock_list) * $number_of_reps)/$fieldmap_row_number);
      $fieldmap_col_number = _validate_field_colNumber($colNumber);
  }
  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');

  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('block_size <- '.$block_size);
  $r_block->add_command('number_of_reps <- '.$number_of_reps);
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('alpha<-design.alpha(trt,block_size,number_of_reps,serie=3,kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('alpha<-design.alpha(trt,block_size,number_of_reps,serie=3,kinds=randomization_method)');
  }
  $r_block->add_command('alpha_book<-alpha$book');
  $r_block->add_command('alpha_book<-as.matrix(alpha_book)');

 my @commands = $r_block->read_commands();
    print STDERR join "\n", @commands;
    print STDERR "\n";


  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','alpha_book');
  @plot_numbers = $result_matrix->get_column("plots");
  @block_numbers = $result_matrix->get_column("block");
  @rep_numbers = $result_matrix->get_column("replication");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  if ($plot_layout_format eq "zigzag") {
    if (!$fieldmap_col_number){
      @col_number_fieldmaps = ((1..$number_of_blocks) x ($number_of_blocks * $number_of_reps));
      #print STDERR Dumper(\@col_number_fieldmaps);
    } else {
        @col_number_fieldmaps = ((1..$fieldmap_col_number) x $fieldmap_row_number);
      }
  }
  elsif ($plot_layout_format eq "serpentine") {
    if (!$fieldmap_row_number)  {
      for my $rep (1 .. ($number_of_blocks * $number_of_reps)){
        if ($rep % 2){
          push @col_number_fieldmaps, (1..$number_of_blocks);
        } else {
          push @col_number_fieldmaps, (reverse 1..$number_of_blocks);
        }
      }
    } else {
        for my $rep (1 .. $fieldmap_row_number){
          if ($rep % 2){
            push @col_number_fieldmaps, (1..$fieldmap_col_number);
          } else {
              push @col_number_fieldmaps, (reverse 1..$fieldmap_col_number);
          }
        }
      }
  }

  if ($plot_layout_format && !$fieldmap_col_number && !$fieldmap_row_number){
    @fieldmap_row_numbers = (@block_numbers);
  }
  elsif ($plot_layout_format && $fieldmap_row_number){
      @fieldmap_row_numbers = ((1..$fieldmap_row_number) x $fieldmap_col_number);
      @fieldmap_row_numbers = sort {$a <=> $b} @fieldmap_row_numbers;
    }

    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'rep_number'} = $rep_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    if ($fieldmap_row_numbers[$i]){
      $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
      $plot_info{'col_number'} = $col_number_fieldmaps[$i];
    }
    $alpha_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %alpha_design = %{_build_plot_names($self,\%alpha_design)};
  return \%alpha_design;
}

sub _get_lattice_design {
  my $self = shift;
  my %lattice_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $number_of_blocks;
  my $number_of_reps;
  my $stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @block_numbers;
  my @rep_numbers;
  my @converted_plot_numbers;
  my @control_list_crbd;
  my %control_names_lookup;
  my $fieldmap_row_number;
  my @fieldmap_row_numbers;
  my $fieldmap_col_number;
  my $plot_layout_format;
  my @col_number_fieldmaps;
  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  my $block_number_calculated = sqrt(scalar(@stock_list));
  if ($block_number_calculated =~ /^\d+$/ ){
      $number_of_blocks = $block_number_calculated;
  } else {
    die "Square root of Number of stocks (".scalar(@stock_list).") for lattice design should give a whole number.\n";
  }

  if ($self->has_control_list_crbd()) {
    @control_list_crbd = @{$self->get_control_list_crbd()};
    %control_names_lookup = map { $_ => 1 } @control_list_crbd;
    $self->_check_controls_and_accessions_lists;
  }

   if ($self->has_number_of_reps()) {
     $number_of_reps = $self->get_number_of_reps();
     if ($number_of_reps == 2 || $number_of_reps == 3){
      } else {
          die "Number of reps should be 2 for SIMPLE and 3 for TRIPLE lattice design.\n";
      }
   } else {
     die "Number of reps not specified\n";
   }

  if ($self->has_fieldmap_col_number()) {
    $fieldmap_col_number = $self->get_fieldmap_col_number();
  }

  if ($self->has_fieldmap_row_number()) {
    $fieldmap_row_number = $self->get_fieldmap_row_number();
      my $colNumber = ((scalar(@stock_list) * $number_of_reps)/$fieldmap_row_number);
      $fieldmap_col_number = _validate_field_colNumber($colNumber);
  }
  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  #$r_block->add_command('block_size <- '.$block_size);
  $r_block->add_command('number_of_reps <- '.$number_of_reps);
  #$r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('lattice<-design.lattice(trt,r=number_of_reps,serie=3,kinds="Super-Duper", seed=randomization_seed)');
  }
  else {
    $r_block->add_command('lattice<-design.lattice(trt,r=number_of_reps,serie=3,kinds="Super-Duper")');
  }
  $r_block->add_command('lattice_book<-lattice$book');
  $r_block->add_command('lattice_book<-as.matrix(lattice_book)');

 my @commands = $r_block->read_commands();
    print STDERR join "\n", @commands;
    print STDERR "\n";


  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','lattice_book');
  @plot_numbers = $result_matrix->get_column("plots");
  #print STDERR Dumper(@plot_numbers);
  @block_numbers = $result_matrix->get_column("block");
  my $max = max( @block_numbers );
  @rep_numbers = $result_matrix->get_column("r");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  if ($plot_layout_format eq "zigzag") {
    if (!$fieldmap_col_number){
      @col_number_fieldmaps = ((1..$number_of_blocks) x ($number_of_blocks * $number_of_reps));
      #print STDERR Dumper(\@col_number_fieldmaps);
    } else {
        @col_number_fieldmaps = ((1..$fieldmap_col_number) x $fieldmap_row_number);
      }
  }
  elsif ($plot_layout_format eq "serpentine") {
    if (!$fieldmap_row_number)  {
      for my $rep (1 .. ($number_of_blocks * $number_of_reps)){
        if ($rep % 2){
          push @col_number_fieldmaps, (1..$number_of_blocks);
        } else {
          push @col_number_fieldmaps, (reverse 1..$number_of_blocks);
        }
      }
    } else {
        for my $rep (1 .. $fieldmap_row_number){
          if ($rep % 2){
            push @col_number_fieldmaps, (1..$fieldmap_col_number);
          } else {
              push @col_number_fieldmaps, (reverse 1..$fieldmap_col_number);
          }
        }
      }
  }

  if ($plot_layout_format && !$fieldmap_col_number && !$fieldmap_row_number){
    @fieldmap_row_numbers = (@block_numbers);
  }
  elsif ($plot_layout_format && $fieldmap_row_number){
      @fieldmap_row_numbers = ((1..$fieldmap_row_number) x $fieldmap_col_number);
      @fieldmap_row_numbers = sort {$a <=> $b} @fieldmap_row_numbers;
    }

    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'rep_number'} = $rep_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    if ($fieldmap_row_numbers[$i]){
      $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
      $plot_info{'col_number'} = $col_number_fieldmaps[$i];
    }
    $lattice_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %lattice_design = %{_build_plot_names($self,\%lattice_design)};
  return \%lattice_design;
}

sub _get_augmented_design {
  my $self = shift;
  my %augmented_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my @control_list;
  my $maximum_block_size;
  my $number_of_blocks;
  my $stock_data_matrix;
  my $control_stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @block_numbers;
  my @converted_plot_numbers;
  my %control_names_lookup;

  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    $self->_check_controls_and_accessions_lists;
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }

  if ($self->has_maximum_block_size()) {
    $maximum_block_size = $self->get_maximum_block_size();
    if ($maximum_block_size <= scalar(@control_list)) {
      die "Maximum block size must be greater the number of control stocks for augmented design\n";
    }
    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
    }
    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
  } else {
    die "No block size specified\n";
  }

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );

  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );
  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');
  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('control_trt <- control_stock_data_matrix[1,]');
  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=3,kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=3,kinds=randomization_method)');
  }
  $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('augmented<-as.matrix(augmented)');

  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');
  @plot_numbers = $result_matrix->get_column("plots");
  @block_numbers = $result_matrix->get_column("block");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  my %seedlot_hash;
  if($self->get_seedlot_hash){
      %seedlot_hash = %{$self->get_seedlot_hash};
  }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $augmented_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %augmented_design = %{_build_plot_names($self,\%augmented_design)};
  return \%augmented_design;

}

sub _get_madii_design {
    my $self = shift;
    my %madii_design;

    my $rbase = R::YapRI::Base->new();

    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;
    my $number_of_rows;
    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    my @row_numbers;
    my @check_names;
    my @col_numbers;

    my $block_row_number;
    my $block_col_number;
    my @block_row_numbers;
    my @block_col_numbers;


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    $self->_check_controls_and_accessions_lists;
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }

#    if ($self->has_number_of_blocks()) {
#    $number_of_blocks = $self->get_number_of_blocks();
#    } else {
#    die "Number of blocks not specified\n";
#    }

   if ($self->has_number_of_rows()) {
    $number_of_rows = $self->get_number_of_rows();
    } else {
    die "Number of rows not specified\n";
    }

    #system("R --slave --args $tempfile $tempfile_out < R/MADII_layout_function.R");
#     system("R --slave < R/MADII_layout_function.R");


#    if ($self->has_maximum_row_number()) {
#    $maximum_row_number = $self->get_maximum_row_number();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#
#  } else {
#    die "No block size specified\n";
#  }


#  if ($self->has_maximum_block_size()) {
#    $maximum_block_size = $self->get_maximum_block_size();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#  } else {
#    die "No block size specified\n";
#  }

#=comment

  print STDERR join "\n", "@stock_list\n";

  print STDERR join "\n", "$number_of_rows\n";

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');

 #$r_block->add_command('library(agricolae)');

  $r_block->add_command('library(MAD)');


  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');


#  $r_block->add_command('trt <- stock_data_matrix[1,]');
#  $r_block->add_command('control_trt <- control_stock_data_matrix[1,]');



#  $r_block->add_command('acc<-c(seq(1,330,1))');
#  $r_block<-add_command('chk<-c(seq(1,4,1))');

#  $r_block->add_command('trt <- acc');
#  $r_block->add_command('control_trt <- chk');
#  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);

   $r_block->add_command('number_of_rows <- '.$number_of_rows);

# $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

 # if ($self->has_randomization_seed()){
 #   $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
 # }
 # else {
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
 # }

 #$r_block->add_command('test.ma<-design.dma(entries=c(seq(1,330,1)),chk.names=c(seq(1,4,1)),num.rows=9, num.cols=NULL, num.sec.chk=3)');

# $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=number_of_rows, num.cols=NULL, num.sec.chk=3)');

#  $r_block->add_command('test.ma<-design.dma.0(entries=trt,chk.names=control_trt, nFieldRow=number_of_rows)');

   $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt, nFieldRow=number_of_rows)');

#  design.dma.0(entries=c(seq(1,300,1)),chk.names= c(seq(1,4,1)),nFieldRow=10)

# $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');

# $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output

  $r_block->add_command('augmented<-test.ma[[2]]'); #added for agricolae 1.1-8 changes in output
#  $r_block->add_command('print(augmented)');
  $r_block->add_command('augmented<-as.matrix(augmented)');
 # $r_block->add_command('augmented<-as.data.frame(augmented)');

 #  $r_block<-add_command('colnames(augmented)[2]<-"plots"');
 #  $r_block<-add_command('colnames(augmented)[3]<-"trt"');
 #  $r_block<-add_command('colnames(augmented)[7]<-"block"');

    my @commands = $r_block->read_commands();
    print STDERR join "\n", @commands;
    print STDERR "\n";

  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("Plot");
  @row_numbers = $result_matrix->get_column("Row");
  @col_numbers = $result_matrix->get_column("Col");
  @block_row_numbers=$result_matrix->get_column("Row.Blk");
  @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("Blk");
  @stock_names = $result_matrix->get_column("Entry");
  @check_names=$result_matrix->get_column("Check");

#Row.Blk Col.Blk

  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  my %seedlot_hash;
  if($self->get_seedlot_hash){
      %seedlot_hash = %{$self->get_seedlot_hash};
  }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;

    $plot_info{'row_number'} =$row_numbers[$i];
    $plot_info{'col_number'} =$col_numbers[$i];
    $plot_info{'check_name'} =$check_names[$i];
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'block_row_number'}=$block_row_numbers[$i];
    $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madii_design{$converted_plot_numbers[$i]} = \%plot_info;
  }

  %madii_design = %{_build_plot_names($self,\%madii_design)};

#  return \%augmented_design;

 #call R code and create design data structure

 return \%madii_design;

#=cut

}

sub _get_madiii_design {

    my $self = shift;
    my %madiii_design;

    my $rbase = R::YapRI::Base->new();

    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;

    my $number_of_rows;
    my $number_of_rows_per_block;
    my $number_of_cols_per_block;
    my $number_of_cols;


    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    my @row_numbers;
    my @check_names;

    my @col_numbers;
    my @block_row_numbers;
    my @block_col_numbers;


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    $self->_check_controls_and_accessions_lists;
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }


    if ($self->has_number_of_rows()) {
    $number_of_rows = $self->get_number_of_rows();
    } else {
    die "Number of rows not specified\n";
    }

    if ($self->has_block_row_numbers()) {
    $number_of_rows_per_block = $self->get_block_row_numbers();
    } else {
    die "Number of block row not specified\n";
    }

    if ($self->has_block_col_numbers()) {
    $number_of_cols_per_block = $self->get_block_col_numbers();
    } else {
    die "Number of block col not specified\n";
    }

    if ($self->has_number_of_cols()) {
    $number_of_cols = $self->get_number_of_cols();
    } else {
    die "Number of blocks not specified\n";
    }

    #system("R --slave --args $tempfile $tempfile_out < R/MADII_layout_function.R");
#     system("R --slave < R/MADII_layout_function.R");


#    if ($self->has_maximum_row_number()) {
#    $maximum_row_number = $self->get_maximum_row_number();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#
#  } else {
#    die "No block size specified\n";
#  }


#  if ($self->has_maximum_block_size()) {
#    $maximum_block_size = $self->get_maximum_block_size();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#  } else {
#    die "No block size specified\n";
#  }

#=comment

  print "@stock_list\n";


  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');

 #$r_block->add_command('library(agricolae)');

  $r_block->add_command('library(MAD)');

  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');

#  $r_block->add_command('acc<-c(seq(1,330,1))');
#  $r_block<-add_command('chk<-c(seq(1,4,1))');

#  $r_block->add_command('trt <- acc');
#  $r_block->add_command('control_trt <- chk');
#  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);

# $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

 # if ($self->has_randomization_seed()){
 #   $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
 # }
 # else {
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
 # }

 #$r_block->add_command('test.ma<-design.dma(entries=c(seq(1,330,1)),chk.names=c(seq(1,4,1)),num.rows=9, num.cols=NULL, num.sec.chk=3)');

  $r_block->add_command('number_of_rows <- '.$number_of_rows);
  $r_block->add_command('number_of_cols <- '.$number_of_cols);
  $r_block->add_command('number_of_rows_per_block <- '.$number_of_rows_per_block);
  $r_block->add_command('number_of_cols_per_block <- '.$number_of_cols_per_block);

  $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,nFieldRow=number_of_rows,nFieldCols=number_of_cols,nRowsPerBlk=number_of_rows_per_block, nColsPerBlk=number_of_cols_per_block)');


 # $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

  #$r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

# $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');

# $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output

  $r_block->add_command('augmented<-test.ma[[2]]'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('augmented<-as.matrix(augmented)');

#  $r_block<-add_command('colnames(augmented)[2]<-"plots"');
#  $r_block<-add_command('colnames(augmented)[3]<-"trt"');
#  $r_block<-add_command('colnames(augmented)[7]<-"block"');


   my @commands = $r_block->read_commands();
   print STDERR join "\n", @commands;
   print STDERR "\n";


  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("Plot");
  @row_numbers = $result_matrix->get_column("Row");
  @col_numbers = $result_matrix->get_column("Col");
  @block_row_numbers=$result_matrix->get_column("Row.Blk");
  @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("Blk");
  @stock_names = $result_matrix->get_column("Entry");
  @check_names=$result_matrix->get_column("Check");


#Row.Blk Col.Blk



  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  my %seedlot_hash;
  if($self->get_seedlot_hash){
      %seedlot_hash = %{$self->get_seedlot_hash};
  }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;

    $plot_info{'row_number'} =$row_numbers[$i];
    $plot_info{'col_number'} =$col_numbers[$i];
    $plot_info{'check_name'} =$check_names[$i];
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'block_row_number'}=$block_row_numbers[$i];
    $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madiii_design{$converted_plot_numbers[$i]} = \%plot_info;
  }

  %madiii_design = %{_build_plot_names($self,\%madiii_design)};

#  return \%augmented_design;

 #call R code and create design data structure

 return \%madiii_design;

#=cut

}

sub _get_madiv_design {

    my $self = shift;
    my %madiv_design;

    my $rbase = R::YapRI::Base->new();

    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;

    my $number_of_rows;
    my $number_of_rows_per_block;
    my $number_of_cols_per_block;
    my $number_of_cols;


    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    my @row_numbers;
    my @check_names;

    my @col_numbers;
    my @block_row_numbers;
    my @block_col_numbers;


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    $self->_check_controls_and_accessions_lists;
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }


    if ($self->has_number_of_rows()) {
    $number_of_rows = $self->get_number_of_rows();
    } else {
    die "Number of rows not specified\n";
    }

    if ($self->has_block_row_numbers()) {
    $number_of_rows_per_block = $self->get_block_row_numbers();
    } else {
    die "Number of block row not specified\n";
    }

  #  if ($self->has_block_col_numbers()) {
  #  $number_of_cols_per_block = $self->get_block_col_numbers();
  #  } else {
  #  die "Number of block col not specified\n";
  #  }

  #  if ($self->has_number_of_cols()) {
  #  $number_of_cols = $self->get_number_of_cols();
  #  } else {
  #  die "Number of blocks not specified\n";
  #  }

    #system("R --slave --args $tempfile $tempfile_out < R/MADII_layout_function.R");
#     system("R --slave < R/MADII_layout_function.R");


#    if ($self->has_maximum_row_number()) {
#    $maximum_row_number = $self->get_maximum_row_number();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#
#  } else {
#    die "No block size specified\n";
#  }


#  if ($self->has_maximum_block_size()) {
#    $maximum_block_size = $self->get_maximum_block_size();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#  } else {
#    die "No block size specified\n";
#  }

#=comment

  print "@stock_list\n";


  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');

 #$r_block->add_command('library(agricolae)');

  $r_block->add_command('library(MAD)');

  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');

#  $r_block->add_command('acc<-c(seq(1,330,1))');
#  $r_block<-add_command('chk<-c(seq(1,4,1))');

#  $r_block->add_command('trt <- acc');
#  $r_block->add_command('control_trt <- chk');
#  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);

# $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

 # if ($self->has_randomization_seed()){
 #   $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
 # }
 # else {
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
 # }

 #$r_block->add_command('test.ma<-design.dma(entries=c(seq(1,330,1)),chk.names=c(seq(1,4,1)),num.rows=9, num.cols=NULL, num.sec.chk=3)');

  $r_block->add_command('number_of_rows <- '.$number_of_rows);
 # $r_block->add_command('number_of_cols <- '.$number_of_cols);
  $r_block->add_command('number_of_rows_per_block <- '.$number_of_rows_per_block);
 # $r_block->add_command('number_of_cols_per_block <- '.$number_of_cols_per_block);

  #$r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,nFieldRow=number_of_rows,nFieldCols=number_of_cols,nRowsPerBlk=number_of_rows_per_block, nColsPerBlk=number_of_cols_per_block)');

  $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,nFieldRow=number_of_rows,nRowsPerBlk=number_of_rows_per_block)');
 # $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

  #$r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

# $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');

# $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output

  $r_block->add_command('augmented<-test.ma[[2]]'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('augmented<-as.matrix(augmented)');

#  $r_block<-add_command('colnames(augmented)[2]<-"plots"');
#  $r_block<-add_command('colnames(augmented)[3]<-"trt"');
#  $r_block<-add_command('colnames(augmented)[7]<-"block"');


   my @commands = $r_block->read_commands();
   print STDERR join "\n", @commands;
   print STDERR "\n";


  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("Plot");
  @row_numbers = $result_matrix->get_column("Row");
  @col_numbers = $result_matrix->get_column("Col");
  @block_row_numbers=$result_matrix->get_column("Row.Blk");
  @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("Blk");
  @stock_names = $result_matrix->get_column("Entry");
  @check_names=$result_matrix->get_column("Check");


#Row.Blk Col.Blk



  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  my %seedlot_hash;
  if($self->get_seedlot_hash){
      %seedlot_hash = %{$self->get_seedlot_hash};
  }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;

    $plot_info{'row_number'} =$row_numbers[$i];
    $plot_info{'col_number'} =$col_numbers[$i];
    $plot_info{'check_name'} =$check_names[$i];
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'block_row_number'}=$block_row_numbers[$i];
    $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madiv_design{$converted_plot_numbers[$i]} = \%plot_info;
  }

  %madiv_design = %{_build_plot_names($self,\%madiv_design)};

#  return \%augmented_design;

 #call R code and create design data structure

 return \%madiv_design;

#=cut

}

sub _convert_plot_numbers {
  my $self = shift;
  my $plot_numbers_ref = shift;
  my @plot_numbers = @{$plot_numbers_ref};
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
  return \@plot_numbers;
}

sub _build_plot_names {
    my $self = shift;
    my $design_ref = shift;
    my %design = %{$design_ref};
    my $prefix = '';
    my $suffix = '';
    my $trial_name = $self->get_trial_name;

    if ($self->has_plot_name_prefix()) {
        $prefix = $self->get_plot_name_prefix()."_";
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

	if ($self->get_design_type() eq "RCBD") { # as requested by IITA (Prasad)
      my $plot_num_per_block = $design{$key}->{plot_num_per_block};
      $design{$key}->{plot_number} = $design{$key}->{plot_num_per_block};
	    #$design{$key}->{plot_name} = $prefix.$trial_name."_rep_".$rep_number."_".$stock_name."_".$block_number."_".$plot_num_per_block."".$suffix;
        $design{$key}->{plot_name} = $prefix.$trial_name."_rep".$rep_number."_".$stock_name."_".$plot_num_per_block."".$suffix;
	}
	elsif ($self->get_design_type() eq "Augmented") {
	    $design{$key}->{plot_name} = $prefix.$trial_name."_plotno".$key."_".$stock_name."_".$suffix;
	}
	else {
	    $design{$key}->{plot_name} = $prefix.$trial_name."_".$key.$suffix;
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

sub _get_greenhouse_design {
    my $self = shift;
    my $order = 1;
    my %greenhouse_design;
    my @num_plants = @{ $self->get_greenhouse_num_plants() };
    my @accession_list = sort @{ $self->get_stock_list() };
    my $trial_name = $self->get_trial_name;
    my %num_accession_hash;
    @num_accession_hash{@accession_list} = @num_plants;

    my @plot_numbers = (1..scalar(@accession_list));
    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
    for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
        my %plot_info;
        $plot_info{'stock_name'} = $accession_list[$i];
        $plot_info{'seedlot_name'} = $seedlot_hash{$accession_list[$i]}->[0];
        if ($plot_info{'seedlot_name'}){
            $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
        }
        $plot_info{'block_number'} = 1;
        $plot_info{'rep_number'} = 1;
        $plot_info{'plot_name'} = $plot_numbers[$i];
        $greenhouse_design{$plot_numbers[$i]} = \%plot_info;
    }
    %greenhouse_design = %{_build_plot_names($self,\%greenhouse_design)};

    foreach my $plot_num (keys %greenhouse_design) {
        my @plant_names;
        my $plot_name = $greenhouse_design{$plot_num}->{'plot_name'};
        my $stock_name = $greenhouse_design{$plot_num}->{'stock_name'};
        for my $n (1..$num_accession_hash{$stock_name}) {
            my $plant_name = $plot_name."_plant_$n";
            push @plant_names, $plant_name;
        }
        $greenhouse_design{$plot_num}->{'plant_names'} = \@plant_names;
    }

    #print STDERR Dumper \%greenhouse_design;
    return \%greenhouse_design;
}

sub _get_splitplot_design {
    my $self = shift;
    my %splitplot_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $number_of_blocks;
    my $number_of_reps;
    my $stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @subplots_numbers;
    my @treatments;
    my @stock_names;
    my @block_numbers;
    my @rep_numbers;
    my @converted_plot_numbers;
    my $number_of_stocks;
    my $fieldmap_row_number;
    my @fieldmap_row_numbers;
    my $fieldmap_col_number;
    my $plot_layout_format;
    my @col_number_fieldmaps;
    my $treatments;
    my $num_plants_per_plot;
    if ($self->has_stock_list()) {
        @stock_list = @{$self->get_stock_list()};
        $number_of_stocks = scalar(@stock_list);
    } else {
        die "No stock list specified\n";
    }
    if ($self->has_treatments()) {
        $treatments = $self->get_treatments();
    } else {
        die "treatments not specified\n";
    }
    if ($self->has_number_of_blocks()) {
        $number_of_blocks = $self->get_number_of_blocks();
        $number_of_reps = $number_of_blocks;
    } else {
        die "Number of blocks not specified\n";
    }

    if ($self->has_fieldmap_col_number()) {
        $fieldmap_col_number = $self->get_fieldmap_col_number();
    }
    if ($self->has_fieldmap_row_number()) {
        $fieldmap_row_number = $self->get_fieldmap_row_number();
        my $colNumber = ((scalar(@stock_list) * $number_of_reps)/$fieldmap_row_number);
        $fieldmap_col_number = _validate_field_colNumber($colNumber);
    }

    if ($self->has_plot_layout_format()) {
        $plot_layout_format = $self->get_plot_layout_format();
    }
    if($self->has_num_plants_per_plot()){
        $num_plants_per_plot = $self->get_num_plants_per_plot();
    }

    $stock_data_matrix =  R::YapRI::Data::Matrix->new({
        name => 'stock_data_matrix',
        rown => 1,
        coln => scalar(@stock_list),
        data => \@stock_list,
    });
    #print STDERR Dumper $stock_data_matrix;
    my $treatment_data_matrix =  R::YapRI::Data::Matrix->new({
        name => 'treatment_data_matrix',
        rown => 1,
        coln => scalar(@$treatments),
        data => $treatments,
    });
    #print STDERR Dumper $treatment_data_matrix;

    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block');
    $treatment_data_matrix->send_rbase($rbase, 'r_block');

    $r_block->add_command('library(agricolae)');
    $r_block->add_command('accessions <- stock_data_matrix[1,]');
    $r_block->add_command('treatments <- treatment_data_matrix[1,]');
    $r_block->add_command('r <- '.$number_of_reps);
    $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

    if ($self->has_randomization_seed()){
        $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
        $r_block->add_command('splitplot<-design.split(accessions,treatments,r=r,serie=3,kinds=randomization_method, seed=randomization_seed)');
    }
    else {
        $r_block->add_command('splitplot<-design.split(accessions,treatments,r=r,serie=3,kinds=randomization_method)');
    }
    $r_block->add_command('split<-splitplot$book'); #added for agricolae 1.1-8 changes in output
    $r_block->add_command('split<-as.matrix(split)');
    $r_block->run_block();
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','split');
    #print STDERR Dumper $result_matrix;

    @plot_numbers = $result_matrix->get_column("plots");
    @subplots_numbers = $result_matrix->get_column("splots");
    @rep_numbers = $result_matrix->get_column("block");
    @stock_names = $result_matrix->get_column("accessions");
    @treatments = $result_matrix->get_column("treatments");
    @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};
    #print STDERR Dumper \@converted_plot_numbers;

    if ($plot_layout_format eq "zigzag") {
        if (!$fieldmap_col_number){
            for (1..$number_of_reps){
                for my $s (1..(scalar(@stock_list))){
                    for (1..scalar(@$treatments)){
                        push @col_number_fieldmaps, $s;
                    }
                }
            }
        } else {
            for (1..$fieldmap_row_number){
                for my $s (1..$fieldmap_col_number){
                    for (1..scalar(@$treatments)){
                        push @col_number_fieldmaps, $s;
                    }
                }
            }
        }
    }
    elsif ($plot_layout_format eq "serpentine") {
        if (!$fieldmap_row_number)  {
            for my $rep (1 .. $number_of_reps){
                if ($rep % 2){
                    for my $s (1..(scalar(@stock_list))){
                        for (1..scalar(@$treatments)){
                            push @col_number_fieldmaps, $s;
                        }
                    }
                } else {
                    for my $s (reverse 1..(scalar(@stock_list))){
                        for (1..scalar(@$treatments)){
                            push @col_number_fieldmaps, $s;
                        }
                    }
                }
            }
        } else {
            for my $rep (1 .. $fieldmap_row_number){
                if ($rep % 2){
                    for my $s (1..$fieldmap_col_number){
                        for (1..scalar(@$treatments)){
                            push @col_number_fieldmaps, $s;
                        }
                    }
                } else {
                    for my $s (reverse 1..$fieldmap_col_number){
                        for (1..scalar(@$treatments)){
                            push @col_number_fieldmaps, $s;
                        }
                    }
                }
            }
        }
    }

    if ($plot_layout_format && !$fieldmap_col_number && !$fieldmap_row_number){
        @fieldmap_row_numbers = sort(@rep_numbers);
    }
    elsif ($plot_layout_format && $fieldmap_row_number){
        @fieldmap_row_numbers = ((1..$fieldmap_row_number) x $fieldmap_col_number);
        @fieldmap_row_numbers = sort {$a <=> $b} @fieldmap_row_numbers;
    }
    #print STDERR Dumper \@fieldmap_row_numbers;
    #print STDERR Dumper \@col_number_fieldmaps;

    my %subplot_plots;
    my %treatment_plots;
    my %treatment_subplot_hash;
    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
    for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
        my %plot_info;

        $plot_info{'stock_name'} = $stock_names[$i];
        $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
        if ($plot_info{'seedlot_name'}){
            $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
        }
        $plot_info{'block_number'} = 1;
        $plot_info{'rep_number'} = $rep_numbers[$i];
        $plot_info{'plot_name'} = $converted_plot_numbers[$i];
        $plot_info{'plot_number'} = $converted_plot_numbers[$i];
        if ($fieldmap_row_numbers[$i]){
            $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
            $plot_info{'col_number'} = $col_number_fieldmaps[$i];
        }
        push @{$subplot_plots{$converted_plot_numbers[$i]}}, $subplots_numbers[$i];
        $plot_info{'subplots_names'} = $subplot_plots{$converted_plot_numbers[$i]};
        push @{$treatment_plots{$converted_plot_numbers[$i]}}, $treatments[$i];
        $plot_info{'treatments'} = $treatment_plots{$converted_plot_numbers[$i]};
        $splitplot_design{$converted_plot_numbers[$i]} = \%plot_info;
    }
    #print STDERR Dumper \%splitplot_design;
    %splitplot_design = %{_build_plot_names($self,\%splitplot_design)};

    while(my($plot,$val) = each(%splitplot_design)){
        my $subplots = $val->{'subplots_names'};
        my $treatments = $val->{'treatments'};
        my $num_plants_per_subplot = $num_plants_per_plot/scalar(@$subplots);
        my %subplot_plants_hash;
        my @plant_names;
        my $plant_index = 1;
        for(my $i=0; $i<scalar(@$subplots); $i++){
            push @{$treatment_subplot_hash{$treatments->[$i]}}, $subplots->[$i];
            for(my $j=0; $j<$num_plants_per_subplot; $j++){
                my $plant_name = $subplots->[$i]."_plant_$plant_index";
                push @{$subplot_plants_hash{$subplots->[$i]}}, $plant_name;
                push @{$treatment_subplot_hash{$treatments->[$i]}}, $plant_name;
                push @plant_names, $plant_name;
                $plant_index++;
            }
        }
        $val->{plant_names} = \@plant_names;
        $val->{subplots_plant_names} = \%subplot_plants_hash;
    }
    $splitplot_design{'treatments'} = \%treatment_subplot_hash;
    #print STDERR Dumper \%splitplot_design;
    return \%splitplot_design;
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
