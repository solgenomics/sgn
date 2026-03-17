package CXGN::Trial::ParseUpload::Plugin::TrialGeneric;

use Moose::Role;
use List::MoreUtils qw(uniq);
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::List::Transform;
use CXGN::Stock::Seedlot;
use CXGN::Trial;
use Data::Dumper;

my @REQUIRED_COLUMNS = qw|stock_name plot_number block_number|;
# stock_name can also be accession_name, cross_unique_id, or family_name
my @OPTIONAL_COLUMNS = qw|intercrop_stock_name plot_name is_a_control rep_number range_number row_number col_number seedlot_name num_seed_per_plot weight_gram_seed_per_plot entry_number|;
# Any additional columns that are not required or optional will be used as a treatment

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $trial_name = $self->get_trial_name();

    # Encountered Error and Warning Messages
    my %errors;
    my @error_messages;
    my %warnings;
    my @warning_messages;
    my $validator = CXGN::List::Validate->new();

    # Read and parse the upload file
    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => \@REQUIRED_COLUMNS,
        optional_columns => \@OPTIONAL_COLUMNS,
        column_aliases => {
            'stock_name' => [ 'accession_name', 'cross_unique_id', 'family_name' ],
            'intercrop_stock_name' => [ 'intercrop_accession_name', 'intercrop_cross_unique_id', 'intercrop_family_name' ]
        },
        column_arrays => [ 'intercrop_stock_name' ]
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
    my @seedlot_pairs;          # 2D array of [seedlot_name, accession_name]
    my %seen_entry_numbers;     # check for entry numbers: used only once per trial
    $seen_entry_numbers{'by_num'} = {};
    $seen_entry_numbers{'by_acc'} = {};

    ##
    ## ROW BY ROW VALIDATION
    ## These are checks on the individual plot-level data
    ##
    foreach (@$parsed_data) {
        my $data = $_;
        my $row = $data->{'_row'};
        my $stock_name = $data->{'stock_name'};
        my $intercrop_stock_name = $data->{'intercrop_stock_name'};
        my $plot_number = $data->{'plot_number'};
        my $block_number = $data->{'block_number'};
        my $plot_name = $data->{'plot_name'} || _create_plot_name($trial_name, $plot_number);
        my $trial_type = $data->{'trial_type'};
        my $plot_width = $data->{'plot_width'};
        my $plot_length = $data->{'plot_length'};
        my $field_size = $data->{'field_size'};
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
            push @seedlot_pairs, [$seedlot_name, $stock_name];
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


        # Map to check for duplicated plot numbers
        if ( $plot_number ) {
            $seen_plot_numbers{$plot_number}++;
        }

        # Map to check for duplicated plot names
        if ( $plot_name ) {
            $seen_plot_names{$plot_name}++;
        }

        # Map to check for overlapping plots
        if ( $row_number && $col_number ) {
            my $pk = "$row_number-$col_number";
            if ( !exists $seen_plot_positions{$pk} ) {
                $seen_plot_positions{$pk} = [$plot_number];
            }
            else {
                push @{$seen_plot_positions{$pk}}, $plot_number;
            }
        }

        # Map to check the entry number <-> accession associations
        # For each trial: each entry number should only be associated with one accession
        # and each accession should only be associated with one entry number
        if ( $entry_number ) {
            if ( !exists $seen_entry_numbers{'by_num'}->{$entry_number} ) {
                $seen_entry_numbers{'by_num'}->{$entry_number} = [$stock_name];
            }
            else {
                push @{$seen_entry_numbers{'by_num'}->{$entry_number}}, $stock_name;
            }

            if ( !exists $seen_entry_numbers{'by_acc'}->{$stock_name} ) {
                $seen_entry_numbers{'by_acc'}->{$stock_name} = [$entry_number];
            }
            else {
                push @{$seen_entry_numbers{'by_acc'}->{$stock_name}}, $entry_number;
            }
        }
    }


    ##
    ## OVERALL VALIDATION
    ## These are checks on the unique values of different columns
    ##

    # Trial Name: cannot already exist in the database, cannot contain spaces, should not contain slashes
    my @already_used_trial_names;
    my @missing_trial_names = @{$validator->validate($schema,'trials',[$trial_name])->{'missing'}};
    my %unused_trial_names = map { $missing_trial_names[$_] => $_ } 0..$#missing_trial_names;
    foreach (($trial_name)) {
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

    # Stock Names: must exist in the database
    my @entry_names = @{$parsed_values->{'stock_name'}};
    my @intercrop_names = $parsed_values->{'intercrop_stock_name'} ? @{$parsed_values->{'intercrop_stock_name'}} : ();
    my @merged_names = uniq(@entry_names, @intercrop_names);
    my $entry_name_validator = CXGN::List::Validate->new();
    my @entry_names_missing = @{$entry_name_validator->validate($schema,'accessions_or_crosses_or_familynames',\@merged_names)->{'missing'}};
    if (scalar(@entry_names_missing) > 0) {
        $errors{'missing_stocks'} = \@entry_names_missing;
        push @error_messages, "The following entry names are not in the database as uniquenames or synonyms: ".join(',',@entry_names_missing);
    }

    # Seedlots: names must exist in the database
    my @seedlots_missing = @{$validator->validate($schema,'seedlots',$parsed_values->{'seedlot_name'})->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "Seedlot(s) <strong>".join(',',@seedlots_missing)."</strong> are not in the database.  To use a seedlot as a seed source for a plot, the seedlot must already exist in the database.";
    }

    # Verify seedlot pairs: accession name of plot must match seedlot contents
    if ( scalar(@seedlot_pairs) > 0 ) {
        my $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, \@seedlot_pairs);
        if (exists($return->{error})){
            push @error_messages, $return->{error};
        }
    }

    # Plot Names: must not exist in the database (as any stock)
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

    # Check for duplicated plot numbers
    foreach my $pk (keys %seen_plot_numbers) {
        my $count = $seen_plot_numbers{$pk};
        if ( $count > 1 ) {
            push @error_messages, "Plot number <strong>$pk</strong> is used $count times.  Each plot should have a unique plot number.";
        }
    }

    # Check for duplicated plot names
    foreach my $pk (keys %seen_plot_names) {
        my $count = $seen_plot_names{$pk};
        if ( $count > 1 ) {
            push @error_messages, "Plot name <strong>$pk</strong> is used $count times. Each plot should have a unique plot name.";
        }
    }

    # Check for overlapping plot positions (more than one plot assigned the same row/col positions)
    foreach my $pk (keys %seen_plot_positions) {
        my $plots = $seen_plot_positions{$pk};
        my $count = scalar(@$plots);
        if ( $count > 1 ) {
            my @pos = split('-', $pk);
            push @warning_messages, "More than 1 plot is assigned to the position row=" . $pos[0] . " col=" . $pos[1] . " plots=" . join(',', @$plots);
        }
    }

    # Check for entry number errors:
    # the same accession assigned different entry numbers
    # the same entry number assigned to different accessions

    # check assignments by accessions
    foreach my $an (keys %{$seen_entry_numbers{'by_acc'}} ) {
        my @ens = uniq @{$seen_entry_numbers{'by_acc'}{$an}};
        my $count = scalar(@ens);
        if ( scalar(@ens) > 1 ) {
            push @error_messages, "Entry Number mismatch: Accession <strong>$an</strong> has multiple entry numbers (" . join(', ', @ens) . ") assigned to it.";
        }
    }

    # check assigments by entry number
    foreach my $en (keys %{$seen_entry_numbers{'by_num'}} ) {
        my @ans = uniq @{$seen_entry_numbers{'by_num'}{$en}};
        my $count = scalar(@ans);
        if ( scalar(@ans) > 1 ) {
            push @error_messages, "Entry Number mismatch: Entry number <strong>$en</strong> has multiple accessions (" . join(', ', @ans) . ") assigned to it.";
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
    my $trial_name = $self->get_trial_name();
    my $parsed = $self->_get_validated_data();
    my $data = $parsed->{'data'};
    my $values = $parsed->{'values'};
    my $treatments = $parsed->{'additional_columns'};

    # Get synonyms for accessions in data
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my @accessions = @{$values->{'stock_name'}};
    my @intercrop_accessions = $values->{'intercrop_stock_name'} ? @{$values->{'intercrop_stock_name'}} : ();
    my @merged_accessions = uniq(@accessions, @intercrop_accessions);
    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => \@merged_accessions },
        'me.type_id' => $accession_cvterm_id,
        'stockprops.type_id' => $synonym_cvterm_id
    },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});

    # Create lookup hash for synonym -> uniquename -> stock id
    my %stock_synonyms_lookup;
    while (my $r=$acc_synonym_rs->next){
        $stock_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
    }

    # Build trial design
    my %design;
    my %seen_entry_numbers;
    my $treatment_design;
    foreach (@$data) {
        my $r = $_;
        my $row = $r->{'_row'};
        my $stock_name = $r->{'stock_name'};
        my $intercrop_stock_name = $r->{'intercrop_stock_name'};
        my $plot_number = $r->{'plot_number'};
        my $block_number = $r->{'block_number'};
        my $plot_name = $r->{'plot_name'} || _create_plot_name($trial_name, $plot_number);
        my $trial_type = $r->{'trial_type'};
        my $plot_width = $r->{'plot_width'};
        my $plot_length = $r->{'plot_length'};
        my $field_size = $r->{'field_size'};
        my $is_a_control = $r->{'is_a_control'};
        my $rep_number = $r->{'rep_number'};
        my $range_number = $r->{'range_number'};
        my $row_number = $r->{'row_number'};
        my $col_number = $r->{'col_number'};
        my $seedlot_name = $r->{'seedlot_name'};
        my $num_seed_per_plot = $r->{'num_seed_per_plot'} || 0;
        my $weight_gram_seed_per_plot = $r->{'weight_gram_seed_per_plot'} || 0;
        my $entry_number = $r->{'entry_number'};

        if ($stock_synonyms_lookup{$stock_name}) {
            my @stock_names = keys %{$stock_synonyms_lookup{$stock_name}};
            if (scalar(@stock_names)>1) {
                print STDERR "There is more than one uniquename for this synonym $stock_name. this should not happen!\n";
            }
            $stock_name = $stock_names[0];
        }
        my @checked_intercrop_names;
        foreach my $intercrop_name (@$intercrop_stock_name) {
            if ($stock_synonyms_lookup{$intercrop_name}) {
                my @accession_names = keys %{$stock_synonyms_lookup{$intercrop_name}};
                if (scalar(@accession_names)>1) {
                    print STDERR "There is more than one uniquename for this synonym $intercrop_name. this should not happen!\n";
                }
                $intercrop_name = $accession_names[0];
            }
            push @checked_intercrop_names, $intercrop_name;
        }

        if ($entry_number) {
            $seen_entry_numbers{$stock_name} = $entry_number;
        }

        $design{$row}->{plot_name} = $plot_name;
        $design{$row}->{stock_name} = $stock_name;
        $design{$row}->{intercrop_stock_name} = \@checked_intercrop_names;
        $design{$row}->{plot_number} = $plot_number;
        $design{$row}->{block_number} = $block_number;
        if ($is_a_control) {
            $design{$row}->{is_a_control} = 1;
        } else {
            $design{$row}->{is_a_control} = 0;
        }
        if ($rep_number) {
            $design{$row}->{rep_number} = $rep_number;
        }
        if ($range_number) {
            $design{$row}->{range_number} = $range_number;
        }
        if ($row_number) {
            $design{$row}->{row_number} = $row_number;
        }
        if ($col_number) {
            $design{$row}->{col_number} = $col_number;
        }
        if ($seedlot_name){
            $design{$row}->{seedlot_name} = $seedlot_name;
            $design{$row}->{num_seed_per_plot} = $num_seed_per_plot;
            $design{$row}->{weight_gram_seed_per_plot} = $weight_gram_seed_per_plot;
        }
        foreach my $treatment (@{$treatments}) {
            if (defined($r->{$treatment})) {
                $treatment_design->{$plot_name}->{$treatment} = $r->{$treatment};
            }
        }
    }

    my %parsed_data = (
        design => \%design,
        entry_numbers => \%seen_entry_numbers,
        treatment_design => $treatment_design
    );

    $self->_set_parsed_data(\%parsed_data);

    return 1;
}

sub _create_plot_name {
  my $trial_name = shift;
  my $plot_number = shift;
  return $trial_name . "-PLOT_" . $plot_number;
}

1;
