package CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignExcelFormat;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;
use CXGN::Calendar;
use CXGN::Trial;

#
# DEPRECATED: This plugin has been replaced by the MultipleTrialDesignGeneric plugin
#

my @REQUIRED_COLUMNS = qw|trial_name breeding_program location year design_type description accession_name plot_number block_number|;
my @OPTIONAL_COLUMNS = qw|plot_name trial_type plot_width plot_length field_size planting_date transplanting_date harvest_date is_a_control rep_number range_number row_number col_number seedlot_name num_seed_per_plot weight_gram_seed_per_plot entry_number|;
# Any additional columns that are not required or optional will be used as a treatment

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
  if ( ($col_max - $col_min) < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
    push @error_messages, "Spreadsheet is missing header or contains no rows";
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

  my $headers = _parse_headers($worksheet);
  my %columns = %{$headers->{columns}};
  my @treatment_names = @{$headers->{treatments}};
  my @errors = @{$headers->{errors}};
    if (scalar(@errors) >= 1) {
    foreach my $error (@errors) {
      push @error_messages, $error;
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
  my $transplanting_date;
  my $design_type;
  my $description;
  my $trial_type;
  my $plot_width;
  my $plot_length;
  my $field_size;
  my $planting_date;
  my $harvest_date;
  my %seen_plot_keys;
  my %seen_entry_numbers;

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
    my $entry_number;

    if ($worksheet->get_cell($row,$columns{trial_name}->{index})) {
      $current_trial_name = $worksheet->get_cell($row,$columns{trial_name}->{index})->value();
    } else {
      $current_trial_name = undef;
    }

    if ($current_trial_name && $current_trial_name ne $trial_name) {
      $working_on_new_trial = 1;
      if ($worksheet->get_cell($row,$columns{breeding_program}->{index})) {
        $breeding_program = $worksheet->get_cell($row,$columns{breeding_program}->{index})->value();
      } else {
        $breeding_program = undef;
      }

      if ($worksheet->get_cell($row,$columns{location}->{index})) {
        $location = $worksheet->get_cell($row,$columns{location}->{index})->value();
      } else {
        $location = undef;
      }

      if ($worksheet->get_cell($row,$columns{year}->{index})) {
        $year = $worksheet->get_cell($row,$columns{year}->{index})->value();
      } else {
        $year = undef;
      }

      if ($worksheet->get_cell($row,$columns{transplanting_date}->{index})) {
        $transplanting_date = $worksheet->get_cell($row,$columns{transplanting_date}->{index})->value();
      } else {
        $transplanting_date = undef;
      }

      if ($worksheet->get_cell($row,$columns{design_type}->{index})) {
        $design_type = $worksheet->get_cell($row,$columns{design_type}->{index})->value();
      } else {
        $design_type = undef;
      }

      if ($worksheet->get_cell($row,$columns{description}->{index})) {
        $description = $worksheet->get_cell($row,$columns{description}->{index})->value();
      } else {
        $description = undef;
      }

      if ($worksheet->get_cell($row,$columns{trial_type}->{index})) {
        $trial_type = $worksheet->get_cell($row,$columns{trial_type}->{index})->value();
      } else {
        $trial_type = undef;
      }

      if ($worksheet->get_cell($row,$columns{plot_width}->{index})) {
        $plot_width = $worksheet->get_cell($row,$columns{plot_width}->{index})->value();
      } else {
        $plot_width = undef;
      }

      if ($worksheet->get_cell($row,$columns{plot_length}->{index})) {
        $plot_length = $worksheet->get_cell($row,$columns{plot_length}->{index})->value();
      } else {
        $plot_length = undef;
      }

      if ($worksheet->get_cell($row,$columns{field_size}->{index})) {
        $field_size = $worksheet->get_cell($row,$columns{field_size}->{index})->value();
      } else {
        $field_size = undef;
      }

      if ($worksheet->get_cell($row,$columns{planting_date}->{index})) {
        $planting_date = $worksheet->get_cell($row,$columns{planting_date}->{index})->value();
      } else {
        $planting_date = undef;
      }

      if ($worksheet->get_cell($row,$columns{harvest_date}->{index})) {
        $harvest_date = $worksheet->get_cell($row,$columns{harvest_date}->{index})->value();
      } else {
        $harvest_date = undef;
      }

      $seen_entry_numbers{$current_trial_name} = {
        by_num => {},
        by_acc => {}
      };
    }

    #skip blank rows
    my $has_row_value;
    foreach (keys %columns) {
      if ( $worksheet->get_cell($row,$columns{$_}->{index})) {
        if ( $worksheet->get_cell($row,$columns{$_}->{index})->value() ) {
          $has_row_value = 1;
        }
      }
    }
    if ( !$has_row_value ) {
      next;
    }

    if ($worksheet->get_cell($row,$columns{plot_name}->{index})) {
      $plot_name = $worksheet->get_cell($row,$columns{plot_name}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{accession_name}->{index})) {
      $accession_name = $worksheet->get_cell($row,$columns{accession_name}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{plot_number}->{index})) {
      $plot_number =  $worksheet->get_cell($row,$columns{plot_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{block_number}->{index})) {
      $block_number =  $worksheet->get_cell($row,$columns{block_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{is_a_control}->{index})) {
      $is_a_control =  $worksheet->get_cell($row,$columns{is_a_control}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{rep_number}->{index})) {
      $rep_number =  $worksheet->get_cell($row,$columns{rep_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{range_number}->{index})) {
      $range_number =  $worksheet->get_cell($row,$columns{range_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{row_number}->{index})) {
      $row_number = $worksheet->get_cell($row,$columns{row_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{col_number}->{index})) {
      $col_number = $worksheet->get_cell($row,$columns{col_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{seedlot_name}->{index})) {
      $seedlot_name = $worksheet->get_cell($row,$columns{seedlot_name}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{num_seed_per_plot}->{index})) {
      $num_seed_per_plot = $worksheet->get_cell($row,$columns{num_seed_per_plot}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{weight_gram_seed_per_plot}->{index})) {
      $weight_gram_seed_per_plot = $worksheet->get_cell($row,$columns{weight_gram_seed_per_plot}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{entry_number}->{index})) {
      $entry_number = $worksheet->get_cell($row,$columns{entry_number}->{index})->value();
    }

    if ( $row_number && $col_number ) {
      my $tk = $current_trial_name;
      my $pk = "$row_number-$col_number";
      if ( !exists $seen_plot_keys{$tk} ) {
        $seen_plot_keys{$tk} = {};
      }
      if ( !exists $seen_plot_keys{$tk}{$pk} ) {
        $seen_plot_keys{$tk}{$pk} = [$plot_number];
      }
      else {
        push @{$seen_plot_keys{$tk}{$pk}}, $plot_number;
      }
    }

    if ($working_on_new_trial) {

      ## PLOT NUMBER CHECK FOR PREVIOUS TRIAL
      foreach my $pn ( keys %seen_plot_numbers ) {
        my $count = $seen_plot_numbers{$pn};
        if ($count > 1) {
          push @error_messages, "Plot number <b>$pn</b> must be unique within the trial. You used this plot number more than once in trial $trial_name";
        }
      }
      ## reset counting hash
      %seen_plot_numbers = ();
      $trial_name = $current_trial_name;

      ## TRIAL NAME CHECK
      if (!$trial_name || $trial_name eq '' ) {
        push @error_messages, "Row $row_name: trial_name missing.";
      }
      elsif ($trial_name =~ /\s/ ) {
        push @error_messages, "Row $row_name: trial_name <b>$trial_name</b> must not contain spaces.";
      }
      elsif ($trial_name =~ /\// || $trial_name =~ /\\/) {
        push @warning_messages, "Row $row_name: trial_name <b>$trial_name</b> contains slashes. Note that slashes can cause problems for third-party applications; however, plotnames can be saved with slashes.";
      } else {
        $trial_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_trial_names{$trial_name} = $row_name;
      }

      ## BREEDING PROGRAM CHECK
      if (!$breeding_program || $breeding_program eq '' ) {
        push @error_messages, "Row $row_name: breeding_program missing.";
      }
      else {
        $breeding_program =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_breeding_programs{$breeding_program}=$row_name;
      }

      ## LOCATION CHECK
      if (!$location || $location eq '' ) {
        push @error_messages, "Row $row_name: location missing.";
      }
      else {
        $location =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_locations{$location}=$row_name;
      }

      ## YEAR CHECK
      if (!($year =~ /^\d{4}$/)) {
        push @error_messages, "Row $row_name: <b>$year</b> is not a valid year, must be a 4 digit positive integer.";
      }

      ## TRANSPLANTING DATE CHECK
      if ($transplanting_date) {
        unless ($calendar_funcs->check_value_format($transplanting_date)) {
          push @error_messages, "Row $row_name: transplanting_date <b>$transplanting_date</b> must be in the format YYYY-MM-DD.";
        }
      }

      ## DESIGN TYPE CHECK
      if (!$design_type || $design_type eq '' ) {
        push @error_messages, "Row $row_name: design_type missing.";
      }
      else {
        $design_type =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_design_types{$design_type}=$row_name;
      }

      ## DESCRIPTION CHECK
      if (!$description || $description eq '' ) {
        push @error_messages, "Row $row_name: description missing.";
      }

      ## TRIAL TYPE CHECK
      if ($trial_type) {
        $trial_type =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_trial_types{$trial_type}=$row_name;
      }

      ## PLOT WIDTH CHECK
      if ($plot_width && !($plot_width =~ /^([\d]*)([\.]?)([\d]+)$/)){
        push @error_messages, "Row $row_name: plot_width <b>$plot_width</b> must be a positive number.";
      }

      ## PLOT LENGTH CHECK
      if ($plot_length && !($plot_length =~ /^([\d]*)([\.]?)([\d]+)$/)){
        push @error_messages, "Row $row_name: plot_length <b>$plot_length</b> must be a positive number.";
      }

      ## FIELD SIZE CHECK
      if ($field_size && !($field_size =~ /^([\d]*)([\.]?)([\d]+)$/)){
        push @error_messages, "Row $row_name: field_size <b>$field_size</b> must be a positive number.";
      }

      ## PLANTING DATE CHECK
      if ($planting_date) {
        unless ($calendar_funcs->check_value_format($planting_date)) {
          push @error_messages, "Row $row_name: planting_date <b>$planting_date</b> must be in the format YYYY-MM-DD.";
        }
      }

      ## HARVEST DATE CHECK
      if ($harvest_date) {
        unless ($calendar_funcs->check_value_format($harvest_date)) {
          push @error_messages, "Row $row_name: harvest_date <b>$harvest_date</b> must be in the format YYYY-MM-DD.";
        }
      }

      $working_on_new_trial = 0;
    }

    ## PLOT NAME CHECK
    if (!$plot_name || $plot_name eq '' ) {
      $plot_name = _create_plot_name($current_trial_name, $plot_number);
    }
    elsif ($plot_name =~ /\s/ ) {
      push @error_messages, "Row $row_name: plot name <b>$plot_name</b> must not contain spaces.";
    }
    elsif ($plot_name =~ /\// || $plot_name =~ /\\/) {
      push @warning_messages, "Row $row_name: plot name <b>$plot_name</b> contains slashes. Note that slashes can cause problems for third-party applications; however, plotnames can be saved with slashes.";
    }
    else {
      $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
      if ($seen_plot_names{$plot_name}) {
        push @error_messages, "Row $row_name: duplicate plot name <b>$plot_name</b> seen before at row ".$seen_plot_names{$plot_name}.".";
      }
      $seen_plot_names{$plot_name}=$row_name;
    }

    ## ACCESSSION NAME CHECK
    if (!$accession_name || $accession_name eq '') {
      push @error_messages, "Row $row_name: accession name missing";
    } else {
      $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
      $seen_accession_names{$accession_name}++;
    }

    ## PLOT NUMBER CHECK
    if (!$plot_number || $plot_number eq '') {
      push @error_messages, "Row $row_name: plot number missing";
    }
    if (!($plot_number =~ /^\d+?$/)) {
      push @error_messages, "Row $row_name: plot number <b>$plot_number</b> is not a positive integer.";
    }
    $seen_plot_numbers{$plot_number}++;

    ## BLOCK NUMBER CHECK
    if (!$block_number || $block_number eq '') {
      push @error_messages, "Row $row_name: block number missing";
    }
    if (!($block_number =~ /^\d+?$/)) {
      push @error_messages, "Row $row_name: block number <b>$block_number</b> is not a positive integer.";
    }

    ## IS A CONTROL CHECK
    if ($is_a_control) {
      if (!($is_a_control eq "yes" || $is_a_control eq "no" || $is_a_control eq "1" ||$is_a_control eq "0" || $is_a_control eq '')) {
        push @error_messages, "Row $row_name: is_a_control <b>$is_a_control</b> is not either yes, no 1, 0, or blank.";
      }
    }

    ## REP, ROW, RANGE AND COLUMN CHECKS
    if ($rep_number && !($rep_number =~ /^\d+?$/)){
      push @error_messages, "Row $row_name: rep_number <b>$rep_number</b> must be a positive integer.";
    }
    if ($range_number && !($range_number =~ /^\d+?$/)){
      push @error_messages, "Row $row_name: range_number <b>$range_number</b> must be a positive integer.";
    }
    if ($row_number && !($row_number =~ /^\d+?$/)){
      push @error_messages, "Row $row_name: row_number <b>$row_number</b> must be a positive integer.";
    }
    if ($col_number && !($col_number =~ /^\d+?$/)){
      push @error_messages, "Row $row_name: col_number <b>$col_number</b> must be a positive integer.";
    }

    ## SEEDLOT CHECKS
    if ($seedlot_name){
      $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
      $seen_seedlot_names{$seedlot_name}++;
      push @pairs, [$seedlot_name, $accession_name];
    }
    if (defined($num_seed_per_plot) && $num_seed_per_plot ne '' && !($num_seed_per_plot =~ /^\d+?$/)){
      push @error_messages, "Row $row_name: num_seed_per_plot <b>$num_seed_per_plot</b> must be a positive integer.";
    }
    if (defined($weight_gram_seed_per_plot) && $weight_gram_seed_per_plot ne '' && !($weight_gram_seed_per_plot =~ /^\d+?$/)){
      push @error_messages, "Row $row_name: weight_gram_seed_per_plot <b>$weight_gram_seed_per_plot</b> must be a positive integer.";
    }

    ## ENTRY NUMBER CHECK
    if ($entry_number) {
      my $ex_acc = $seen_entry_numbers{$current_trial_name}->{by_num}->{$entry_number};
      my $ex_en = $seen_entry_numbers{$current_trial_name}->{by_acc}->{$accession_name};
      if ( $ex_acc ) {
        if ( $ex_acc ne $accession_name ) {
          push @error_messages, "Row $row_name: entry number $entry_number has already been assigned to a different accession ($ex_acc).";
        }
      }
      elsif ( $ex_en ) {
        if ( $ex_en ne $entry_number ) {
          push @error_messages, "Row $row_name: accession $accession_name has already been assigned a different entry number ($ex_en).";
        }
      }
      else {
        $seen_entry_numbers{$current_trial_name}->{by_num}->{$entry_number} = $accession_name;
        $seen_entry_numbers{$current_trial_name}->{by_acc}->{$accession_name} = $entry_number;
      }
    }

    ## TREATMENT CHECKS
    foreach my $treatment_name (@treatment_names){
      my $treatment_col = $columns{$treatment_name}->{index};
      if($worksheet->get_cell($row,$treatment_col)){
        my $apply_treatment = $worksheet->get_cell($row,$treatment_col)->value();
        if ( ($apply_treatment ne '') && defined($apply_treatment) && $apply_treatment ne '1'){
          push @error_messages, "Treatment value for treatment <b>$treatment_name</b> in row $row_name should be either 1 or empty";
        }
    }
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
  my $locations_hashref = $validator->validate($schema,'locations',\@locations);

  # Find valid location codes
  my @codes = @{$locations_hashref->{'codes'}};
  my %location_code_map;
  foreach my $code (@codes) {
    my $location_code = $code->[0];
    my $found_location_name = $code->[1];
    $location_code_map{$location_code} = $found_location_name;
    push @warning_messages, "File Location '$location_code' matches the code for the location named '$found_location_name' and will be substituted if you ignore warnings.";
  }
  $self->_set_location_code_map(\%location_code_map);

  # Check the missing locations, ignoring matched codes
  my @locations_missing = @{$locations_hashref->{'missing'}};
  my @locations_missing_no_codes = grep { !exists $location_code_map{$_} } @locations_missing;
  if (scalar(@locations_missing_no_codes) > 0) {
    push @error_messages, "Location(s) <b>".join(',',@locations_missing_no_codes)."</b> are not in the database.";
  }

  ## DESIGN TYPES OVERALL VALIDATION
  my @design_types = keys %seen_design_types;
  my %valid_design_types = (
    "CRD" => 1,
    "RCBD" => 1,
    "RRC" => 1,
    "DRRC" => 1,
    "ARC" => 1,
    "Alpha" => 1,
    "Lattice" => 1,
    "Augmented" => 1,
    "MAD" => 1,
    "genotyping_plate" => 1,
    "greenhouse" => 1,
    "p-rep" => 1,
    "splitplot" => 1,
    "stripplot" => 1,
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
  my $accessions_hashref = $validator->validate($schema,'accessions',\@accessions);

  #find unique synonyms. Sometimes trial uploads use synonym names instead of the unique accession name. We allow this if the synonym is unique and matches one accession in the database
  my @synonyms =  @{$accessions_hashref->{'synonyms'}};
  foreach my $synonym (@synonyms) {
    my $found_acc_name_from_synonym = $synonym->{'uniquename'};
    my $matched_synonym = $synonym->{'synonym'};

    push @warning_messages, "File Accession $matched_synonym is a synonym of database accession $found_acc_name_from_synonym ";

    @accessions = grep !/\Q$matched_synonym/, @accessions;
    push @accessions, $found_acc_name_from_synonym;
  }

  #now validate again the accession names
  $accessions_hashref = $validator->validate($schema,'accessions',\@accessions);

  my @accessions_missing = @{$accessions_hashref->{'missing'}};
  my @multiple_synonyms = @{$accessions_hashref->{'multiple_synonyms'}};

  if (scalar(@accessions_missing) > 0) {
    # $errors{'missing_accessions'} = \@accessions_missing;
    push @error_messages, "Accession(s) <b>".join(',',@accessions_missing)."</b> are not in the database as uniquenames or synonyms.";
  }
  if (scalar(@multiple_synonyms) > 0) {
    my @msgs;
    foreach my $m (@multiple_synonyms) {
      push(@msgs, 'Name: ' . @$m[0] . ' = Synonym: ' . @$m[1]);
    }
    push @error_messages, "Accession(s) <b>".join(',',@msgs)."</b> appear in the database as synonyms of more than one unique accession. Please change to the unique accession name or delete the multiple synonyms";
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
    push @error_messages, "Plot name <b>".$r->uniquename."</b> already exists.";
  }

  ## PLOT POSITION OVERALL VALIDATION
  foreach my $tk (keys %seen_plot_keys) {
    foreach my $pk (keys %{$seen_plot_keys{$tk}} ) {
      my $plots = $seen_plot_keys{$tk}{$pk};
      my $count = scalar(@{$plots});
      if ( $count > 1 ) {
        my @pos = split('-', $pk);
        push @warning_messages, "More than 1 plot is assigned to the position row=" . $pos[0] . " col=" . $pos[1] . " trial=" . $tk . " plots=" . join(',', @$plots);
      }
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

  # print STDERR "Check 3.1.3 ".localtime();
  return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();

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

  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();

  my $headers = _parse_headers($worksheet);
  my %columns = %{$headers->{columns}};
  my @treatment_names = @{$headers->{treatments}};

  my %seen_accession_names;
  for my $row ( 1 .. $row_max ) {
    my $accession_name;
    if ($worksheet->get_cell($row,$columns{accession_name}->{index})) {
      $accession_name = $worksheet->get_cell($row,$columns{accession_name}->{index})->value();
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
  my %seen_entry_numbers;

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
    my $entry_number;

    if ($worksheet->get_cell($row,$columns{trial_name}->{index})) {
      $current_trial_name = $worksheet->get_cell($row,$columns{trial_name}->{index})->value();
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
        $single_design{'entry_numbers'} = $seen_entry_numbers{$trial_name};
        my %final_single_design = %single_design;
        %single_design = ();
        $all_designs{$trial_name} = \%final_single_design;
      }

      # Get location and replace codes with names
      my $location = $worksheet->get_cell($row,$columns{location}->{index})->value();
      if ( $self->_has_location_code_map() ) {
        my $location_code_map = $self->_get_location_code_map();
        if ( exists $location_code_map->{$location} ) {
          $location = $location_code_map->{$location};
        }
      }

      $single_design{'breeding_program'} = $worksheet->get_cell($row,$columns{breeding_program}->{index})->value();
      $single_design{'location'} = $location;
      $single_design{'year'} = $worksheet->get_cell($row,$columns{year}->{index})->value();
      # $single_design{'transplanting_date'} = $worksheet->get_cell($row,$columns{transplanting_date}->{index})->value();
      $single_design{'design_type'} = $worksheet->get_cell($row,$columns{design_type}->{index})->value();
      $single_design{'description'} = $worksheet->get_cell($row,$columns{description}->{index})->value();


      # for a moment transplanting_date is moves as not required but whole design of that features must be redone
      # including use cases
      if ($worksheet->get_cell($row,$columns{transplanting_date}->{index})) {
        $single_design{'transplanting_date'} = $worksheet->get_cell($row,$columns{transplanting_date}->{index})->value();
      }

      if ($worksheet->get_cell($row,$columns{trial_type}->{index})) { # get and save trial type cvterm_id using trial type name
        my $trial_type_id = $trial_type_map{$worksheet->get_cell($row,$columns{trial_type}->{index})->value()};
        $single_design{'trial_type'} = $trial_type_id;
      }
      if ($worksheet->get_cell($row,$columns{plot_width}->{index})) {
        $single_design{'plot_width'} = $worksheet->get_cell($row,$columns{plot_width}->{index})->value();
      }
      if ($worksheet->get_cell($row,$columns{plot_length}->{index})) {
        $single_design{'plot_length'} = $worksheet->get_cell($row,$columns{plot_length}->{index})->value();
      }
      if ($worksheet->get_cell($row,$columns{field_size}->{index})) {
        $single_design{'field_size'} = $worksheet->get_cell($row,$columns{field_size}->{index})->value();
      }
      if ($worksheet->get_cell($row,$columns{planting_date}->{index})) {
        $single_design{'planting_date'} = $worksheet->get_cell($row,$columns{planting_date}->{index})->value();
      }
      if ($worksheet->get_cell($row,$columns{harvest_date}->{index})) {
        $single_design{'harvest_date'} = $worksheet->get_cell($row,$columns{harvest_date}->{index})->value();
      }
      ## Update trial name
      $trial_name = $current_trial_name;
    }

    #skip blank rows
    my $has_row_value;
    foreach (keys %columns) {
      if ( $worksheet->get_cell($row,$columns{$_}->{index})) {
        if ( $worksheet->get_cell($row,$columns{$_}->{index})->value() ) {
          $has_row_value = 1;
        }
      }
    }
    if ( !$has_row_value ) {
      next;
    }

    if ($worksheet->get_cell($row,$columns{plot_number}->{index})) {
      $plot_number = $worksheet->get_cell($row,$columns{plot_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{plot_name}->{index})) {
      $plot_name = $worksheet->get_cell($row,$columns{plot_name}->{index})->value();
    }
    if (!$plot_name || $plot_name eq '') {
      $plot_name = _create_plot_name($current_trial_name, $plot_number);
    }
    $plot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,$columns{accession_name}->{index})) {
      $accession_name = $worksheet->get_cell($row,$columns{accession_name}->{index})->value();
    }
    $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    if ($worksheet->get_cell($row,$columns{block_number}->{index})) {
      $block_number =  $worksheet->get_cell($row,$columns{block_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{is_a_control}->{index})) {
      $is_a_control =  $worksheet->get_cell($row,$columns{is_a_control}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{rep_number}->{index})) {
      $rep_number =  $worksheet->get_cell($row,$columns{rep_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{range_number}->{index})) {
      $range_number =  $worksheet->get_cell($row,$columns{range_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{row_number}->{index})) {
      $row_number = $worksheet->get_cell($row, $columns{row_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{col_number}->{index})) {
      $col_number = $worksheet->get_cell($row, $columns{col_number}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{seedlot_name}->{index})) {
      $seedlot_name = $worksheet->get_cell($row, $columns{seedlot_name}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{entry_number}->{index})) {
      $entry_number = $worksheet->get_cell($row, $columns{entry_number}->{index})->value();
    }

    if ($seedlot_name){
      $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
    }
    if ($worksheet->get_cell($row,$columns{num_seed_per_plot}->{index})) {
      $num_seed_per_plot = $worksheet->get_cell($row, $columns{num_seed_per_plot}->{index})->value();
    }
    if ($worksheet->get_cell($row,$columns{weight_gram_seed_per_plot}->{index})) {
      $weight_gram_seed_per_plot = $worksheet->get_cell($row, $columns{weight_gram_seed_per_plot}->{index})->value();
    }

    if ($entry_number) {
      $seen_entry_numbers{$current_trial_name}->{$accession_name} = $entry_number;
    }

    foreach my $treatment_name (@treatment_names){
      my $treatment_col = $columns{$treatment_name}->{index};
      if($worksheet->get_cell($row,$treatment_col)){
        if($worksheet->get_cell($row,$treatment_col)->value()){
          push @{$design_details{treatments}->{$treatment_name}{new_treatment_stocks}}, $plot_name;
        }
      }
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
  $single_design{'entry_numbers'} = $seen_entry_numbers{$trial_name};
  $all_designs{$trial_name} = \%single_design;

  $self->_set_parsed_data(\%all_designs);

  return 1;

}

sub _parse_headers {
  my $worksheet = shift;
  my ( $col_min, $col_max ) = $worksheet->col_range();
  my %columns;
  my @treatments;
  my @errors;

  for ( $col_min .. $col_max ) {
    if ( $worksheet->get_cell(0,$_) ) {
      my $header = $worksheet->get_cell(0,$_)->value();
      $header =~ s/^\s+|\s+$//g;
      my $is_required = !!grep( /^$header$/, @REQUIRED_COLUMNS );
      my $is_optional = !!grep( /^$header$/, @OPTIONAL_COLUMNS );
      my $is_treatment = !grep( /^$header$/, @REQUIRED_COLUMNS ) && !grep( /^$header$/, @OPTIONAL_COLUMNS );
      $columns{$header} = {
        header => $header,
        index => $_,
        is_required => $is_required,
        is_optional => $is_optional,
        is_treatment => $is_treatment
      };
      if ( $is_treatment ) {
        push(@treatments, $header);
      }
    }
  }

  foreach (@REQUIRED_COLUMNS) {
    if ( !exists $columns{$_} ) {
      push(@errors, "Required column $_ is missing from the file!");
    }
  }

  return {
    columns => \%columns,
    treatments => \@treatments,
    errors => \@errors
  }
}

sub _create_plot_name {
  my $trial_name = shift;
  my $plot_number = shift;
  return $trial_name . "-PLOT_" . $plot_number;
}

1;
