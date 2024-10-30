package CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignGeneric;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;
use CXGN::Calendar;
use CXGN::Trial;

my @REQUIRED_COLUMNS = qw|trial_name breeding_program location year design_type description accession_name plot_number block_number|;
my @OPTIONAL_COLUMNS = qw|plot_name trial_type plot_width plot_length field_size planting_date transplanting_date harvest_date is_a_control rep_number range_number row_number col_number seedlot_name num_seed_per_plot weight_gram_seed_per_plot entry_number|;
# Any additional columns that are not required or optional will be used as a treatment

# VALID DESIGN TYPES
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

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    # Date and List validators
    my $calendar_funcs = CXGN::Calendar->new({});
    my $validator = CXGN::List::Validate->new();

    # Valid Trial Types
    my @valid_trial_types = CXGN::Trial::get_all_project_types($schema);
    my %valid_trial_types = map { @{$_}[1] => 1 } @valid_trial_types;

    # Encountered Error and Warning Messages
    my %errors;
    my @error_messages;
    my %warnings;
    my @warning_messages;

    # Read and parse the upload file
    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => \@REQUIRED_COLUMNS,
        optional_columns => \@OPTIONAL_COLUMNS
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{'errors'};
    my $parsed_data = $parsed->{'data'};
    my $parsed_values = $parsed->{'values'};
    my $treatments = $parsed->{'additional_columns'};

    # Return file parsing errors
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Maps of plot-level data to use in overall validation
    my %seen_plot_numbers;      # check for a plot numbers: used only once per trial
    my %seen_plot_names;        # check for plot names: used only once per trial
    my %seen_plot_positions;    # check for plot row / col positions: each position only used once per trial
    my %seen_entry_numbers;     # check for entry numbers: used only once per trial
    my @seedlot_pairs;          # 2D array of [seedlot_name, accession_name]

    ##
    ## ROW BY ROW VALIDATION
    ## These are checks on the individual plot-level data
    ##
    foreach (@$parsed_data) {
        my $row = $_->{'_row'};
        my $trial_name = $_->{'trial_name'};
        my $breeding_program = $_->{'breeding_program'};
        my $location = $_->{'location'};
        my $year = $_->{'year'};
        my $design_type = $_->{'design_type'};
        my $description = $_->{'description'};
        my $accession_name = $_->{'accession_name'};
        my $plot_number = $_->{'plot_number'};
        my $block_number = $_->{'block_number'};
        my $plot_name = $_->{'plot_name'};
        my $trial_type = $_->{'trial_type'};
        my $plot_width = $_->{'plot_width'};
        my $plot_length = $_->{'plot_length'};
        my $field_size = $_->{'field_size'};
        my $planting_date = $_->{'planting_date'};
        my $transplanting_date = $_->{'transplanting_date'};
        my $harvest_date = $_->{'harvest_date'};
        my $is_a_control = $_->{'is_a_control'};
        my $rep_number = $_->{'rep_number'};
        my $range_number = $_->{'range_number'};
        my $row_number = $_->{'row_number'};
        my $col_number = $_->{'col_number'};
        my $seedlot_name = $_->{'seedlot_name'};
        my $num_seed_per_plot = $_->{'num_seed_per_plot'};
        my $weight_gram_seed_per_plot = $_->{'weight_gram_seed_per_plot'};
        my $entry_number = $_->{'entry_number'};

        # TODO: Remove
        print STDERR "ROW: $row = $trial_name / $plot_name / $accession_name / $plot_number\n";

        # Plot Number: must be a positive number
        if (!($plot_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: plot number <strong>$plot_number</strong> must be a positive integer.";
        }

        # Block Number: must be a positive integer
        if (!($block_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: block number <strong>$block_number</strong> must be a positive integer.";
        }

        # Rep Number: must be a positive integer, if provided
        if ($rep_number && !($rep_number =~ /^\d+?$/)){
            push @error_messages, "Row $row: rep_number <strong>$rep_number</strong> must be a positive integer.";
        }

        # Plot Name: cannot contain spaces, should not contain slashes
        if ($plot_name =~ /\s/ ) {
            push @error_messages, "Row $row: plot name <strong>$plot_name</strong> must not contain spaces.";
        }
        if ($plot_name =~ /\// || $plot_name =~ /\\/) {
            push @warning_messages, "Row $row: plot name <strong>$plot_name</strong> contains slashes. Note that slashes can cause problems for third-party applications; however, plot names can be saved with slashes if you ignore warnings.";
        }

        # Plot Width / Plot Length / Field Size: must be a positive number, if provided
        if ($plot_width && !($plot_width =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, "Row $row: plot_width <strong>$plot_width</strong> must be a positive number.";
        }
        if ($plot_length && !($plot_length =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, "Row $row: plot_length <strong>$plot_length</strong> must be a positive number.";
        }
        if ($field_size && !($field_size =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, "Row $row: plot_width <strong>$field_size</strong> must be a positive number.";
        }

        # Transplanting / Planting / Harvest Dates: must be YYYY-MM-DD format, if provided
        if ($transplanting_date && !$calendar_funcs->check_value_format($transplanting_date)) {
            push @error_messages, "Row $row: transplanting_date <strong>$transplanting_date</strong> must be in the format YYYY-MM-DD.";
        }
        if ($planting_date && !$calendar_funcs->check_value_format($planting_date)) {
            push @error_messages, "Row $row: planting_date <strong>$planting_date</strong> must be in the format YYYY-MM-DD.";
        }
        if ($harvest_date && !$calendar_funcs->check_value_format($harvest_date)) {
            push @error_messages, "Row $row: harvest_date <strong>$harvest_date</strong> must be in the format YYYY-MM-DD.";
        }

        # Is A Control: must be blank, 0, or 1, if provided
        if ( $is_a_control && $is_a_control ne '' && $is_a_control ne '0' && $is_a_control ne '1' ) {
            push @error_messages, "Row $row: is_a_control value of <strong>$is_a_control</strong> is invalid.  It must be blank (not a control), 0 (not a control), or 1 (is a control).";
        }

        # Range Number / Row Number / Col Number: must be a positive integer, if provided
        if ($range_number && !($range_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: range_number <strong>$range_number</strong> must be a positive integer.";
        }
        if ($row_number && !($row_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: row_number <strong>$row_number</strong> must be a positive integer.";
        }
        if ($col_number && !($col_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: col_number <strong>$col_number</strong> must be a positive integer.";
        }

        # Seedlots: add seedlot_name / accession_name to seedlot_pairs
        # count and weight must be a positive integer
        # return a warning if both count and weight are not provided
        if ( $seedlot_name ) {
            push @seedlot_pairs, [$seedlot_name, $accession_name];
            if ( $num_seed_per_plot && $num_seed_per_plot ne '' && !($num_seed_per_plot =~ /^\d+?$/) ) {
                push @error_messages, "Row $row: num_seed_per_plot <strong>$num_seed_per_plot</strong> must be a positive integer.";
            }
            if ( $weight_gram_seed_per_plot && $weight_gram_seed_per_plot ne '' && !($weight_gram_seed_per_plot =~ /^\d+?$/) ) {
                push @error_messages, "Row $row: weight_gram_seed_per_plot <strong>$weight_gram_seed_per_plot</strong> must be a positive integer.";
            }
            if ( !$num_seed_per_plot && !$weight_gram_seed_per_plot ) {
                push @warning_messages, "Row $row: this plot does not have a count or weight of seed to be used from seedlot <strong>$seedlot_name</strong>."
            }
        }

        # Entry Number: must be a positive integer, if provided
        if ($entry_number && !($entry_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: entry_number <strong>$entry_number</strong> must be a positive integer.";
        }

        # Treatment Values: must be either blank, 0, or 1
        foreach my $treatment (@$treatments) {
            my $treatment_value = $row->{$treatment};
            print STDERR "Row $row: $treatment = $treatment_value\n";
            if ( $treatment_value && $treatment_value ne '' && $treatment_value ne '0' && $treatment_value ne '1' ) {
                push @error_messages, "Row $row: Treatment value for treatment <strong>$treatment</strong> should be either 1 (applied) or empty (not applied).";
            }
        }


        # Create maps to check for overall validation within individual trials
        my $tk = $trial_name;

        # Map to check for duplicated plot numbers
        if ( $plot_number ) {
            my $pk = $plot_number;
            if ( !exists $seen_plot_numbers{$tk} ) {
                $seen_plot_numbers{$tk} = {};
            }
            if ( !exists $seen_plot_numbers{$tk}{$pk} ) {
                $seen_plot_numbers{$tk}{$pk} = 1;
            }
            else {
                $seen_plot_numbers{$tk}{$pk}++;
            }
        }

        # Map to check for duplicated plot names
        if ( $plot_name ) {
            my $pk = $plot_name;
            if ( !exists $seen_plot_names{$tk} ) {
                $seen_plot_names{$tk} = {};
            }
            if ( !exists $seen_plot_names{$tk}{$pk} ) {
                $seen_plot_names{$tk}{$pk} = [$plot_number];
            }
            else {
                push @{$seen_plot_names{$tk}{$pk}}, $plot_number;
            }
        }

        # Map to check for overlapping plots
        if ( $row_number && $col_number ) {
            my $pk = "$row_number-$col_number";
            if ( !exists $seen_plot_positions{$tk} ) {
                $seen_plot_positions{$tk} = {};
            }
            if ( !exists $seen_plot_positions{$tk}{$pk} ) {
                $seen_plot_positions{$tk}{$pk} = [$plot_number];
            }
            else {
                push @{$seen_plot_positions{$tk}{$pk}}, $plot_number;
            }
        }

        # Map to check the entry number <-> accession associations
        # For each trial: each entry number should only be associated with one accession
        # and each accession should only be associated with one entry number
        if ( $entry_number ) {
            if ( !exists $seen_entry_numbers{$tk} ) {
                $seen_entry_numbers{$tk}->{'by_num'} = {};
                $seen_entry_numbers{$tk}->{'by_acc'} = {};
            }

            if ( !exists $seen_entry_numbers{$tk}->{'by_num'}->{$entry_number} ) {
                $seen_entry_numbers{$tk}->{'by_num'}->{$entry_number} = [$accession_name];
            }
            else {
                push @{$seen_entry_numbers{$tk}->{'by_num'}->{$entry_number}}, $accession_name;
            }

            if ( !exists $seen_entry_numbers{$tk}->{'by_acc'}->{$accession_name} ) {
                $seen_entry_numbers{$tk}->{'by_acc'}->{$accession_name} = [$entry_number];
            }
            else {
                push @{$seen_entry_numbers{$tk}->{'by_acc'}->{$accession_name}}, $entry_number;
            }
        }
    }

    ##
    ## OVERALL VALIDATION
    ## These are checks on the unique values of different columns
    ##

    # Trial Name: cannot already exist in the database, cannot contain spaces, should not contain slashes
    my @already_used_trial_names;
    my @missing_trial_names = @{$validator->validate($schema,'trials',$parsed_values->{'trial_name'})->{'missing'}};
    my %unused_trial_names = map { $missing_trial_names[$_] => $_ } 0..$#missing_trial_names;
    foreach (@{$parsed_values->{'trial_name'}}) {
        push(@already_used_trial_names, $_) unless exists $unused_trial_names{$_};
        if ($_ =~ /\s/) {
            push @error_messages, "trial_name <strong>$_</strong> must not contain spaces.";
        }
        if ($_ =~ /\// || $_ =~ /\\/) {
            push @warning_messages, "trial_name <strong>$_</strong> contains slashes. Note that slashes can cause problems for third-party applications; however, trial names can be saved with slashes if you ignore warnings.";
        }
    }
    if (scalar(@already_used_trial_names) > 0) {
        push @error_messages, "Trial name(s) <strong>".join(',',@already_used_trial_names)."</strong> are invalid because they are already used in the database.";
    }

    # Breeding Program: must already exist in the database
    my $breeding_programs_missing = $validator->validate($schema,'breeding_programs',$parsed_values->{'breeding_program'})->{'missing'};
    my @breeding_programs_missing = @{$breeding_programs_missing};
    if (scalar(@breeding_programs_missing) > 0) {
        push @error_messages, "Breeding program(s) <strong>".join(',',@breeding_programs_missing)."</strong> are not in the database.";
    }

    # Location: Transform location abbreviations/codes to full names
    my $locations_hashref = $validator->validate($schema,'locations',$parsed_values->{'location'});
    my @codes = @{$locations_hashref->{'codes'}};
    my %location_code_map;
    foreach my $code (@codes) {
        my $location_code = $code->[0];
        my $found_location_name = $code->[1];
        $location_code_map{$location_code} = $found_location_name;
        push @warning_messages, "File location '$location_code' matches the code for the location named '$found_location_name' and will be substituted if you ignore warnings.";
    }
    $self->_set_location_code_map(\%location_code_map);

    # Location: must already exist in the database
    my @locations_missing = @{$locations_hashref->{'missing'}};
    my @locations_missing_no_codes = grep { !exists $location_code_map{$_} } @locations_missing;
    if (scalar(@locations_missing_no_codes) > 0) {
        push @error_messages, "Location(s) <strong>".join(',',@locations_missing_no_codes)."</strong> are not in the database.";
    }

    # Year: must be a 4 digit integer
    foreach (@{$parsed_values->{'year'}}) {
        if (!($_ =~ /^\d{4}$/)) {
            push @error_messages, "year <strong>$_</strong> is not a valid year, must be a 4 digit positive integer.";
        }
    }

    # Design Type: must be a valid / supported design type
    foreach (@{$parsed_values->{'design_type'}}) {
        if ( !exists $valid_design_types{$_} ) {
            push @error_messages, "design_type <strong>$_</strong> is not supported. Supported design types: " . join(', ', keys(%valid_design_types)) . ".";
        }
    }

    # Trial Type: must be a valid / supported trial type
    foreach (@{$parsed_values->{'trial_type'}}) {
        if ( !exists $valid_trial_types{$_} ) {
            push @error_messages, "trial_type <strong>$_</strong> is not supported. Supported trial types: " . join(', ', keys(%valid_trial_types)) . ".";
        }
    }

    # Accession Names: must exist in the database
    my @accessions = @{$parsed_values->{'accession_name'}};
    my $accessions_hashref = $validator->validate($schema,'accessions',\@accessions);

    #find unique synonyms. Sometimes trial uploads use synonym names instead of the unique accession name. We allow this if the synonym is unique and matches one accession in the database
    my @synonyms = @{$accessions_hashref->{'synonyms'}};
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
        push @error_messages, "Accession(s) <strong>".join(',',@accessions_missing)."</strong> are not in the database as uniquenames or synonyms.";
    }
    if (scalar(@multiple_synonyms) > 0) {
        my @msgs;
        foreach my $m (@multiple_synonyms) {
            push(@msgs, 'Name: ' . @$m[0] . ' = Synonym: ' . @$m[1]);
        }
        push @error_messages, "Accession(s) <strong>".join(',',@msgs)."</strong> appear in the database as synonyms of more than one unique accession. Please change to the unique accession name or delete the multiple synonyms";
    }

    # Seedlots...

    # Check trial-level maps


    # NOT FINISHED!
    push @error_messages, "Generic Trial Upload not fully implemented!";


    print STDERR "\n\n\n\n=====> WARNINGS:\n";
    print STDERR Dumper \@warning_messages;
    print STDERR "\n=====> ERRORS:\n";
    print STDERR Dumper \@error_messages;


    if (scalar(@warning_messages) >= 1) {
        $warnings{'warning_messages'} = \@warning_messages;
        $self->_set_parse_warnings(\%warnings);
    }
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

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
