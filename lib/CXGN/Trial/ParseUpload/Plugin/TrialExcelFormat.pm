package CXGN::Trial::ParseUpload::Plugin::TrialExcelFormat;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;

sub _validate_with_plugin {
    print STDERR "Check 3.1.1 ".localtime();
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my $trial_stock_type = $self->get_trial_stock_type();
  my %errors;
  my @error_messages;
  my %warnings;
  my @warning_messages;
  my %missing_accessions;

  # Match a dot, extension .xls / .xlsx
  my ($extension) = $filename =~ /(\.[^.]+)$/;
  my $parser;

  if ($extension eq '.xlsx') {
    $parser = Spreadsheet::ParseXLSX->new();
  }
  else {
    $parser = Spreadsheet::ParseExcel->new();
  }

  my $excel_obj;
  my $worksheet;
  my %seen_plot_names;
  my %seen_seedlot_names;
  my %seen_entry_names;
  my %seen_plot_keys;


  #try to open the excel file and report any errors
  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    push @error_messages, $parser->error();
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

    print STDERR "Check 3.1.2 ".localtime();

  $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
  if (!$worksheet) {
      push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
      $errors{'error_messages'} = \@error_messages;
      $self->_set_parse_errors(\%errors);
      return;
  }
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();
  if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
    push @error_messages, "Spreadsheet is missing header or contains no rows";
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

  #get column headers
  my $plot_name_head;
  my $stock_name_head;
  my $seedlot_name_head;
  my $num_seed_per_plot_head;
  my $weight_gram_seed_per_plot_head;
  my $plot_number_head;
  my $block_number_head;
  my $is_a_control_head;
  my $rep_number_head;
  my $range_number_head;
  my $row_number_head;
  my $col_number_head;

  if ($worksheet->get_cell(0,0)) {
    $plot_name_head  = $worksheet->get_cell(0,0)->value();
    $plot_name_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,1)) {
    $stock_name_head  = $worksheet->get_cell(0,1)->value();
    $stock_name_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,2)) {
    $plot_number_head  = $worksheet->get_cell(0,2)->value();
    $plot_number_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,3)) {
    $block_number_head  = $worksheet->get_cell(0,3)->value();
    $block_number_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,4)) {
    $is_a_control_head  = $worksheet->get_cell(0,4)->value();
    $is_a_control_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,5)) {
    $rep_number_head  = $worksheet->get_cell(0,5)->value();
    $rep_number_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,6)) {
    $range_number_head  = $worksheet->get_cell(0,6)->value();
    $range_number_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,7)) {
      $row_number_head  = $worksheet->get_cell(0,7)->value();
      $row_number_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,8)) {
      $col_number_head  = $worksheet->get_cell(0,8)->value();
      $col_number_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,9)) {
    $seedlot_name_head  = $worksheet->get_cell(0,9)->value();
    $seedlot_name_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,10)) {
    $num_seed_per_plot_head = $worksheet->get_cell(0,10)->value();
    $num_seed_per_plot_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,11)) {
    $weight_gram_seed_per_plot_head = $worksheet->get_cell(0,11)->value();
    $weight_gram_seed_per_plot_head =~ s/^\s+|\s+$//g;
  }

  my @treatment_names;
  for (12 .. $col_max){
      if ($worksheet->get_cell(0,$_)){
          push @treatment_names, $worksheet->get_cell(0,$_)->value();
      }
  }

  if (!$plot_name_head || $plot_name_head ne 'plot_name' ) {
    push @error_messages, "Cell A1: plot_name is missing from the header";
  }

    if ($trial_stock_type eq 'family_name') {
        if (!$stock_name_head || $stock_name_head ne 'family_name') {
            push @error_messages, "Cell B1: family_name is missing from the header";
        }
    } elsif ($trial_stock_type eq 'cross') {
        if (!$stock_name_head || $stock_name_head ne 'cross_unique_id') {
            push @error_messages, "Cell B1: cross_unique_id is missing from the header";
        }
    } else {
        if (!$stock_name_head || $stock_name_head ne 'accession_name') {
            push @error_messages, "Cell B1: accession_name is missing from the header";
        }
    }

  if (!$plot_number_head || $plot_number_head ne 'plot_number') {
    push @error_messages, "Cell C1: plot_number is missing from the header";
  }
  if (!$block_number_head || $block_number_head ne 'block_number') {
    push @error_messages, "Cell D1: block_number is missing from the header";
  }
  if (!$is_a_control_head || $is_a_control_head ne 'is_a_control') {
    push @error_messages, "Cell E1: is_a_control is missing from the header. (Header is required, but values are optional)";
  }
  if (!$rep_number_head || $rep_number_head ne 'rep_number') {
    push @error_messages, "Cell F1: rep_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$range_number_head || $range_number_head ne 'range_number') {
    push @error_messages, "Cell G1: range_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$row_number_head || $row_number_head ne 'row_number') {
    push @error_messages, "Cell H1: row_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$col_number_head || $col_number_head ne 'col_number') {
    push @error_messages, "Cell I1: col_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name') {
    push @error_messages, "Cell J1: seedlot_name is missing from the header. (Header is required, but values are optional)";
  }
  if (!$num_seed_per_plot_head || $num_seed_per_plot_head ne 'num_seed_per_plot') {
    push @error_messages, "Cell K1: num_seed_per_plot is missing from the header. (Header is required, but values are optional)";
  }
  if (!$weight_gram_seed_per_plot_head || $weight_gram_seed_per_plot_head ne 'weight_gram_seed_per_plot') {
    push @error_messages, "Cell L1: weight_gram_seed_per_plot is missing from the header. (Header is required, but values are optional)";
  }

  my @pairs;
  my %seen_plot_numbers;
  for my $row ( 1 .. $row_max ) {
      #print STDERR "Check 01 ".localtime();
    my $row_name = $row+1;
    my $plot_name;
    my $stock_name;
    my $seedlot_name;
    my $num_seed_per_plot = 0;
    my $weight_gram_seed_per_plot = 0;
    my $plot_number;
    my $block_number;
    my $is_a_control;
    my $rep_number;
    my $range_number;
    my $row_number;
    my $col_number;

    if ($worksheet->get_cell($row,0)) {
      $plot_name = $worksheet->get_cell($row,0)->value();
    }
    if ($worksheet->get_cell($row,1)) {
      $stock_name = $worksheet->get_cell($row,1)->value();
    }
    if ($worksheet->get_cell($row,2)) {
      $plot_number =  $worksheet->get_cell($row,2)->value();
    }
    if ($worksheet->get_cell($row,3)) {
      $block_number =  $worksheet->get_cell($row,3)->value();
    }
    if ($worksheet->get_cell($row,4)) {
      $is_a_control =  $worksheet->get_cell($row,4)->value();
    }
    if ($worksheet->get_cell($row,5)) {
      $rep_number =  $worksheet->get_cell($row,5)->value();
    }
    if ($worksheet->get_cell($row,6)) {
      $range_number =  $worksheet->get_cell($row,6)->value();
    }
    if ($worksheet->get_cell($row, 7)) {
	     $row_number = $worksheet->get_cell($row, 7)->value();
    }
    if ($worksheet->get_cell($row, 8)) {
	     $col_number = $worksheet->get_cell($row, 8)->value();
    }
    if ($worksheet->get_cell($row,9)) {
      $seedlot_name = $worksheet->get_cell($row,9)->value();
    }
    if ($worksheet->get_cell($row,10)) {
      $num_seed_per_plot = $worksheet->get_cell($row,10)->value();
    }
    if ($worksheet->get_cell($row,11)) {
      $weight_gram_seed_per_plot = $worksheet->get_cell($row,11)->value();
    }

    #skip blank lines
    if (!$plot_name && !$stock_name && !$plot_number && !$block_number) {
      next;
    }

      #print STDERR "Check 02 ".localtime();

    #plot_name must not be blank
    if (!$plot_name || $plot_name eq '' ) {
        push @error_messages, "Cell A$row_name: plot name missing.";
    }
    elsif ($plot_name =~ /\s/ ) {
        push @error_messages, "Cell A$row_name: plot name must not contain spaces.";
    }
    elsif ($plot_name =~ /\// || $plot_name =~ /\\/) {
        push @warning_messages, "Cell A$row_name: plot name contains slashes. Note that slashes can cause problems for third-party applications; however, plotnames can be saved with slashes.";
    }
    else {
        $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        #file must not contain duplicate plot names
        if ($seen_plot_names{$plot_name}) {
            push @error_messages, "Cell A$row_name: duplicate plot name at cell A".$seen_plot_names{$plot_name}.": $plot_name";
        }
        $seen_plot_names{$plot_name}=$row_name;
    }

      #print STDERR "Check 03 ".localtime();

    #stock_name must not be blank and must exist in the database
    if (!$stock_name || $stock_name eq '') {
        push @error_messages, "Cell B$row_name: entry name missing";
    } else {
        $stock_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_entry_names{$stock_name}++;
    }

      #print STDERR "Check 04 ".localtime();

    #plot number must not be blank
    if (!$plot_number || $plot_number eq '') {
        push @error_messages, "Cell C$row_name: plot number missing";
    }
    #plot number must be a positive integer
    if (!($plot_number =~ /^\d+?$/)) {
        push @error_messages, "Cell C$row_name: plot number is not a positive integer: $plot_number";
    }
    #plot number must be unique in file
    if (exists($seen_plot_numbers{$plot_number})){
        push @error_messages, "Cell C$row_name: plot number must be unique in your file. You already used this plot number in C".$seen_plot_numbers{$plot_number};
    } else {
        $seen_plot_numbers{$plot_number} = $row_name;
    }

    #block number must not be blank
    if (!$block_number || $block_number eq '') {
        push @error_messages, "Cell D$row_name: block number missing";
    }
    #block number must be a positive integer
    if (!($block_number =~ /^\d+?$/)) {
        push @error_messages, "Cell D$row_name: block number is not a positive integer: $block_number";
    }
    if ($is_a_control) {
      #is_a_control must be either yes, no 1, 0, or blank
      if (!($is_a_control eq "yes" || $is_a_control eq "no" || $is_a_control eq "1" ||$is_a_control eq "0" || $is_a_control eq '')) {
          push @error_messages, "Cell E$row_name: is_a_control is not either yes, no 1, 0, or blank: $is_a_control";
      }
    }
    if ($rep_number && !($rep_number =~ /^\d+?$/)){
        push @error_messages, "Cell F$row_name: rep_number must be a positive integer: $rep_number";
    }
    if ($range_number && !($range_number =~ /^\d+?$/)){
        push @error_messages, "Cell G$row_name: range_number must be a positive integer: $range_number";
    }
    if ($row_number && !($row_number =~ /^\d+?$/)){
        push @error_messages, "Cell H$row_name: row_number must be a positive integer: $row_number";
    }
    if ($col_number && !($col_number =~ /^\d+?$/)){
        push @error_messages, "Cell I$row_name: col_number must be a positive integer: $col_number";
    }
    if ($row_number && $col_number) {
      my $k = "$row_number-$col_number";
      if ( !exists $seen_plot_keys{$k} ) {
        $seen_plot_keys{$k} = [$plot_number];
      }
      else {
        push @{$seen_plot_keys{$k}}, $plot_number;
      }
    }

    if ($seedlot_name){
        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_seedlot_names{$seedlot_name}++;
        push @pairs, [$seedlot_name, $stock_name];
    }
    if (defined($num_seed_per_plot) && $num_seed_per_plot ne '' && !($num_seed_per_plot =~ /^\d+?$/)){
        push @error_messages, "Cell K$row_name: num_seed_per_plot must be a positive integer: $num_seed_per_plot";
    }
    if (defined($weight_gram_seed_per_plot) && $weight_gram_seed_per_plot ne '' && !($weight_gram_seed_per_plot =~ /^\d+?$/)){
        push @error_messages, "Cell L$row_name: weight_gram_seed_per_plot must be a positive integer: $weight_gram_seed_per_plot";
    }

    my $treatment_col = 12;
    foreach my $treatment_name (@treatment_names){
        if($worksheet->get_cell($row,$treatment_col)){
            my $apply_treatment = $worksheet->get_cell($row,$treatment_col)->value();
            if ( ($apply_treatment ne '' ) && defined($apply_treatment) && $apply_treatment ne '1'){
                push @error_messages, "Treatment value in row $row_name should be either 1 or empty";
            }
        }
        $treatment_col++;
    }

  }

    my @entry_names = keys %seen_entry_names;
    my $entry_name_validator = CXGN::List::Validate->new();
    my @entry_names_missing = @{$entry_name_validator->validate($schema,'accessions_or_crosses_or_familynames',\@entry_names)->{'missing'}};

    if (scalar(@entry_names_missing) > 0) {
        $errors{'missing_stocks'} = \@entry_names_missing;
        push @error_messages, "The following entry names are not in the database as uniquenames or synonyms: ".join(',',@entry_names_missing);
    }


    my @seedlot_names = keys %seen_seedlot_names;
    if (scalar(@seedlot_names)>0){
        my $seedlot_validator = CXGN::List::Validate->new();
        my @seedlots_missing = @{$seedlot_validator->validate($schema,'seedlots',\@seedlot_names)->{'missing'}};

        if (scalar(@seedlots_missing) > 0) {
            $errors{'missing_seedlots'} = \@seedlots_missing;
            push @error_messages, "The following seedlots are not in the database or are marked as discarded: ".join(',',@seedlots_missing);
        }

        my $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, \@pairs);
        if (exists($return->{error})){
            push @error_messages, $return->{error};
        }
    }

    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my @plots = keys %seen_plot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'type_id' => $plot_type_id,
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plots }
    });
    while (my $r=$rs->next){
        push @error_messages, "Cell A".$seen_plot_names{$r->uniquename}.": plot name already exists: ".$r->uniquename;
    }

    # check for multiple plots at the same position
    foreach my $key (keys %seen_plot_keys) {
        my $plots = $seen_plot_keys{$key};
        my $count = scalar(@{$plots});
        if ( $count > 1 ) {
            my @pos = split('-', $key);
            push @warning_messages, "More than 1 plot is assigned to the position row=" . $pos[0] . " col=" . $pos[1] . " plots=" . join(',', @$plots);
        }
    }

    if (scalar(@warning_messages) >= 1) {
        $warnings{'warning_messages'} = \@warning_messages;
        $self->_set_parse_warnings(\%warnings);
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    print STDERR "Check 3.1.3 ".localtime();

    return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my $trial_stock_type = $self->get_trial_stock_type();

  # Match a dot, extension .xls / .xlsx
  my ($extension) = $filename =~ /(\.[^.]+)$/;
  my $parser;

  if ($extension eq '.xlsx') {
    $parser = Spreadsheet::ParseXLSX->new();
  }
  else {
    $parser = Spreadsheet::ParseExcel->new();
  }

  my $excel_obj;
  my $worksheet;
  my %design;

  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();

  my @treatment_names;
  for (12 .. $col_max){
      if ($worksheet->get_cell(0,$_)){
          push @treatment_names, $worksheet->get_cell(0,$_)->value();
      }
  }

  my %seen_stock_names;
  for my $row ( 1 .. $row_max ) {
      my $stock_name;
      if ($worksheet->get_cell($row,1)) {
          $stock_name = $worksheet->get_cell($row,1)->value();
          $stock_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
          $seen_stock_names{$stock_name}++;
      }
  }
  my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
  my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

  my @stocks = keys %seen_stock_names;
  my $stock_synonym_rs = $schema->resultset("Stock::Stock")->search({
      'me.is_obsolete' => { '!=' => 't' },
      'stockprops.value' => { -in => \@stocks},
      'me.type_id' => $accession_cvterm_id,
      'stockprops.type_id' => $synonym_cvterm_id
  },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
  my %stock_synonyms_lookup;
  while (my $r=$stock_synonym_rs->next){
      $stock_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
  }

  for my $row ( 1 .. $row_max ) {
    my $plot_name;
    my $stock_name;
    my $plot_number;
    my $block_number;
    my $is_a_control;
    my $rep_number;
    my $range_number;
    my $row_number;
    my $col_number;
    my $seedlot_name;
    my $num_seed_per_plot = 0;
    my $weight_gram_seed_per_plot = 0;

    if ($worksheet->get_cell($row,0)) {
      $plot_name = $worksheet->get_cell($row,0)->value();
    }
    $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,1)) {
      $stock_name = $worksheet->get_cell($row,1)->value();
    }
    $stock_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,2)) {
      $plot_number =  $worksheet->get_cell($row,2)->value();
    }
    if ($worksheet->get_cell($row,3)) {
      $block_number =  $worksheet->get_cell($row,3)->value();
    }
    if ($worksheet->get_cell($row,4)) {
      $is_a_control =  $worksheet->get_cell($row,4)->value();
    }
    if ($worksheet->get_cell($row,5)) {
      $rep_number =  $worksheet->get_cell($row,5)->value();
    }
    if ($worksheet->get_cell($row,6)) {
      $range_number =  $worksheet->get_cell($row,6)->value();
    }
    if ($worksheet->get_cell($row,7)) {
	     $row_number = $worksheet->get_cell($row, 7)->value();
    }
    if ($worksheet->get_cell($row,8)) {
	     $col_number = $worksheet->get_cell($row, 8)->value();
    }
    if ($worksheet->get_cell($row,9)) {
        $seedlot_name = $worksheet->get_cell($row, 9)->value();
    }
    if ($seedlot_name){
        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    }
    if ($worksheet->get_cell($row,10)) {
        $num_seed_per_plot = $worksheet->get_cell($row, 10)->value();
    }
    if ($worksheet->get_cell($row,11)) {
        $weight_gram_seed_per_plot = $worksheet->get_cell($row, 11)->value();
    }

    #skip blank lines
    if (!$plot_name && !$stock_name && !$plot_number && !$block_number) {
      next;
    }

    my $treatment_col = 12;
    foreach my $treatment_name (@treatment_names){
        if($worksheet->get_cell($row,$treatment_col)){
            if($worksheet->get_cell($row,$treatment_col)->value()){
                push @{$design{treatments}->{$treatment_name}{new_treatment_stocks}}, $plot_name;
            }
        }
        $treatment_col++;
    }

    if ($stock_synonyms_lookup{$stock_name}){
        my @stock_names = keys %{$stock_synonyms_lookup{$stock_name}};
        if (scalar(@stock_names)>1){
            print STDERR "There is more than one uniquename for this synonym $stock_name. this should not happen!\n";
        }
        $stock_name = $stock_names[0];
    }

    my $key = $row;
    $design{$key}->{plot_name} = $plot_name;
    $design{$key}->{stock_name} = $stock_name;
    $design{$key}->{plot_number} = $plot_number;
    $design{$key}->{block_number} = $block_number;
    if ($is_a_control) {
      $design{$key}->{is_a_control} = 1;
    } else {
      $design{$key}->{is_a_control} = 0;
    }
    if ($rep_number) {
      $design{$key}->{rep_number} = $rep_number;
    }
    if ($range_number) {
      $design{$key}->{range_number} = $range_number;
    }
    if ($row_number) {
	     $design{$key}->{row_number} = $row_number;
    }
    if ($col_number) {
	     $design{$key}->{col_number} = $col_number;
    }
    if ($seedlot_name){
        $design{$key}->{seedlot_name} = $seedlot_name;
        $design{$key}->{num_seed_per_plot} = $num_seed_per_plot;
        $design{$key}->{weight_gram_seed_per_plot} = $weight_gram_seed_per_plot;
    }

  }
  #print STDERR Dumper \%design;
  $self->_set_parsed_data(\%design);

  return 1;

}


1;
