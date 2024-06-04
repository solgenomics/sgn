## Package for Augmented Row Column Design
package CXGN::Trial::TrialDesign::Plugin::ARC;

use File::Slurp;
use CXGN::Tools::Run;
use Moose::Role;
use Data::Dumper;

sub create_design {
  my $self = shift;
  my %arc_design;
  my $rbase = R::YapRI::Base->new();
  my $stock_list;
  my @stock_list;
  my $control_list;
  my $number_of_blocks;
  my $stock_data_matrix;
  my $control_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @is_a_control;
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
    $stock_list = '"'.join('","', @stock_list).'"';
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_control_list()) {
    $control_list = '"'.join('","',@{$self->get_control_list()}).'"';
    %control_names_lookup = map { $_ => 1 } @{$self->get_control_list()};
    $self->_check_controls_and_accessions_lists;
  } else {
    die "No control list specified\n";
  }

  print "This is the control: $control_list\n";

  


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
  }else{
    $fieldmap_row_number = 1;
  }

  print STDERR "Stock number is ".scalar(@stock_list)." and block number is $number_of_blocks and row number is $fieldmap_row_number\n";

  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  my $plot_start = $self->get_plot_start_number();
  my $serie;
  if($plot_start == 1){
      $serie = 1;
  }elsif($plot_start == 101){
      $serie = 2;
  }elsif($plot_start == 1001){
      $serie = 3;
  }

  my $tempfile = $self->get_tempfile();

  my $param_file = $tempfile.".params";
  open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
  print $F "treatments <- c($stock_list)\n";
  print $F "controls <- c($control_list)\n";
  print $F "nBlocks <- ".$number_of_blocks."\n";
  print $F "nRow <- ".$fieldmap_row_number."\n";
  print $F "serie <- ".$serie."\n";
  close($F);


  my $cmd = "R CMD BATCH  '--args paramfile=\"".$tempfile.".params\"' " .  " R/arc_design.R ".$tempfile.".out";

  my $backend = 'Slurm';
  my $cluster_host = "localhost";

  my $ctr = CXGN::Tools::Run->new( {
      backend => $self->get_backend(),
      working_dir => $self->get_temp_base(),
      submit_host => $self->get_submit_host()
  } );

  print STDERR "running R command $cmd...\n";
  $ctr->run_cluster($cmd);
  while ($ctr->alive()) {
    print STDERR "R process still running ...\n";
    sleep(1);
  }


  my $design_file = $tempfile.".design";
  open my $design, $design_file or die "Could not open $design_file: $!";

  if ( -e $design_file) {
      my @lines = read_file($design_file);
      chomp(@lines);
      print STDERR Dumper @lines;

      my $header_line = shift(@lines);
      @block_numbers = split('\t', shift(@lines));
      print STDERR "Block numbers are: @block_numbers\n";
      @fieldmap_row_numbers = split('\t', shift(@lines));
      @col_number_fieldmaps = split('\t', shift(@lines));
      @plot_numbers = split('\t', shift(@lines));
      @stock_names = split('\t', shift(@lines));
      @is_a_control = split('\t', shift(@lines));
  }
  my %seedlot_hash;
  if($self->get_seedlot_hash){
    %seedlot_hash = %{$self->get_seedlot_hash};
  }
  for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $plot_numbers[$i];
    $plot_info{'rep_number'} = $block_numbers[$i];
    #$plot_info{'plot_num_per_block'} = $plot_numbers[$i];
    $plot_info{'plot_number'} = $plot_numbers[$i];
    $plot_info{'plot_num_per_block'} = $plot_numbers[$i];
    $plot_info{'is_a_control'} = $is_a_control[$i];
    #$plot_info_per_block{}
      if ($fieldmap_row_numbers[$i]){
      $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
      $plot_info{'col_number'} = $col_number_fieldmaps[$i];
    }
    $arc_design{$plot_numbers[$i]} = \%plot_info;
  }
  %arc_design = %{$self->_build_plot_names(\%arc_design)};
  return \%arc_design;
}
1;
