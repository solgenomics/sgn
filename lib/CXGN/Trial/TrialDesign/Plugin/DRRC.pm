
package CXGN::Trial::TrialDesign::Plugin::DRRC;

use File::Slurp;
use CXGN::Tools::Run;
use Moose::Role;
use List::MoreUtils qw(first_index);
use Data::Dumper;

sub create_design {
  my $self = shift;
  my %drrc_design;
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
  my @rep_numbers;
  my @converted_plot_numbers;
  my @control_list_crbd;
  my %control_names_lookup;
  my $fieldmap_row_number;
  my @fieldmap_row_numbers;
  my $fieldmap_col_number;
  my $plot_layout_format;
  my @fieldmap_col_numbers;
  my $colNumber;
  my $repNumber;
  my $rowNumber;
  my $blockColNumber;

  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
    $stock_list = '"'.join('","', @stock_list).'"';
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_control_list_crbd()) {
    $control_list = '"'.join('","',@{$self->get_control_list_crbd()}).'"';
    %control_names_lookup = map { $_ => 1 } @{$self->get_control_list_crbd()};
    $self->_check_controls_and_accessions_lists;
  }
  if ($self->has_number_of_reps()) {
    $repNumber = $self->get_number_of_reps();
  } else {
    die "Number of reps not specified\n";
  }

  if ($self->has_number_of_cols()) {
    $colNumber = $self->get_number_of_cols();
  } else {
    die "Number of cols not specified\n";
  }

  my $rowNumber = scalar(@stock_list) / ($colNumber/$repNumber);

  ## It checks if number of stocks is divisible by number of columns and rows.
  if (scalar(@stock_list) % $colNumber == 0) {
    print "Correct entries and col number proportion.\n";
  } else {
    die "The number of entries must be divisible by the number of cols.\nThis design is resulting in:\nCols: $colNumber\nRows: $rowNumber\n";
  }
  if (scalar(@stock_list) % $rowNumber == 0)  {
    print "Correct entries and row number proportion.\n "
    } else {
    die "Total number of treatments must be divisible by the number of rows.\nThis design is resulting in:\nCols: $colNumber\nRows: $rowNumber\n";
  }

  print STDERR "Stock number is ".scalar(@stock_list)." and the number of rep is $repNumber and row number is $rowNumber and the number of col is $colNumber\n";

  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  my $plot_start = $self->get_plot_start_number();


  my $tempfile = $self->get_tempfile();

  my $param_file = $tempfile.".params";
  open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
  print $F "treatments <- c($stock_list)\n";
  print $F "controls <- c($control_list)\n";
  print $F "nRep <- ".$repNumber."\n";
  print $F "nRow <- ".$rowNumber."\n";
  print $F "nCol <- ".$colNumber."\n";
  print $F "plot_start <- \"$plot_start\"\n";
  print $F "plot_type <- \"$plot_layout_format\"\n";
  # print $F "col_per_block <- ".$blockColNumber."\n";
  close($F);

  print "The plot type is $plot_layout_format \n";

  my $cmd = "R CMD BATCH  '--args paramfile=\"".$tempfile.".params\"' " .  " R/DRRC.r ".$tempfile.".out";

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

  my $design_file = $tempfile.".design";
  open my $design, $design_file or die "Could not open $design_file: $!";

if (-e $design_file) {
    my @lines = read_file($design_file);
    chomp(@lines);
    my $header_line = shift(@lines);
    my @headers = split('\t', $header_line);

    # Define column names you're interested in
    my @desired_columns = ('block_number', 'rep_number','row_number', 'col_number', 'plot_number', 'accession_name', 'is_a_control');

    # Find indices of desired columns
    my %column_indices;
    for my $col_name (@desired_columns) {
        my $index = first_index { $_ eq $col_name } @headers;
        $column_indices{$col_name} = $index;
    }

    # Extract data based on column names
    my %data;
    for my $col_name (@desired_columns) {
        my $index = $column_indices{$col_name};
        $data{$col_name} = [ map { (split('\t', $_))[$index] } @lines ];
    }

    my $index_ref = shift;
    $index_ref = $column_indices{'block_number'};
    push @block_numbers, map { (split('\t', $_))[$index_ref] } @lines;

    $index_ref = $column_indices{'rep_number'};
    push @rep_numbers, map { (split('\t', $_))[$index_ref] } @lines;

    $index_ref = $column_indices{'row_number'};
    push @fieldmap_row_numbers, map { (split('\t', $_))[$index_ref] } @lines;

    $index_ref = $column_indices{'col_number'};
    push @fieldmap_col_numbers, map { (split('\t', $_))[$index_ref] } @lines;

    $index_ref = $column_indices{'plot_number'};
    push @plot_numbers, map { (split('\t', $_))[$index_ref] } @lines;

    $index_ref = $column_indices{'accession_name'};
    push @stock_names, map { (split('\t', $_))[$index_ref] } @lines;

    $index_ref = $column_indices{'is_a_control'};
    push @is_a_control, map { (split('\t', $_))[$index_ref] } @lines;




    print Dumper \%data;
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
    $plot_info{'rep_number'} = $rep_numbers[$i];
    $plot_info{'plot_number'} = $plot_numbers[$i];
    $plot_info{'plot_num_per_block'} = $plot_numbers[$i];
    $plot_info{'is_a_control'} = $is_a_control[$i];
    $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
    $plot_info{'col_number'} = $fieldmap_col_numbers[$i];

    $drrc_design{$plot_numbers[$i]} = \%plot_info;
  }

  %drrc_design = %{$self->_build_plot_names(\%drrc_design)};
  # print Dumper \%drrc_design;

  return \%drrc_design;
}

1;