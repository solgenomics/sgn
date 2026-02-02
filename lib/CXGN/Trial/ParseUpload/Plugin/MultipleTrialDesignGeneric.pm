package CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignGeneric;

use Moose::Role;
use List::MoreUtils qw(uniq);
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::List::Transform;
use CXGN::Stock::Seedlot;
use CXGN::Calendar;
use CXGN::Trial;
use CXGN::Trait;

my @REQUIRED_COLUMNS = qw|trial_name breeding_program location year design_type description accession_name plot_number block_number|;
my @OPTIONAL_COLUMNS = qw|plot_name trial_type trial_stock_type plot_width plot_length field_size planting_date transplanting_date harvest_date is_a_control rep_number range_number row_number col_number seedlot_name num_seed_per_plot weight_gram_seed_per_plot entry_number|;
# Any additional columns that are not required or optional will be parsed as treatments. 

# VALID DESIGN TYPES
my %valid_design_types = (
    "CRD" => 1,
    "RCBD" => 1,
    "RRC" => 1,
    "DRRC" => 1,
    "URDD" => 1,
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

# VALID STOCK TYPES
my %valid_stock_types = (
    "accession" => 1,
    "cross" => 1,
    "family_name" => 1
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
        optional_columns => \@OPTIONAL_COLUMNS,
        column_aliases => {
            'accession_name' => [ 'stock_name', 'cross_unique_id', 'family_name' ]
        }
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{'errors'};
    my $parsed_data = $parsed->{'data'};
    my $parsed_values = $parsed->{'values'};
    my $treatments = $parsed->{'additional_columns'};

    my $trait_validator = CXGN::List::Validate->new();
    
    my $validate = $trait_validator->validate($schema, "traits", $treatments);

    foreach my $treatment (@{$treatments}) {
        if ($treatment !~ m/_TREATMENT:/) {
            push @error_messages, "Column $treatment is not formatted like a treatment. Use only full, valid treatment names.\n";
        }
    }

    if (@{$validate->{missing}}>0) { 
        foreach my $missing (@{$validate->{missing}}) {
            push @error_messages, "Treatment $missing does not exist in the database.\n";
        }
    }

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
        my $data = $_;
        my $row = $data->{'_row'};
        my $trial_name = $data->{'trial_name'};
        my $breeding_program = $data->{'breeding_program'};
        my $location = $data->{'location'};
        my $year = $data->{'year'};
        my $design_type = $data->{'design_type'};
        my $description = $data->{'description'};
        my $accession_name = $data->{'accession_name'};
        my $plot_number = $data->{'plot_number'};
        my $block_number = $data->{'block_number'};
        my $plot_name = $data->{'plot_name'} || _create_plot_name($trial_name, $plot_number);
        my $trial_type = $data->{'trial_type'};
        my $plot_width = $data->{'plot_width'};
        my $plot_length = $data->{'plot_length'};
        my $field_size = $data->{'field_size'};
        my $planting_date = $data->{'planting_date'};
        my $transplanting_date = $data->{'transplanting_date'};
        my $harvest_date = $data->{'harvest_date'};
        my $is_a_control = $data->{'is_a_control'};
        my $rep_number = $data->{'rep_number'};
        my $range_number = $data->{'range_number'};
        my $row_number = $data->{'row_number'};
        my $col_number = $data->{'col_number'};
        my $seedlot_name = $data->{'seedlot_name'};
        my $num_seed_per_plot = $data->{'num_seed_per_plot'};
        my $weight_gram_seed_per_plot = $data->{'weight_gram_seed_per_plot'};
        my $entry_number = $data->{'entry_number'};

        foreach my $treatment (@{$treatments}) {
            my $lt = CXGN::List::Transform->new();

            my $transform = $lt->transform($schema, 'traits_2_trait_ids', [$treatment]);
            my @treatment_id_list = @{$transform->{transform}};
            my $treatment_id = $treatment_id_list[0];

            my $treatment_obj = CXGN::Trait->new({
                bcs_schema => $schema, 
                cvterm_id => $treatment_id
            });
            if ($treatment_obj->format() eq "numeric" && defined($treatment_obj->minimum()) && defined($data->{$treatment}) && $data->{$treatment} < $treatment_obj->minimum()) {
                push @error_messages, "Row $row: value for $treatment is lower than the allowed minimum for that treatment.";
            }
            if ($treatment_obj->format() eq "numeric" && defined($treatment_obj->maximum()) && defined($data->{$treatment}) && $data->{$treatment} > $treatment_obj->maximum()) {
                push @error_messages, "Row $row: value for $treatment is higher than the allowed maximum for that treatment.";
            }
            if ($treatment_obj->format() eq "qualitative" && defined($treatment_obj->categories()) && defined($data->{$treatment})) {
                my $qual_value = $data->{$treatment};
                my $categories = $treatment_obj->categories();
                if ( $categories !~ m/$qual_value/) {
                    push @error_messages, "Row $row: value for $treatment is not in the valid categories for that treatment.";
                }
            }
        }

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

        # Map to check for duplicated plot names (unique across all trials)
        if ( $plot_name ) {
            my $pk = $plot_name;
            if ( !exists $seen_plot_names{$pk} ) {
                $seen_plot_names{$pk} = 1;
            }
            else {
                $seen_plot_names{$pk}++;
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
        push @error_messages, "Trial name(s) <strong>".join(', ',@already_used_trial_names)."</strong> are invalid because they are already used in the database.";
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
        push @warning_messages, "File location <strong>$location_code</strong> matches the code for the location named <strong>$found_location_name</strong> and will be substituted if you ignore warnings.";
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

    # Trial Stock Type: must be a valid / supported trial stock type
    foreach (@{$parsed_values->{'trial_stock_type'}}) {
        if ( !exists $valid_stock_types{$_} ) {
            push @error_messages, "trial_stock_type <strong>$_</strong> is not supported. Supported trial stock types: " . join(', ', keys(%valid_stock_types)) . ".";
        }
    }

    # Accession Names: must exist in the database
    my @accessions = @{$parsed_values->{'accession_name'}};
    my $accessions_hashref = $validator->validate($schema,'accessions',\@accessions);
    my @multiple_synonyms = @{$accessions_hashref->{'multiple_synonyms'}};

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
    $accessions_hashref = $validator->validate($schema,'accessions_or_crosses_or_familynames',\@accessions);
    my @accessions_missing = @{$accessions_hashref->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "Stocks(s) <strong>".join(',',@accessions_missing)."</strong> are not in the database as uniquenames or synonyms of accessions, crosses, or families.";
    }
    if (scalar(@multiple_synonyms) > 0) {
        my @msgs;
        foreach my $m (@multiple_synonyms) {
            push(@msgs, 'Name: ' . @$m[0] . ' = Synonym: ' . @$m[1]);
        }
        push @error_messages, "Accession(s) <strong>".join(',',@msgs)."</strong> appear in the database as synonyms of more than one unique accession. Please change to the unique accession name or delete the multiple synonyms";
    }

    # Plot Names: should not exist (as any stock)
    my @plot_names = keys %seen_plot_names;
    my @already_used_plot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plot_names }
    });
    foreach my $r ($rs->all()) {
        push @already_used_plot_names, $r->uniquename();
    }
    if (scalar(@already_used_plot_names) > 0) {
        push @error_messages, "Plot name(s) <strong>".join(', ',@already_used_plot_names)."</strong> are invalid because they are already used in the database.";
    }

    # Seedlots: names must exist in the database
    my @seedlots_missing = @{$validator->validate($schema,'seedlots',$parsed_values->{'seedlot_name'})->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "Seedlot(s) <strong>".join(',',@seedlots_missing)."</strong> are not in the database.  To use a seedlot as a seed source for a plot, the seedlot must already exist in the database.";
    }

    # Verify seedlot pairs: accession name of plot must match seedlot contents
    if ( scalar(@seedlot_pairs) > 0 ) {
        my $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, \@seedlot_pairs);
        if (exists($return->{error})) {
            push @error_messages, $return->{error};
        }
    }

    # Check for duplicated plot numbers
    foreach my $tk (keys %seen_plot_numbers) {
        foreach my $pk (keys %{$seen_plot_numbers{$tk}}) {
            my $count = $seen_plot_numbers{$tk}{$pk};
            if ( $count > 1 ) {
                push @error_messages, "Plot number <strong>$pk</strong> in trial <strong>$tk</strong> is used $count times.  Each plot should have a unique plot number in an individual trial.";
            }
        }
    }

    # Check for duplicated plot names
    foreach my $pk (keys %seen_plot_names) {
        my $count = $seen_plot_names{$pk};
        if ( $count > 1 ) {
            push @error_messages, "Plot name <strong>$pk</strong> is used $count times. Each plot should have a unique plot name across all trials.";
        }
    }

    # Check for overlapping plot positions (more than one plot assigned the same row/col positions)
    foreach my $tk (keys %seen_plot_positions) {
        foreach my $pk (keys %{$seen_plot_positions{$tk}}) {
            my $plots = $seen_plot_positions{$tk}{$pk};
            my $count = scalar(@$plots);
            if ( $count > 1 ) {
                my @pos = split('-', $pk);
                push @warning_messages, "More than 1 plot is assigned to the position row=" . $pos[0] . " col=" . $pos[1] . " trial=" . $tk . " plots=" . join(',', @$plots);
            }
        }
    }

    # Check for entry number errors:
    # the same accession assigned different entry numbers
    # the same entry number assigned to different accessions
    foreach my $tk (keys %seen_entry_numbers) {

        # check assignments by accessions
        foreach my $an (keys %{$seen_entry_numbers{$tk}{'by_acc'}} ) {
            my @ens = uniq @{$seen_entry_numbers{$tk}{'by_acc'}{$an}};
            my $count = scalar(@ens);
            if ( scalar(@ens) > 1 ) {
                push @error_messages, "Entry Number mismatch: Accession <strong>$an</strong> has multiple entry numbers (" . join(', ', @ens) . ") assigned to it in trial <strong>$tk</strong>.";
            }
        }

        # check assigments by entry number
        foreach my $en (keys %{$seen_entry_numbers{$tk}{'by_num'}} ) {
            my @ans = uniq @{$seen_entry_numbers{$tk}{'by_num'}{$en}};
            my $count = scalar(@ans);
            if ( scalar(@ans) > 1 ) {
                push @error_messages, "Entry Number mismatch: Entry number <strong>$en</strong> has multiple accessions (" . join(', ', @ans) . ") assigned to it in trial <strong>$tk</strong>.";
            }
        }

    }

    # Return warnings and error messages
    if (scalar(@warning_messages) >= 1) {
        $warnings{'warning_messages'} = \@warning_messages;
        $self->_set_parse_warnings(\%warnings);
    }
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_validated_data($parsed);
    return 1; #returns true if validation is passed
}


sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $parsed = $self->_get_validated_data();
    my $data = $parsed->{'data'};
    my $values = $parsed->{'values'};
    my $treatments = $parsed->{'additional_columns'};

    # Get synonyms for accessions in data
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my @accessions = @{$values->{'accession_name'}};
    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => \@accessions},
        'me.type_id' => $accession_cvterm_id,
        'stockprops.type_id' => $synonym_cvterm_id
    },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});

    # Create lookup hash for synonym -> uniquename -> stock id
    my %acc_synonyms_lookup;
    while (my $r=$acc_synonym_rs->next){
        $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
    }

    # Create map of trial type codes to trial type ids
    my @valid_trial_types = CXGN::Trial::get_all_project_types($schema);
    my %trial_type_map = map { @{$_}[1] => @{$_}[0] } @valid_trial_types;

    my %all_designs;
    my %single_design;
    my %design_details;
    my %seen_entry_numbers;
    my $trial_name = '';
    for my $row (@$data) {
        my $row_id = $row->{'_row'};
        my $current_trial_name = $row->{'trial_name'};
        my $accession_name = $row->{'accession_name'};
        my $plot_number = $row->{'plot_number'};
        my $plot_name = $row->{'plot_name'} || _create_plot_name($current_trial_name, $plot_number);
        my $block_number = $row->{'block_number'};
        my $is_a_control = $row->{'is_a_control'};
        my $rep_number = $row->{'rep_number'};
        my $range_number = $row->{'range_number'};
        my $row_number = $row->{'row_number'};
        my $col_number = $row->{'col_number'};
        my $seedlot_name = $row->{'seedlot_name'};
        my $num_seed_per_plot = $row->{'num_seed_per_plot'} || 0;
        my $weight_gram_seed_per_plot = $row->{'weight_gram_seed_per_plot'} || 0;
        my $entry_number = $row->{'entry_number'};

        if ($current_trial_name && $current_trial_name ne $trial_name) {

            ## Save old single trial hash in all trials hash; reinitialize temp hashes
            if ($trial_name) {
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
            my $location = $row->{'location'};
            if ( $self->_has_location_code_map() ) {
                my $location_code_map = $self->_get_location_code_map();
                if ( exists $location_code_map->{$location} ) {
                    $location = $location_code_map->{$location};
                }
            }

            $single_design{'breeding_program'} = $row->{'breeding_program'};
            $single_design{'location'} = $location;
            $single_design{'year'} = $row->{'year'};
            $single_design{'design_type'} = $row->{'design_type'};
            $single_design{'description'} = $row->{'description'};
            $single_design{'trial_stock_type'} = $row->{'trial_stock_type'} || 'accession';
            $single_design{'plot_width'} = $row->{'plot_width'};
            $single_design{'plot_length'} = $row->{'plot_length'};
            $single_design{'field_size'} = $row->{'field_size'};
            $single_design{'planting_date'} = $row->{'planting_date'};
            $single_design{'harvest_date'} = $row->{'harvest_date'};

            # for a moment transplanting_date is moves as not required but whole design of that features must be redone
            # including use cases
            if ($row->{'transplanting_date'}) {
                $single_design{'transplanting_date'} = $row->{'transplanting_date'};
            }

            # get and save trial type cvterm_id using trial type name
            if ($row->{'trial_type'}) {
                my $trial_type_id = $trial_type_map{$row->{'trial_type'}};
                $single_design{'trial_type'} = $trial_type_id;
            }

            ## Update trial name
            $trial_name = $current_trial_name;
        }

        if ($entry_number) {
            $seen_entry_numbers{$current_trial_name}->{$accession_name} = $entry_number;
        }

        if ($acc_synonyms_lookup{$accession_name}){
            my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
            if (scalar(@accession_names)>1){
                print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
            }
            $accession_name = $accession_names[0];
        }

        my $key = $row_id;
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
        foreach my $treatment (@{$treatments}) {
            if (defined($row->{$treatment})) {
                $design_details{'treatments'}->{$plot_name}->{$treatment} = [$row->{$treatment}];
            }
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

sub _create_plot_name {
  my $trial_name = shift;
  my $plot_number = shift;
  return $trial_name . "-PLOT_" . $plot_number;
}

1;
