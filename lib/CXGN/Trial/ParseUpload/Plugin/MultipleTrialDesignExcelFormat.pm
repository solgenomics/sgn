package CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignExcelFormat;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;
use CXGN::Calendar;
use CXGN::Trial;

sub _validate_with_plugin {

  # print STDERR "Starting validation\t".localtime()."\n";

  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my %errors;
  my @error_messages;
  my %warnings;
  my @warning_messages;
  my %missing_accessions;
  my $parser   = Spreadsheet::ParseExcel->new();
  my $excel_obj;
  my $worksheet;

  #try to open the excel file and report any errors
  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    push @error_messages, $parser->error();
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

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

  my $header_errors = _parse_header($worksheet);
  if (scalar(@{$header_errors}) >= 1) {
    foreach my $error (@{$header_errors}) {
      push @error_messages, $error;
    }
  }

  my @treatment_names;
  for (24 .. $col_max){
      if ($worksheet->get_cell(0,$_)){
          push @treatment_names, $worksheet->get_cell(0,$_)->value();
      }
  }

  my $calendar_funcs = CXGN::Calendar->new({});
  my @pairs;
  my $current_trial_name;
  my $working_on_new_trial;
  my %seen_trial_names;
  my %seen_breeding_programs;
  my %seen_locations;
  my %seen_trial_types;
  my %seen_design_types;
  my %seen_plot_names;
  my %seen_accession_names;
  my %seen_seedlot_names;
  my %seen_plot_numbers;
  my $trial_name = '';
  my $breeding_program;
  my $location;
  my $year;
  my $design_type;
  my $description;
  my $trial_type;
  my $plot_width;
  my $plot_length;
  my $field_size;
  my $planting_date;
  my $harvest_date;

  for my $row ( 1 .. $row_max ) {

      #print STDERR "Check 01 ".localtime();
    my $row_name = $row+1;
    my $plot_name;
    my $accession_name;
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
      $current_trial_name = $worksheet->get_cell($row,0)->value();
    } else {
      $current_trial_name = undef;
    }

    if ($current_trial_name && $current_trial_name ne $trial_name) {
      $working_on_new_trial = 1;
      if ($worksheet->get_cell($row,1)) {
          $breeding_program = $worksheet->get_cell($row,1)->value();
      } else {
          $breeding_program = undef;
      }

      if ($worksheet->get_cell($row,2)) {
        $location = $worksheet->get_cell($row,2)->value();
      } else {
          $location = undef;
      }

      if ($worksheet->get_cell($row,3)) {
        $year = $worksheet->get_cell($row,3)->value();
      } else {
        $year = undef;
      }

      if ($worksheet->get_cell($row,4)) {
        $design_type = $worksheet->get_cell($row,4)->value();
      } else {
        $design_type = undef;
      }

      if ($worksheet->get_cell($row,5)) {
        $description = $worksheet->get_cell($row,5)->value();
      } else {
        $description = undef;
      }

      if ($worksheet->get_cell($row,6)) {
        $trial_type = $worksheet->get_cell($row,6)->value();
      } else {
        $trial_type = undef;
      }

      if ($worksheet->get_cell($row,7)) {
        $plot_width = $worksheet->get_cell($row,7)->value();
      } else {
        $plot_width = undef;
      }

      if ($worksheet->get_cell($row,8)) {
        $plot_length = $worksheet->get_cell($row,8)->value();
      } else {
        $plot_length = undef;
      }

      if ($worksheet->get_cell($row,9)) {
        $field_size = $worksheet->get_cell($row,9)->value();
      } else {
        $field_size = undef;
      }

      if ($worksheet->get_cell($row,10)) {
        $planting_date = $worksheet->get_cell($row,10)->value();
      } else {
        $planting_date = undef;
      }

      if ($worksheet->get_cell($row,11)) {
        $harvest_date = $worksheet->get_cell($row,11)->value();
      } else {
        $harvest_date = undef;
      }
    }

    #skip blank rows
    if (
      !$worksheet->get_cell($row,0)
      && !$worksheet->get_cell($row,1)
      && !$worksheet->get_cell($row,2)
      && !$worksheet->get_cell($row,3)
      && !$worksheet->get_cell($row,4)
      && !$worksheet->get_cell($row,5)
      && !$worksheet->get_cell($row,12)
      && !$worksheet->get_cell($row,13)
      && !$worksheet->get_cell($row,14)
      && !$worksheet->get_cell($row,15)
    ) {
      next;
    }

    if ($worksheet->get_cell($row,12)) {
      $plot_name = $worksheet->get_cell($row,12)->value();
    }
    if ($worksheet->get_cell($row,13)) {
      $accession_name = $worksheet->get_cell($row,13)->value();
    }
    if ($worksheet->get_cell($row,14)) {
      $plot_number =  $worksheet->get_cell($row,14)->value();
    }
    if ($worksheet->get_cell($row,15)) {
      $block_number =  $worksheet->get_cell($row,15)->value();
    }
    if ($worksheet->get_cell($row,16)) {
      $is_a_control =  $worksheet->get_cell($row,16)->value();
    }
    if ($worksheet->get_cell($row,17)) {
      $rep_number =  $worksheet->get_cell($row,17)->value();
    }
    if ($worksheet->get_cell($row,18)) {
      $range_number =  $worksheet->get_cell($row,18)->value();
    }
    if ($worksheet->get_cell($row,19)) {
	     $row_number = $worksheet->get_cell($row,19)->value();
    }
    if ($worksheet->get_cell($row,20)) {
	     $col_number = $worksheet->get_cell($row,20)->value();
    }
    if ($worksheet->get_cell($row,21)) {
      $seedlot_name = $worksheet->get_cell($row,21)->value();
    }
    if ($worksheet->get_cell($row,22)) {
      $num_seed_per_plot = $worksheet->get_cell($row,22)->value();
    }
    if ($worksheet->get_cell($row,23)) {
      $weight_gram_seed_per_plot = $worksheet->get_cell($row,23)->value();
    }

    if ($working_on_new_trial) {

      ## PLOT NUMBER CHECK FOR PREVIOUS TRIAL
      foreach $plot_number ( keys %seen_plot_numbers ) {
        my $count = $seen_plot_numbers{$plot_number};
        if ($count > 1) {
          push @error_messages, "Plot number <b>$plot_number</b> must be unique within the trial. You used this plot number more than once in trial $trial_name";
        }
      }
      ## reset counting hash
      %seen_plot_numbers = ();
      $trial_name = $current_trial_name;

      ## TRIAL NAME CHECK
      if (!$trial_name || $trial_name eq '' ) {
          push @error_messages, "Cell A$row_name: trial_name missing.";
      }
      elsif ($trial_name =~ /\s/ ) {
          push @error_messages, "Cell A$row_name: trial_name <b>$trial_name</b> must not contain spaces.";
      }
      elsif ($trial_name =~ /\// || $trial_name =~ /\\/) {
          push @warning_messages, "Cell A$row_name: trial_name <b>$trial_name</b> contains slashes. Note that slashes can cause problems for third-party applications; however, plotnames can be saved with slashes.";
      } else {
          $trial_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
          $seen_trial_names{$trial_name} = $row_name;
      }

      ## BREEDING PROGRAM CHECK
      if (!$breeding_program || $breeding_program eq '' ) {
          push @error_messages, "Cell B$row_name: breeding_program missing.";
      }
      else {
        $breeding_program =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_breeding_programs{$breeding_program}=$row_name;
      }

      ## LOCATION CHECK
      if (!$location || $location eq '' ) {
          push @error_messages, "Cell C$row_name: location missing.";
      }
      else {
        $location =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_locations{$location}=$row_name;
      }

      ## YEAR CHECK
      if (!($year =~ /^\d{4}$/)) {
          push @error_messages, "Cell D$row_name: <b>$year</b> is not a valid year, must be a 4 digit positive integer.";
      }

      ## DESIGN TYPE CHECK
      if (!$design_type || $design_type eq '' ) {
          push @error_messages, "Cell E$row_name: design_type missing.";
      }
      else {
        $design_type =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_design_types{$design_type}=$row_name;
      }

      ## DESCRIPTION CHECK
      if (!$description || $description eq '' ) {
          push @error_messages, "Cell F$row_name: description missing.";
      }

      ## TRIAL TYPE CHECK
      if ($trial_type) {
        $trial_type =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_trial_types{$trial_type}=$row_name;
      }

      ## PLOT WIDTH CHECK
      if ($plot_width && !($plot_width =~ /^([\d]*)([\.]?)([\d]+)$/)){
          push @error_messages, "Cell H$row_name: plot_width <b>$plot_width</b> must be a positive number.";
      }

      ## PLOT LENGTH CHECK
      if ($plot_length && !($plot_length =~ /^([\d]*)([\.]?)([\d]+)$/)){
          push @error_messages, "Cell I$row_name: plot_length <b>$plot_length</b> must be a positive number.";
      }

      ## FIELD SIZE CHECK
      if ($field_size && !($field_size =~ /^([\d]*)([\.]?)([\d]+)$/)){
          push @error_messages, "Cell J$row_name: field_size <b>$field_size</b> must be a positive number.";
      }

      ## PLANTING DATE CHECK
      if ($planting_date) {
        unless ($calendar_funcs->check_value_format($planting_date)) {
          push @error_messages, "Cell K$row_name: planting_date <b>$planting_date</b> must be in the format YYYY-MM-DD.";
        }
      }

      ## HARVEST DATE CHECK
      if ($harvest_date) {
        unless ($calendar_funcs->check_value_format($harvest_date)) {
          push @error_messages, "Cell L$row_name: harvest_date <b>$harvest_date</b> must be in the format YYYY-MM-DD.";
        }
      }

      $working_on_new_trial = 0;
    }

    ## PLOT NAME CHECK
    if (!$plot_name || $plot_name eq '' ) {
        push @error_messages, "Cell M$row_name: plot name missing.";
    }
    elsif ($plot_name =~ /\s/ ) {
        push @error_messages, "Cell M$row_name: plot name <b>$plot_name</b> must not contain spaces.";
    }
    elsif ($plot_name =~ /\// || $plot_name =~ /\\/) {
        push @warning_messages, "Cell M$row_name: plot name <b>$plot_name</b> contains slashes. Note that slashes can cause problems for third-party applications; however, plotnames can be saved with slashes.";
    }
    else {
        $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        if ($seen_plot_names{$plot_name}) {
            push @error_messages, "Cell M$row_name: duplicate plot name <b>$plot_name</b> seen before at cell M".$seen_plot_names{$plot_name}.".";
        }
        $seen_plot_names{$plot_name}=$row_name;
    }

    ## ACCESSSION NAME CHECK
    if (!$accession_name || $accession_name eq '') {
      push @error_messages, "Cell N$row_name: accession name missing";
    } else {
      $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
      $seen_accession_names{$accession_name}++;
    }

    ## PLOT NUMBER CHECK
    if (!$plot_number || $plot_number eq '') {
        push @error_messages, "Cell O$row_name: plot number missing";
    }
    if (!($plot_number =~ /^\d+?$/)) {
        push @error_messages, "Cell O$row_name: plot number <b>$plot_number</b> is not a positive integer.";
    }
    $seen_plot_numbers{$plot_number}++;

    ## BLOCK NUMBER CHECK
    if (!$block_number || $block_number eq '') {
        push @error_messages, "Cell P$row_name: block number missing";
    }
    if (!($block_number =~ /^\d+?$/)) {
        push @error_messages, "Cell P$row_name: block number <b>$block_number</b> is not a positive integer.";
    }

    ## IS A CONTROL CHECK
    if ($is_a_control) {
      if (!($is_a_control eq "yes" || $is_a_control eq "no" || $is_a_control eq "1" ||$is_a_control eq "0" || $is_a_control eq '')) {
          push @error_messages, "Cell Q$row_name: is_a_control <b>$is_a_control</b> is not either yes, no 1, 0, or blank.";
      }
    }

    ## REP, ROW, RANGE AND COLUMN CHECKS
    if ($rep_number && !($rep_number =~ /^\d+?$/)){
        push @error_messages, "Cell R$row_name: rep_number <b>$rep_number</b> must be a positive integer.";
    }
    if ($range_number && !($range_number =~ /^\d+?$/)){
        push @error_messages, "Cell S$row_name: range_number <b>$range_number</b> must be a positive integer.";
    }
    if ($row_number && !($row_number =~ /^\d+?$/)){
        push @error_messages, "Cell T$row_name: row_number <b>$row_number</b> must be a positive integer.";
    }
    if ($col_number && !($col_number =~ /^\d+?$/)){
        push @error_messages, "Cell U$row_name: col_number <b>$col_number</b> must be a positive integer.";
    }

    ## SEEDLOT CHECKS
    if ($seedlot_name){
        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_seedlot_names{$seedlot_name}++;
        push @pairs, [$seedlot_name, $accession_name];
    }
    if (defined($num_seed_per_plot) && $num_seed_per_plot ne '' && !($num_seed_per_plot =~ /^\d+?$/)){
        push @error_messages, "Cell W$row_name: num_seed_per_plot <b>$num_seed_per_plot</b> must be a positive integer.";
    }
    if (defined($weight_gram_seed_per_plot) && $weight_gram_seed_per_plot ne '' && !($weight_gram_seed_per_plot =~ /^\d+?$/)){
        push @error_messages, "Cell X$row_name: weight_gram_seed_per_plot <b>$weight_gram_seed_per_plot</b> must be a positive integer.";
    }

    ## TREATMENT CHECKS
    my $treatment_col = 24;
    foreach my $treatment_name (@treatment_names){
        if($worksheet->get_cell($row,$treatment_col)){
            my $apply_treatment = $worksheet->get_cell($row,$treatment_col)->value();
            if (defined($apply_treatment) && $apply_treatment ne '1'){
                push @error_messages, "Treatment value for treatment <b>$treatment_name</b> in row $row_name should be either 1 or empty";
            }
        }
        $treatment_col++;
    }

  }

  ## END ROW BY ROW VALIDATION, BEGIN OVERALL VALIDATION
  my $validator = CXGN::List::Validate->new();

  ## TRIAL NAMES OVERALL VALIDATION
  my @trial_names = keys %seen_trial_names;
  my @already_used_trial_names;
  my @missing_trial_names = @{$validator->validate($schema,'trials',\@trial_names)->{'missing'}};
  my %unused_trial_names = map { $missing_trial_names[$_] => $_ } 0..$#missing_trial_names;

  foreach my $name (@trial_names) {
      push(@already_used_trial_names, $name) unless exists $unused_trial_names{$name};
  }
  if (scalar(@already_used_trial_names) > 0) {
    # $errors{'invalid_trial_names'} = \@already_used_trial_names;
    push @error_messages, "Trial name(s) <b>".join(',',@already_used_trial_names)."</b> are invalid because they are already used in the database.";
  }

  ## BREEDING PROGRAMS OVERALL VALIDATION
  my @breeding_programs = keys %seen_breeding_programs;
  my $breeding_programs_missing = $validator->validate($schema,'breeding_programs',\@breeding_programs)->{'missing'};
  my @breeding_programs_missing = @{$breeding_programs_missing};
  if (scalar(@breeding_programs_missing) > 0) {
      # $errors{'missing_breeding_programs'} = \@breeding_programs_missing;
      push @error_messages, "Breeding program(s) <b>".join(',',@breeding_programs_missing)."</b> are not in the database.";
  }

  ## LOCATIONS OVERALL VALIDATION
  my @locations = keys %seen_locations;
  my @locations_missing = @{$validator->validate($schema,'locations',\@locations)->{'missing'}};
  if (scalar(@locations_missing) > 0) {
      # $errors{'missing_locations'} = \@locations_missing;
      push @error_messages, "Location(s) <b>".join(',',@locations_missing)."</b> are not in the database.";
  }

  ## DESIGN TYPES OVERALL VALIDATION
  my @design_types = keys %seen_design_types;
  my %valid_design_types = (
    "CRD" => 1,
    "RCBD" => 1,
    "Alpha" => 1,
    "Lattice" => 1,
    "Augmented" => 1,
    "MAD" => 1,
    "genotyping_plate" => 1,
    "greenhouse" => 1,
    "p-rep" => 1,
    "splitplot" => 1,
    "Westcott" => 1,
    "Analysis" => 1
  );
  my @design_types_missing;
  foreach my $type (@design_types) {
      push(@design_types_missing, $type) unless exists $valid_design_types{$type};
  }
  if (scalar(@design_types_missing) > 0) {
      # $errors{'missing_design_types'} = \@design_types_missing;
      push @error_messages, "Design type(s) <b>".join(',',@design_types_missing)."</b> are not in the database.";
  }

  ## TRIAL TYPES OVERALL VALIDATION
  my @trial_types = keys %seen_trial_types;
  my @trial_types_missing;
  my @valid_trial_types = CXGN::Trial::get_all_project_types($schema);
  my %valid_trial_types = map { @{$_}[1] => 1 } @valid_trial_types;

  foreach my $type (@trial_types) {
      push(@trial_types_missing, $type) unless exists $valid_trial_types{$type};
  }
  if (scalar(@trial_types_missing) > 0) {
      # $errors{'missing_trial_types'} = \@trial_types_missing;
      push @error_messages, "Trial type(s) <b>".join(',',@trial_types_missing)."</b> are not in the database.";
  }

  ## ACCESSIONS OVERALL VALIDATION
  my @accessions = keys %seen_accession_names;
  my @accessions_missing = @{$validator->validate($schema,'accessions',\@accessions)->{'missing'}};

  if (scalar(@accessions_missing) > 0) {
      # $errors{'missing_accessions'} = \@accessions_missing;
      push @error_messages, "Accession(s) <b>".join(',',@accessions_missing)."</b> are not in the database as uniquenames or synonyms.";
  }

  ## SEEDLOTS OVERALL VALIDATION
  my @seedlot_names = keys %seen_seedlot_names;
  if (scalar(@seedlot_names)>0){
      my @seedlots_missing = @{$validator->validate($schema,'seedlots',\@seedlot_names)->{'missing'}};

      if (scalar(@seedlots_missing) > 0) {
          # $errors{'missing_seedlots'} = \@seedlots_missing;
          push @error_messages, "Seedlot(s) <b>".join(',',@seedlots_missing)."</b> are not in the database.";
      }

      my $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, \@pairs);
      if (exists($return->{error})){
          push @error_messages, $return->{error};
      }
  }

  ## PLOT NAMES OVERALL VALIDATION
  my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
  my @uniquenames = keys %seen_plot_names;
  my $rs = $schema->resultset("Stock::Stock")->search({
      'type_id' => $plot_type_id,
      'is_obsolete' => { '!=' => 't' },
      'uniquename' => { -in => \@uniquenames }
  });
  while (my $r=$rs->next){
      push @error_messages, "Cell M".$seen_plot_names{$r->uniquename}.": plot name <b>".$r->uniquename."</b> already exists.";
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

  # print STDERR "Check 3.1.3 ".localtime();
  return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my $parser   = Spreadsheet::ParseExcel->new();
  my $excel_obj;
  my $worksheet;

  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();

  my @treatment_names;
  for (24 .. $col_max){
      if ($worksheet->get_cell(0,$_)){
          push @treatment_names, $worksheet->get_cell(0,$_)->value();
      }
  }

  my %seen_accession_names;
  for my $row ( 1 .. $row_max ) {
      my $accession_name;
      if ($worksheet->get_cell($row,13)) {
          $accession_name = $worksheet->get_cell($row,13)->value();
          $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
          $seen_accession_names{$accession_name}++;
      }
  }
  my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
  my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

  my @accessions = keys %seen_accession_names;
  my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
      'me.is_obsolete' => { '!=' => 't' },
      'stockprops.value' => { -in => \@accessions},
      'me.type_id' => $accession_cvterm_id,
      'stockprops.type_id' => $synonym_cvterm_id
  },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
  my %acc_synonyms_lookup;
  while (my $r=$acc_synonym_rs->next){
      $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
  }

  my %all_designs;
  my %single_design;
  my %design_details;
  my $trial_name = '';
  my $breeding_program;
  my $location;
  my $year;
  my $design_type;
  my $description;
  my @valid_trial_types = CXGN::Trial::get_all_project_types($schema);
  my %trial_type_map = map { @{$_}[1] => @{$_}[0] } @valid_trial_types;
  my $trial_type;
  my $plot_width;
  my $plot_length;
  my $field_size;
  my $planting_date;
  my $harvest_date;

  for my $row ( 1 .. $row_max ) {

    my $current_trial_name;
    my $plot_name;
    my $accession_name;
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
      $current_trial_name = $worksheet->get_cell($row,0)->value();
    }

    if ($current_trial_name && $current_trial_name ne $trial_name) {

      if ($trial_name) {
        ## Save old single trial hash in all trials hash; reinitialize temp hashes
        my %final_design_details = ();
        my $previous_design_data = $all_designs{$trial_name}{'design_details'};
        if ($previous_design_data) {
            %final_design_details = (%design_details, %{$all_designs{$trial_name}{'design_details'}});
        } else {
            %final_design_details = %design_details;
        }
        %design_details = ();
        $single_design{'design_details'} = \%final_design_details;
        my %final_single_design = %single_design;
        %single_design = ();
        $all_designs{$trial_name} = \%final_single_design;
      }
      $single_design{'breeding_program'} = $worksheet->get_cell($row,1)->value();
      $single_design{'location'} = $worksheet->get_cell($row,2)->value();
      $single_design{'year'} = $worksheet->get_cell($row,3)->value();
      $single_design{'design_type'} = $worksheet->get_cell($row,4)->value();
      $single_design{'description'} = $worksheet->get_cell($row,5)->value();

      if ($worksheet->get_cell($row,6)) { # get and save trial type cvterm_id using trial type name
        my $trial_type_id = $trial_type_map{$worksheet->get_cell($row,6)->value()};
        $single_design{'trial_type'} = $trial_type_id;
      }
      if ($worksheet->get_cell($row,7)) {
        $single_design{'plot_width'} = $worksheet->get_cell($row,7)->value();
      }
      if ($worksheet->get_cell($row,8)) {
        $single_design{'plot_length'} = $worksheet->get_cell($row,8)->value();
      }
      if ($worksheet->get_cell($row,9)) {
        $single_design{'field_size'} = $worksheet->get_cell($row,9)->value();
      }
      if ($worksheet->get_cell($row,10)) {
        $single_design{'planting_date'} = $worksheet->get_cell($row,10)->value();
      }
      if ($worksheet->get_cell($row,11)) {
        $single_design{'harvest_date'} = $worksheet->get_cell($row,11)->value();
      }
      ## Update trial name
      $trial_name = $current_trial_name;
    }

    #skip blank rows
    if (
      !$worksheet->get_cell($row,0)
      && !$worksheet->get_cell($row,1)
      && !$worksheet->get_cell($row,2)
      && !$worksheet->get_cell($row,3)
      && !$worksheet->get_cell($row,4)
      && !$worksheet->get_cell($row,5)
      && !$worksheet->get_cell($row,12)
      && !$worksheet->get_cell($row,13)
      && !$worksheet->get_cell($row,14)
      && !$worksheet->get_cell($row,15)
    ) {
      next;
    }

    if ($worksheet->get_cell($row,12)) {
      $plot_name = $worksheet->get_cell($row,12)->value();
    }
    $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,13)) {
      $accession_name = $worksheet->get_cell($row,13)->value();
    }
    $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,14)) {
      $plot_number =  $worksheet->get_cell($row,14)->value();
    }
    if ($worksheet->get_cell($row,15)) {
      $block_number =  $worksheet->get_cell($row,15)->value();
    }
    if ($worksheet->get_cell($row,16)) {
      $is_a_control =  $worksheet->get_cell($row,16)->value();
    }
    if ($worksheet->get_cell($row,17)) {
      $rep_number =  $worksheet->get_cell($row,17)->value();
    }
    if ($worksheet->get_cell($row,18)) {
      $range_number =  $worksheet->get_cell($row,18)->value();
    }
    if ($worksheet->get_cell($row,19)) {
	     $row_number = $worksheet->get_cell($row, 19)->value();
    }
    if ($worksheet->get_cell($row,20)) {
	     $col_number = $worksheet->get_cell($row, 20)->value();
    }
    if ($worksheet->get_cell($row,21)) {
        $seedlot_name = $worksheet->get_cell($row, 21)->value();
    }
    if ($seedlot_name){
        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    }
    if ($worksheet->get_cell($row,22)) {
        $num_seed_per_plot = $worksheet->get_cell($row, 22)->value();
    }
    if ($worksheet->get_cell($row,23)) {
        $weight_gram_seed_per_plot = $worksheet->get_cell($row, 23)->value();
    }

    my $treatment_col = 24;
    foreach my $treatment_name (@treatment_names){
        if($worksheet->get_cell($row,$treatment_col)){
            if($worksheet->get_cell($row,$treatment_col)->value()){
                push @{$design_details{treatments}->{$treatment_name}{new_treatment_stocks}}, $plot_name;
            }
        }
        $treatment_col++;
    }

    if ($acc_synonyms_lookup{$accession_name}){
        my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
        if (scalar(@accession_names)>1){
            print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
        }
        $accession_name = $accession_names[0];
    }

    my $key = $row;
    $design_details{$key}->{plot_name} = $plot_name;
    $design_details{$key}->{stock_name} = $accession_name;
    $design_details{$key}->{plot_number} = $plot_number;
    $design_details{$key}->{block_number} = $block_number;
    if ($is_a_control) {
      $design_details{$key}->{is_a_control} = 1;
    } else {
      $design_details{$key}->{is_a_control} = 0;
    }
    if ($rep_number) {
      $design_details{$key}->{rep_number} = $rep_number;
    }
    if ($range_number) {
      $design_details{$key}->{range_number} = $range_number;
    }
    if ($row_number) {
	     $design_details{$key}->{row_number} = $row_number;
    }
    if ($col_number) {
	     $design_details{$key}->{col_number} = $col_number;
    }
    if ($seedlot_name){
        $design_details{$key}->{seedlot_name} = $seedlot_name;
        $design_details{$key}->{num_seed_per_plot} = $num_seed_per_plot;
        $design_details{$key}->{weight_gram_seed_per_plot} = $weight_gram_seed_per_plot;
    }

  }

  # add last trial design to all_designs and save parsed data, then return
  my %final_design_details = ();
  my $previous_design_data = $all_designs{$trial_name}{'design_details'};
  if ($previous_design_data) {
      %final_design_details = (%design_details, %{$all_designs{$trial_name}{'design_details'}});
  } else {
      %final_design_details = %design_details;
  }
  $single_design{'design_details'} = \%final_design_details;
  $all_designs{$trial_name} = \%single_design;

  $self->_set_parsed_data(\%all_designs);

  return 1;

}

sub _parse_header {
  #get column headers
  my $worksheet = shift;

  my $trial_name_head;
  my $breeding_program_head;
  my $location_head;
  my $year_head;
  my $design_type_head;
  my $description_head;
  my $trial_type_head;
  my $plot_width_head;
  my $plot_length_head;
  my $field_size_head;
  my $planting_date_head;
  my $harvest_date_head;
  my $plot_name_head;
  my $accession_name_head;
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
    $trial_name_head= $worksheet->get_cell(0,0)->value();
  }
  if ($worksheet->get_cell(0,1)) {
    $breeding_program_head= $worksheet->get_cell(0,1)->value();
  }
  if ($worksheet->get_cell(0,2)) {
    $location_head= $worksheet->get_cell(0,2)->value();
  }
  if ($worksheet->get_cell(0,3)) {
    $year_head= $worksheet->get_cell(0,3)->value();
  }
  if ($worksheet->get_cell(0,4)) {
    $design_type_head= $worksheet->get_cell(0,4)->value();
  }
  if ($worksheet->get_cell(0,5)) {
    $description_head= $worksheet->get_cell(0,5)->value();
  }
  if ($worksheet->get_cell(0,6)) {
    $trial_type_head= $worksheet->get_cell(0,6)->value();
  }
  if ($worksheet->get_cell(0,7)) {
    $plot_width_head= $worksheet->get_cell(0,7)->value();
  }
  if ($worksheet->get_cell(0,8)) {
    $plot_length_head= $worksheet->get_cell(0,8)->value();
  }
  if ($worksheet->get_cell(0,9)) {
    $field_size_head= $worksheet->get_cell(0,9)->value();
  }
  if ($worksheet->get_cell(0,10)) {
    $planting_date_head= $worksheet->get_cell(0,10)->value();
  }
  if ($worksheet->get_cell(0,11)) {
    $harvest_date_head= $worksheet->get_cell(0,11)->value();
  }
  if ($worksheet->get_cell(0,12)) {
    $plot_name_head  = $worksheet->get_cell(0,12)->value();
  }
  if ($worksheet->get_cell(0,13)) {
    $accession_name_head  = $worksheet->get_cell(0,13)->value();
  }
  if ($worksheet->get_cell(0,14)) {
    $plot_number_head  = $worksheet->get_cell(0,14)->value();
  }
  if ($worksheet->get_cell(0,15)) {
    $block_number_head  = $worksheet->get_cell(0,15)->value();
  }
  if ($worksheet->get_cell(0,16)) {
    $is_a_control_head  = $worksheet->get_cell(0,16)->value();
  }
  if ($worksheet->get_cell(0,17)) {
    $rep_number_head  = $worksheet->get_cell(0,17)->value();
  }
  if ($worksheet->get_cell(0,18)) {
    $range_number_head  = $worksheet->get_cell(0,18)->value();
  }
  if ($worksheet->get_cell(0,19)) {
      $row_number_head  = $worksheet->get_cell(0,19)->value();
  }
  if ($worksheet->get_cell(0,20)) {
      $col_number_head  = $worksheet->get_cell(0,20)->value();
  }
  if ($worksheet->get_cell(0,21)) {
    $seedlot_name_head  = $worksheet->get_cell(0,21)->value();
  }
  if ($worksheet->get_cell(0,22)) {
    $num_seed_per_plot_head = $worksheet->get_cell(0,22)->value();
  }
  if ($worksheet->get_cell(0,23)) {
    $weight_gram_seed_per_plot_head = $worksheet->get_cell(0,23)->value();
  }

  my @error_messages;

  if (!$trial_name_head || $trial_name_head ne 'trial_name' ) {
    push @error_messages, "Cell A1: trial_name is missing from the header";
  }
  if (!$breeding_program_head || $breeding_program_head ne 'breeding_program' ) {
    push @error_messages, "Cell B1: breeding_program is missing from the header";
  }
  if (!$location_head || $location_head ne 'location' ) {
    push @error_messages, "Cell C1: location is missing from the header";
  }
  if (!$year_head || $year_head ne 'year' ) {
    push @error_messages, "Cell D1: year is missing from the header";
  }
  if (!$design_type_head || $design_type_head ne 'design_type' ) {
    push @error_messages, "Cell E1: design_type is missing from the header";
  }
  if (!$description_head || $description_head ne 'description' ) {
    push @error_messages, "Cell F1: description is missing from the header";
  }
  if (!$trial_type_head || $trial_type_head ne 'trial_type' ) {
    push @error_messages, "Cell G1: trial_type is missing from the header";
  }
  if (!$plot_width_head || $plot_width_head ne 'plot_width' ) {
    push @error_messages, "Cell H1: plot_width is missing from the header";
  }
  if (!$plot_length_head || $plot_length_head ne 'plot_length' ) {
    push @error_messages, "Cell I1: plot_length is missing from the header";
  }
  if (!$field_size_head || $field_size_head ne 'field_size' ) {
    push @error_messages, "Cell J1: field_size is missing from the header";
  }
  if (!$planting_date_head || $planting_date_head ne 'planting_date' ) {
    push @error_messages, "Cell K1: planting_date is missing from the header";
  }
  if (!$harvest_date_head || $harvest_date_head ne 'harvest_date' ) {
    push @error_messages, "Cell L1: harvest_date is missing from the header";
  }
  if (!$plot_name_head || $plot_name_head ne 'plot_name' ) {
    push @error_messages, "Cell M1: plot_name is missing from the header";
  }
  if (!$accession_name_head || $accession_name_head ne 'accession_name') {
    push @error_messages, "Cell N1: accession_name is missing from the header";
  }
  if (!$plot_number_head || $plot_number_head ne 'plot_number') {
    push @error_messages, "Cell O1: plot_number is missing from the header";
  }
  if (!$block_number_head || $block_number_head ne 'block_number') {
    push @error_messages, "Cell P1: block_number is missing from the header";
  }
  if (!$is_a_control_head || $is_a_control_head ne 'is_a_control') {
    push @error_messages, "Cell Q1: is_a_control is missing from the header. (Header is required, but values are optional)";
  }
  if (!$rep_number_head || $rep_number_head ne 'rep_number') {
    push @error_messages, "Cell R1: rep_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$range_number_head || $range_number_head ne 'range_number') {
    push @error_messages, "Cell S1: range_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$row_number_head || $row_number_head ne 'row_number') {
    push @error_messages, "Cell T1: row_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$col_number_head || $col_number_head ne 'col_number') {
    push @error_messages, "Cell U1: col_number is missing from the header. (Header is required, but values are optional)";
  }
  if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name') {
    push @error_messages, "Cell V1: seedlot_name is missing from the header. (Header is required, but values are optional)";
  }
  if (!$num_seed_per_plot_head || $num_seed_per_plot_head ne 'num_seed_per_plot') {
    push @error_messages, "Cell W1: num_seed_per_plot is missing from the header. (Header is required, but values are optional)";
  }
  if (!$weight_gram_seed_per_plot_head || $weight_gram_seed_per_plot_head ne 'weight_gram_seed_per_plot') {
    push @error_messages, "Cell X1: weight_gram_seed_per_plot is missing from the header. (Header is required, but values are optional)";
  }

  return \@error_messages;

}


1;
