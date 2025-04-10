package CXGN::Trial::TrialDesign::Plugin::URDD;

use File::Slurp;
use CXGN::Tools::Run;
use Moose::Role;
use Data::Dumper;

use File::Slurp;
use CXGN::Tools::Run;
use Moose::Role;
use Data::Dumper;

sub create_design {
  my ($self, $c) = @_;
  my %urdd_design;
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
  if ($self->has_control_list_crbd()) {
    $control_list = '"'.join('","',@{$self->get_control_list_crbd()}).'"';
    %control_names_lookup = map { $_ => 1 } @{$self->get_control_list_crbd()};
    $self->_check_controls_and_accessions_lists;
  }
  if ($self->has_number_of_blocks()) {
    $number_of_blocks = $self->get_number_of_blocks();
  } 
  # else {
  #   die "Number of blocks not specified\n";
  # }
  
  if ($self->has_fieldmap_row_number()) {
    $fieldmap_row_number = $self->get_fieldmap_row_number();
  }

  if ($self->has_fieldmap_col_number()) {
    $fieldmap_col_number = $self->get_fieldmap_col_number();
  }

  my $treatments = [];
  my $num_trt = 0;

  if ($self->has_treatments()) {
      $treatments = $self->get_treatments();
      $num_trt = scalar(@$treatments);
  }

  print STDERR "Stock number is ".scalar(@stock_list)." and block number is $number_of_blocks \nand cols $fieldmap_col_number \nand row number is $fieldmap_row_number\nTreatments are $num_trt";

  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  my $num_controls = $self->has_control_list_crbd() ? scalar(@{$self->get_control_list_crbd()}) : 0;
  my $num_stocks = scalar(@stock_list) - $num_controls;
  if ($num_stocks % $number_of_blocks != 0) {
      die "The number of stocks ($num_stocks) must be divisible by the number of blocks ($number_of_blocks).";
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
  print $F "stocks <- c($stock_list)\n";
  print $F "controls <- c($control_list)\n";
  print $F "nBlocks <- ".$number_of_blocks."\n";
  print $F "nRow <- ".$fieldmap_row_number."\n";
  print $F "nCol <- ".$fieldmap_col_number."\n";
  print $F "serie <- ".$serie."\n";
  print $F "nLines <- ".$num_stocks."\n";
  print $F "layout <- \"$plot_layout_format\"\n";
  close($F);


  my $cmd = "R CMD BATCH  '--args paramfile=\"".$tempfile.".params\"' " .  " R/urdd_design.R ".$tempfile.".out";

  my $ctr = CXGN::Tools::Run->new( {
      backend => $self->get_backend(),
      working_dir => $self->get_temp_base(),
      submit_host => $self->get_submit_host()
  } );

  print STDERR "running R command $cmd...\n";
  $ctr->run_cluster($cmd);
  while ($ctr->alive()) {
    # print STDERR "R process still running ...\n";
    sleep(1);
  }
  
  ## Handling with errors
  my $error_file = $tempfile . "design.error";

  if (-e $error_file) {
      my $error_msg = do {
          open(my $fh, '<', $error_file) or die "Can't read $error_file: $!";
          local $/; <$fh>
      };
      die $error_msg ;
      return;
  }


  my $design_file = $tempfile . ".design";
  open my $design, '<', $design_file or die "Could not open $design_file: $!";

  if (-e $design_file) {
      my $header = <$design>;
      chomp $header;
      my @columns = split /\t/, $header;

      # Map column names to their index
      my %col_idx = map { $columns[$_] =~ s/^\s+|\s+$//gr => $_ } 0..$#columns;

      while (my $line = <$design>) {
          chomp $line;
          next if $line =~ /^\s*$/;  # skip empty lines

          my @fields = split /\t/, $line;

          push @block_numbers,         $fields[ $col_idx{'EXPT'} ];
          push @fieldmap_row_numbers,  $fields[ $col_idx{'ROW'} ];
          push @col_number_fieldmaps,  $fields[ $col_idx{'COLUMN'} ];
          push @plot_numbers,          $fields[ $col_idx{'PLOT'} ];
          push @stock_names,           $fields[ $col_idx{'TREATMENT'} ];
          push @is_a_control,          $fields[ $col_idx{'CHECKS'} ];
      }

      close $design;
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
    $urdd_design{$plot_numbers[$i]} = \%plot_info;
  }
  %urdd_design = %{$self->_build_plot_names(\%urdd_design)};
  return \%urdd_design;
}

1;
