package CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignGeneric;

use Moose::Role;
use SGN::I18N ();
use HTML::Entities ();
use List::MoreUtils qw(uniq);
use JSON;
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::List::Transform;
use CXGN::Stock::Seedlot;
use CXGN::Calendar;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::BreedersToolbox::Projects;

my @REQUIRED_COLUMNS = qw|trial_name breeding_program location year design_type description accession_name plot_number block_number|;
my @OPTIONAL_COLUMNS = qw|intercrop_accession_name plot_name trial_type trial_stock_type plot_width plot_length field_size planting_date transplanting_date harvest_date is_a_control rep_number range_number row_number col_number seedlot_name num_seed_per_plot weight_gram_seed_per_plot entry_number plot_name_template|;
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

sub _multiple_trial_generic_message {
    my ($text, $slots) = @_;
    $text = HTML::Entities::encode_entities($text);
    my %encoded_slots = map { HTML::Entities::encode_entities($_) => $slots->{$_} } keys %{$slots || {}};
    if (%encoded_slots) {
        my $pattern = join '|', map { quotemeta($_) } sort { length($b) <=> length($a) } keys %encoded_slots;
        $text =~ s/($pattern)/$encoded_slots{$1}/ge;
    }
    return $text;
}

sub _validate_with_plugin {
    my $self = shift;
    my SGN::I18N $multi_generic_validate_i18n = $self->i18n;
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
        column_arrays => [ 'intercrop_accession_name' ],
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
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.treatment_column_format', "Column %{column} is not formatted like a treatment. Use only full, valid treatment names.\n", { column => '__SGN_TREATMENT_COLUMN__' })
                    : "Column __SGN_TREATMENT_COLUMN__ is not formatted like a treatment. Use only full, valid treatment names.\n",
                { '__SGN_TREATMENT_COLUMN__' => $treatment }
            );
        }
    }

    if (@{$validate->{missing}}>0) {
        foreach my $missing (@{$validate->{missing}}) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.treatment_missing', "Treatment %{treatment} does not exist in the database.\n", { treatment => '__SGN_TREATMENT__' })
                    : "Treatment __SGN_TREATMENT__ does not exist in the database.\n",
                { '__SGN_TREATMENT__' => $missing }
            );
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
    my %seedlot_trial_stock_type;  # check for seedlot and accession/cross/family compatibility :based on trial stock type


    my %trial_breeding_program;
    my %trial_has_plot_name;
    my %trial_plot_name_template_values;
    my %trial_plot_name_template_missing;

    foreach (@$parsed_data) {
        my $data = $_;
        my $tk = $data->{'trial_name'};
        next unless $tk;
        $trial_breeding_program{$tk} ||= $data->{'breeding_program'};
        if ( defined($data->{'plot_name'}) && $data->{'plot_name'} ne '' ) {
            $trial_has_plot_name{$tk} = 1;
        }
        if ( defined($data->{'plot_name_template'}) && $data->{'plot_name_template'} ne '' ) {
            push @{$trial_plot_name_template_values{$tk}}, $data->{'plot_name_template'};
        }
        else {
            $trial_plot_name_template_missing{$tk}++;
        }
    }

    my %resolved_plot_name_templates;
    foreach my $tk (keys %trial_plot_name_template_values) {
        my @values = uniq @{$trial_plot_name_template_values{$tk}};

        if ( $trial_plot_name_template_missing{$tk} ) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.template_required_all_rows', 'Trial %{trial}: %{template_key} must be provided on every row of a trial if it is used for any row of that trial.', { trial => '__SGN_TRIAL__', template_key => '__SGN_TEMPLATE_KEY__' })
                    : 'Trial __SGN_TRIAL__: __SGN_TEMPLATE_KEY__ must be provided on every row of a trial if it is used for any row of that trial.',
                { '__SGN_TRIAL__' => '<strong>'.$tk.'</strong>', '__SGN_TEMPLATE_KEY__' => 'plot_name_template' }
            );
            next;
        }
        if ( scalar(@values) > 1 ) {
            my $different_template_values = join(', ', @values);
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.template_must_match', 'Trial %{trial}: %{template_key} must be the same value on every row of a trial. Found %{values}.', { trial => '__SGN_TRIAL__', template_key => '__SGN_TEMPLATE_KEY__', values => '__SGN_TEMPLATE_VALUES__' })
                    : 'Trial __SGN_TRIAL__: __SGN_TEMPLATE_KEY__ must be the same value on every row of a trial. Found __SGN_TEMPLATE_VALUES__.',
                { '__SGN_TRIAL__' => '<strong>'.$tk.'</strong>', '__SGN_TEMPLATE_KEY__' => 'plot_name_template', '__SGN_TEMPLATE_VALUES__' => '<strong>'.$different_template_values.'</strong>' }
            );
            next;
        }

        my $template_name = $values[0];
        my $bp_name = $trial_breeding_program{$tk};
        my $bp_row = $bp_name ? $schema->resultset('Project::Project')->find({ name => $bp_name }) : undef;

        # If the breeding program itself is invalid, that is reported separately below; skip template checks.
        next unless $bp_row;

        my $projects = CXGN::BreedersToolbox::Projects->new({ schema => $schema });
        my $available_templates = $projects->get_autogenerated_name_metadata_by_breeding_program($bp_row->project_id(), 'plot');
        my %available_template_lookup;
        foreach my $entry (@$available_templates) {
            foreach my $fmt (keys %$entry) {
                $available_template_lookup{$fmt} = $entry;
            }
        }

        if ( !exists $available_template_lookup{$template_name} ) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.template_wrong_program', 'Trial %{trial}: %{template_key} %{template_name} does not belong to breeding program %{program}.', { trial => '__SGN_TRIAL__', template_key => '__SGN_TEMPLATE_KEY__', template_name => '__SGN_TEMPLATE__', program => '__SGN_PROGRAM__' })
                    : 'Trial __SGN_TRIAL__: __SGN_TEMPLATE_KEY__ __SGN_TEMPLATE__ does not belong to breeding program __SGN_PROGRAM__.',
                { '__SGN_TRIAL__' => '<strong>'.$tk.'</strong>', '__SGN_TEMPLATE_KEY__' => 'plot_name_template', '__SGN_TEMPLATE__' => '<strong>'.$template_name.'</strong>', '__SGN_PROGRAM__' => '<strong>'.$bp_name.'</strong>' }
            );
            next;
        }

        # Only used for plot name generation (and only passed to TrialCreate) when plot_name is not supplied for this trial.
        if ( !$trial_has_plot_name{$tk} ) {
            $resolved_plot_name_templates{$tk} = encode_json($available_template_lookup{$template_name});
        }
    }
    $self->_set_plot_name_template_map(\%resolved_plot_name_templates);

    ##
    ## ROW BY ROW VALIDATION
    ## These are checks on the individual plot-level data
    ##

    my $trial_stock_type;

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
        my $intercrop_accession_name = $data->{'intercrop_accession_name'};
        my $plot_number = $data->{'plot_number'};
        my $block_number = $data->{'block_number'};
        my $is_a_control = $data->{'is_a_control'};
        my $rep_number = $data->{'rep_number'};
        my $range_number = $data->{'range_number'};
        my $row_number = $data->{'row_number'};
        my $col_number = $data->{'col_number'};
        my $plot_name = $data->{'plot_name'} || _generate_plot_name($resolved_plot_name_templates{$trial_name}, {
            breedingProgram => $breeding_program,
            trialName       => $trial_name,
            accessionName   => $accession_name,
            plotNumber      => $plot_number,
            blockNumber     => $block_number,
            rangeNumber     => $range_number,
            repNumber       => $rep_number,
            rowNumber       => $row_number,
            colNumber       => $col_number,
        }) || _create_plot_name($trial_name, $plot_number);
        my $trial_type = $data->{'trial_type'};
        my $plot_width = $data->{'plot_width'};
        my $plot_length = $data->{'plot_length'};
        my $field_size = $data->{'field_size'};
        my $planting_date = $data->{'planting_date'};
        my $transplanting_date = $data->{'transplanting_date'};
        my $harvest_date = $data->{'harvest_date'};
        my $seedlot_name = $data->{'seedlot_name'};
        my $num_seed_per_plot = $data->{'num_seed_per_plot'};
        my $weight_gram_seed_per_plot = $data->{'weight_gram_seed_per_plot'};
        my $entry_number = $data->{'entry_number'};
        $trial_stock_type = $data->{'trial_stock_type'};

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
                push @error_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.treatment_value_below_minimum', 'Row %{row}: value for %{treatment} is lower than the allowed minimum for that treatment.', { row => '__SGN_ROW__', treatment => '__SGN_TREATMENT__' })
                        : 'Row __SGN_ROW__: value for __SGN_TREATMENT__ is lower than the allowed minimum for that treatment.',
                    { '__SGN_ROW__' => $row, '__SGN_TREATMENT__' => $treatment }
                );
            }
            if ($treatment_obj->format() eq "numeric" && defined($treatment_obj->maximum()) && defined($data->{$treatment}) && $data->{$treatment} > $treatment_obj->maximum()) {
                push @error_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.treatment_value_above_maximum', 'Row %{row}: value for %{treatment} is higher than the allowed maximum for that treatment.', { row => '__SGN_ROW__', treatment => '__SGN_TREATMENT__' })
                        : 'Row __SGN_ROW__: value for __SGN_TREATMENT__ is higher than the allowed maximum for that treatment.',
                    { '__SGN_ROW__' => $row, '__SGN_TREATMENT__' => $treatment }
                );
            }
            if ($treatment_obj->format() eq "qualitative" && defined($treatment_obj->categories()) && defined($data->{$treatment})) {
                my $qual_value = $data->{$treatment};
                my $categories = $treatment_obj->categories();
                if ( $categories !~ m/$qual_value/) {
                    push @error_messages, _multiple_trial_generic_message(
                        $multi_generic_validate_i18n
                            ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.treatment_value_category', 'Row %{row}: value for %{treatment} is not in the valid categories for that treatment.', { row => '__SGN_ROW__', treatment => '__SGN_TREATMENT__' })
                            : 'Row __SGN_ROW__: value for __SGN_TREATMENT__ is not in the valid categories for that treatment.',
                        { '__SGN_ROW__' => $row, '__SGN_TREATMENT__' => $treatment }
                    );
                }
            }
        }

        # Plot Number: must be a positive number
        if (!($plot_number =~ /^\d+?$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot number', '__SGN_VALUE__' => '<strong>'.$plot_number.'</strong>' }
            );
        }

        # Block Number: must be a positive integer
        if (!($block_number =~ /^\d+?$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'block number', '__SGN_VALUE__' => '<strong>'.$block_number.'</strong>' }
            );
        }

        # Rep Number: must be a positive integer, if provided
        if ($rep_number && !($rep_number =~ /^\d+?$/)){
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'rep_number', '__SGN_VALUE__' => '<strong>'.$rep_number.'</strong>' }
            );
        }

        # Plot Name: cannot contain spaces, should not contain slashes
        if ($plot_name =~ /\s/ ) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.no_spaces_row', 'Row %{row}: %{field} %{value} must not contain spaces.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must not contain spaces.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot name', '__SGN_VALUE__' => '<strong>'.$plot_name.'</strong>' }
            );
        }
        if ($plot_name =~ /\// || $plot_name =~ /\\/) {
            push @warning_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.plot_name_slashes_warning', 'Row %{row}: %{field} %{value} contains slashes. Note that slashes can cause problems for third-party applications; however, plot names can be saved with slashes if you ignore warnings.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ contains slashes. Note that slashes can cause problems for third-party applications; however, plot names can be saved with slashes if you ignore warnings.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot name', '__SGN_VALUE__' => '<strong>'.$plot_name.'</strong>' }
            );
        }

        # Plot Width / Plot Length / Field Size: must be a positive number, if provided
        if ($plot_width && !($plot_width =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_number', 'Row %{row}: %{field} %{value} must be a positive number.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive number.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot_width', '__SGN_VALUE__' => '<strong>'.$plot_width.'</strong>' }
            );
        }
        if ($plot_length && !($plot_length =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_number', 'Row %{row}: %{field} %{value} must be a positive number.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive number.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot_length', '__SGN_VALUE__' => '<strong>'.$plot_length.'</strong>' }
            );
        }
        if ($field_size && !($field_size =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_number', 'Row %{row}: %{field} %{value} must be a positive number.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive number.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot_width', '__SGN_VALUE__' => '<strong>'.$field_size.'</strong>' }
            );
        }

        # Transplanting / Planting / Harvest Dates: must be YYYY-MM-DD format, if provided
        if ($transplanting_date && !$calendar_funcs->check_value_format($transplanting_date)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.date_format', 'Row %{row}: %{field} %{value} must be in the format %{date_format}.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__', date_format => '__SGN_DATE_FORMAT__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be in the format __SGN_DATE_FORMAT__.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'transplanting_date', '__SGN_VALUE__' => '<strong>'.$transplanting_date.'</strong>', '__SGN_DATE_FORMAT__' => 'YYYY-MM-DD' }
            );
        }
        if ($planting_date && !$calendar_funcs->check_value_format($planting_date)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.date_format', 'Row %{row}: %{field} %{value} must be in the format %{date_format}.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__', date_format => '__SGN_DATE_FORMAT__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be in the format __SGN_DATE_FORMAT__.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'planting_date', '__SGN_VALUE__' => '<strong>'.$planting_date.'</strong>', '__SGN_DATE_FORMAT__' => 'YYYY-MM-DD' }
            );
        }
        if ($harvest_date && !$calendar_funcs->check_value_format($harvest_date)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.date_format', 'Row %{row}: %{field} %{value} must be in the format %{date_format}.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__', date_format => '__SGN_DATE_FORMAT__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be in the format __SGN_DATE_FORMAT__.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'harvest_date', '__SGN_VALUE__' => '<strong>'.$harvest_date.'</strong>', '__SGN_DATE_FORMAT__' => 'YYYY-MM-DD' }
            );
        }

        # Is A Control: must be blank, 0, or 1, if provided
        if ( $is_a_control && $is_a_control ne '' && $is_a_control ne '0' && $is_a_control ne '1' ) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.control_value_invalid', 'Row %{row}: %{field} value of %{value} is invalid.  It must be %{blank} (not a control), %{zero} (not a control), or %{one} (is a control).', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__', blank => '__SGN_BLANK__', zero => '__SGN_ZERO__', one => '__SGN_ONE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ value of __SGN_VALUE__ is invalid.  It must be __SGN_BLANK__ (not a control), __SGN_ZERO__ (not a control), or __SGN_ONE__ (is a control).',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'is_a_control', '__SGN_VALUE__' => '<strong>'.$is_a_control.'</strong>', '__SGN_BLANK__' => 'blank', '__SGN_ZERO__' => '0', '__SGN_ONE__' => '1' }
            );
        }

        # Range Number / Row Number / Col Number: must be a positive integer, if provided
        if ($range_number && !($range_number =~ /^\d+?$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'range_number', '__SGN_VALUE__' => '<strong>'.$range_number.'</strong>' }
            );
        }
        if ($row_number && !($row_number =~ /^\d+?$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'row_number', '__SGN_VALUE__' => '<strong>'.$row_number.'</strong>' }
            );
        }
        if ($col_number && !($col_number =~ /^\d+?$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'col_number', '__SGN_VALUE__' => '<strong>'.$col_number.'</strong>' }
            );
        }

        # Seedlots: add seedlot_name / accession_name to seedlot_pairs
        # count and weight must be a positive integer
        # return a warning if both count and weight are not provided
        if ( $seedlot_name ) {
            if ($trial_stock_type eq 'family_name') {
                push @{$seedlot_trial_stock_type{'family_name'}}, [$seedlot_name, $accession_name];
            } else {
                push @{$seedlot_trial_stock_type{'accession_cross'}}, [$seedlot_name, $accession_name];
            }
            if ( $num_seed_per_plot && $num_seed_per_plot ne '' && !($num_seed_per_plot =~ /^\d+?$/) ) {
                push @error_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                        : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                    { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'num_seed_per_plot', '__SGN_VALUE__' => '<strong>'.$num_seed_per_plot.'</strong>' }
                );
            }
            if ( $weight_gram_seed_per_plot && $weight_gram_seed_per_plot ne '' && !($weight_gram_seed_per_plot =~ /^\d+?$/) ) {
                push @error_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                        : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                    { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'weight_gram_seed_per_plot', '__SGN_VALUE__' => '<strong>'.$weight_gram_seed_per_plot.'</strong>' }
                );
            }
            if ( !$num_seed_per_plot && !$weight_gram_seed_per_plot ) {
                push @warning_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.seedlot_no_seed_quantity', 'Row %{row}: this plot does not have a count or weight of seed to be used from seedlot %{seedlot}.', { row => '__SGN_ROW__', seedlot => '__SGN_SEEDLOT__' })
                        : 'Row __SGN_ROW__: this plot does not have a count or weight of seed to be used from seedlot __SGN_SEEDLOT__.',
                    { '__SGN_ROW__' => $row, '__SGN_SEEDLOT__' => '<strong>'.$seedlot_name.'</strong>' }
                );
            }
        }

        # Entry Number: must be a positive integer, if provided
        if ($entry_number && !($entry_number =~ /^\d+?$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'entry_number', '__SGN_VALUE__' => '<strong>'.$entry_number.'</strong>' }
            );
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
    my %existing_trial_names = map { $_->name => 1 }
        $schema->resultset('Project::Project')->search({ name => { -in => $parsed_values->{'trial_name'} } })->all;
    foreach (@{$parsed_values->{'trial_name'}}) {
        push(@already_used_trial_names, $_) if exists $existing_trial_names{$_};
        if ($_ =~ /\s/) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.no_spaces', '%{field} %{value} must not contain spaces.', { field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : '__SGN_FIELD__ __SGN_VALUE__ must not contain spaces.',
                { '__SGN_FIELD__' => 'trial_name', '__SGN_VALUE__' => '<strong>'.$_.'</strong>' }
            );
        }
        if ($_ =~ /\// || $_ =~ /\\/) {
            push @warning_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.slashes_warning', '%{field} %{value} contains slashes. Note that slashes can cause problems for third-party applications; however, trial names can be saved with slashes if you ignore warnings.', { field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : '__SGN_FIELD__ __SGN_VALUE__ contains slashes. Note that slashes can cause problems for third-party applications; however, trial names can be saved with slashes if you ignore warnings.',
                { '__SGN_FIELD__' => 'trial_name', '__SGN_VALUE__' => '<strong>'.$_.'</strong>' }
            );
        }
    }
    if (scalar(@already_used_trial_names) > 0) {
        my $used_trial_names = join(', ', @already_used_trial_names);
        push @error_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.trial_names_already_used', 'Trial name(s) %{names} are invalid because they are already used in the database.', { names => '__SGN_TRIAL_NAMES__' })
                : 'Trial name(s) __SGN_TRIAL_NAMES__ are invalid because they are already used in the database.',
            { '__SGN_TRIAL_NAMES__' => '<strong>'.$used_trial_names.'</strong>' }
        );
    }

    # Breeding Program: must already exist in the database
    my $breeding_programs_missing = $validator->validate($schema,'breeding_programs',$parsed_values->{'breeding_program'})->{'missing'};
    my @breeding_programs_missing = @{$breeding_programs_missing};
    if (scalar(@breeding_programs_missing) > 0) {
        my $missing_programs = join(',', @breeding_programs_missing);
        push @error_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.programs_missing', 'Breeding program(s) %{programs} are not in the database.', { programs => '__SGN_PROGRAMS__' })
                : 'Breeding program(s) __SGN_PROGRAMS__ are not in the database.',
            { '__SGN_PROGRAMS__' => '<strong>'.$missing_programs.'</strong>' }
        );
    }

    # Location: Transform location abbreviations/codes to full names
    my $locations_hashref = $validator->validate($schema,'locations',$parsed_values->{'location'});
    my @codes = @{$locations_hashref->{'codes'}};
    my %location_code_map;
    foreach my $code (@codes) {
        my $location_code = $code->[0];
        my $found_location_name = $code->[1];
        $location_code_map{$location_code} = $found_location_name;
        push @warning_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.location_code_match', 'File location %{code} matches the code for the location named %{location} and will be substituted if you ignore warnings.', { code => '__SGN_LOCATION_CODE__', location => '__SGN_LOCATION__' })
                : 'File location __SGN_LOCATION_CODE__ matches the code for the location named __SGN_LOCATION__ and will be substituted if you ignore warnings.',
            { '__SGN_LOCATION_CODE__' => '<strong>'.$location_code.'</strong>', '__SGN_LOCATION__' => '<strong>'.$found_location_name.'</strong>' }
        );
    }
    $self->_set_location_code_map(\%location_code_map);

    # Location: must already exist in the database
    my @locations_missing = @{$locations_hashref->{'missing'}};
    my @locations_missing_no_codes = grep { !exists $location_code_map{$_} } @locations_missing;
    if (scalar(@locations_missing_no_codes) > 0) {
        my $missing_locations = join(',', @locations_missing_no_codes);
        push @error_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.locations_missing', 'Location(s) %{locations} are not in the database.', { locations => '__SGN_LOCATIONS__' })
                : 'Location(s) __SGN_LOCATIONS__ are not in the database.',
            { '__SGN_LOCATIONS__' => '<strong>'.$missing_locations.'</strong>' }
        );
    }

    # Year: must be a 4 digit integer
    foreach (@{$parsed_values->{'year'}}) {
        if (!($_ =~ /^\d{4}$/)) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.invalid_year', '%{field} %{year} is not a valid year, must be a %{digits} digit positive integer.', { field => '__SGN_FIELD__', year => '__SGN_YEAR__', digits => '__SGN_DIGITS__' })
                    : '__SGN_FIELD__ __SGN_YEAR__ is not a valid year, must be a __SGN_DIGITS__ digit positive integer.',
                { '__SGN_FIELD__' => 'year', '__SGN_YEAR__' => '<strong>'.$_.'</strong>', '__SGN_DIGITS__' => '4' }
            );
        }
    }

    # Design Type: must be a valid / supported design type
    foreach (@{$parsed_values->{'design_type'}}) {
        if ( !exists $valid_design_types{$_} ) {
            my $supported_design_types = join(', ', keys(%valid_design_types));
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.unsupported_design_type', '%{field} %{value} is not supported. Supported design types: %{supported_types}.', { field => '__SGN_FIELD__', value => '__SGN_VALUE__', supported_types => '__SGN_SUPPORTED_TYPES__' })
                    : '__SGN_FIELD__ __SGN_VALUE__ is not supported. Supported design types: __SGN_SUPPORTED_TYPES__.',
                { '__SGN_FIELD__' => 'design_type', '__SGN_VALUE__' => '<strong>'.$_.'</strong>', '__SGN_SUPPORTED_TYPES__' => $supported_design_types }
            );
        }
    }

    # Trial Type: must be a valid / supported trial type
    foreach (@{$parsed_values->{'trial_type'}}) {
        if ( !exists $valid_trial_types{$_} ) {
            my $supported_trial_types = join(', ', keys(%valid_trial_types));
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.unsupported_trial_type', '%{field} %{value} is not supported. Supported trial types: %{supported_types}.', { field => '__SGN_FIELD__', value => '__SGN_VALUE__', supported_types => '__SGN_SUPPORTED_TYPES__' })
                    : '__SGN_FIELD__ __SGN_VALUE__ is not supported. Supported trial types: __SGN_SUPPORTED_TYPES__.',
                { '__SGN_FIELD__' => 'trial_type', '__SGN_VALUE__' => '<strong>'.$_.'</strong>', '__SGN_SUPPORTED_TYPES__' => $supported_trial_types }
            );
        }
    }

    # Trial Stock Type: must be a valid / supported trial stock type
    foreach (@{$parsed_values->{'trial_stock_type'}}) {
        if ( !exists $valid_stock_types{$_} ) {
            my $supported_stock_types = join(', ', keys(%valid_stock_types));
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.unsupported_stock_type', '%{field} %{value} is not supported. Supported trial stock types: %{supported_types}.', { field => '__SGN_FIELD__', value => '__SGN_VALUE__', supported_types => '__SGN_SUPPORTED_TYPES__' })
                    : '__SGN_FIELD__ __SGN_VALUE__ is not supported. Supported trial stock types: __SGN_SUPPORTED_TYPES__.',
                { '__SGN_FIELD__' => 'trial_stock_type', '__SGN_VALUE__' => '<strong>'.$_.'</strong>', '__SGN_SUPPORTED_TYPES__' => $supported_stock_types }
            );
        }
    }

    # Accession Names: must exist in the database
    my @stock_names = @{$parsed_values->{'accession_name'}};
    my @intercrop_accessions = $parsed_values->{'intercrop_accession_name'} ? @{$parsed_values->{'intercrop_accession_name'}} : ();
    my @merged_stock_names = uniq(@stock_names, @intercrop_accessions);
    my $accessions_hashref = $validator->validate($schema,'accessions',\@merged_stock_names);
    my @multiple_synonyms = @{$accessions_hashref->{'multiple_synonyms'}};

    #find unique synonyms. Sometimes trial uploads use synonym names instead of the unique accession name. We allow this if the synonym is unique and matches one accession in the database
    my @synonyms = @{$accessions_hashref->{'synonyms'}};
    foreach my $synonym (@synonyms) {
        my $found_acc_name_from_synonym = $synonym->{'uniquename'};
        my $matched_synonym = $synonym->{'synonym'};

        push @warning_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.accession_synonym', 'File Accession %{file_accession} is a synonym of database accession %{database_accession} ', { file_accession => '__SGN_FILE_ACCESSION__', database_accession => '__SGN_DATABASE_ACCESSION__' })
                : 'File Accession __SGN_FILE_ACCESSION__ is a synonym of database accession __SGN_DATABASE_ACCESSION__ ',
            { '__SGN_FILE_ACCESSION__' => $matched_synonym, '__SGN_DATABASE_ACCESSION__' => $found_acc_name_from_synonym }
        );

        @merged_stock_names = grep !/\Q$matched_synonym/, @merged_stock_names;
        push @merged_stock_names, $found_acc_name_from_synonym;
    }

    #now validate again the accession names

    my @entry_names_missing = ();
    if ($trial_stock_type eq 'cross') {
        @entry_names_missing = @{$validator->validate($schema,'accessions_or_synonyms_or_crosses',\@merged_stock_names)->{'missing'}};
        if (scalar(@entry_names_missing) > 0) {
            my $missing_stock_names = join(',', @entry_names_missing);
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.stocks_wrong_type', 'Stocks(s) %{stocks} are not in the database or are not %{stock_type_one} or %{stock_type_two} stock type.', { stocks => '__SGN_STOCKS__', stock_type_one => '__SGN_STOCK_TYPE_ONE__', stock_type_two => '__SGN_STOCK_TYPE_TWO__' })
                    : 'Stocks(s) __SGN_STOCKS__ are not in the database or are not __SGN_STOCK_TYPE_ONE__ or __SGN_STOCK_TYPE_TWO__ stock type.',
                { '__SGN_STOCKS__' => '<strong>'.$missing_stock_names.'</strong>', '__SGN_STOCK_TYPE_ONE__' => 'accession', '__SGN_STOCK_TYPE_TWO__' => 'cross' }
            );
        }
    } elsif ($trial_stock_type eq 'family_name') {
        @entry_names_missing = @{$validator->validate($schema,'accessions_or_family_names',\@merged_stock_names)->{'missing'}};
        if (scalar(@entry_names_missing) > 0) {
            my $missing_stock_names = join(',', @entry_names_missing);
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.stocks_wrong_type', 'Stocks(s) %{stocks} are not in the database or are not %{stock_type_one} or %{stock_type_two} stock type.', { stocks => '__SGN_STOCKS__', stock_type_one => '__SGN_STOCK_TYPE_ONE__', stock_type_two => '__SGN_STOCK_TYPE_TWO__' })
                    : 'Stocks(s) __SGN_STOCKS__ are not in the database or are not __SGN_STOCK_TYPE_ONE__ or __SGN_STOCK_TYPE_TWO__ stock type.',
                { '__SGN_STOCKS__' => '<strong>'.$missing_stock_names.'</strong>', '__SGN_STOCK_TYPE_ONE__' => 'accession', '__SGN_STOCK_TYPE_TWO__' => 'family name' }
            );
        }
    } else {
        @entry_names_missing = @{$validator->validate($schema,'accessions',\@merged_stock_names)->{'missing'}};
        if (scalar(@entry_names_missing) > 0) {
            my $missing_stock_names = join(',', @entry_names_missing);
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.stocks_missing', 'Stocks(s) %{stocks} are not in the database as %{name_type} or synonyms of %{stock_type} stock type.', { stocks => '__SGN_STOCKS__', name_type => '__SGN_NAME_TYPE__', stock_type => '__SGN_STOCK_TYPE__' })
                    : 'Stocks(s) __SGN_STOCKS__ are not in the database as __SGN_NAME_TYPE__ or synonyms of __SGN_STOCK_TYPE__ stock type.',
                { '__SGN_STOCKS__' => '<strong>'.$missing_stock_names.'</strong>', '__SGN_NAME_TYPE__' => 'uniquenames', '__SGN_STOCK_TYPE__' => 'accession' }
            );
        }
    }

    if (scalar(@multiple_synonyms) > 0) {
        my @msgs;
        foreach my $m (@multiple_synonyms) {
            push(@msgs, 'Name: ' . @$m[0] . ' = Synonym: ' . @$m[1]);
        }
        my $multiple_synonym_details = join(',', @msgs);
        push @error_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.multiple_accession_synonyms', 'Accession(s) %{details} appear in the database as synonyms of more than one unique accession. Please change to the unique accession name or delete the multiple synonyms', { details => '__SGN_SYNONYM_DETAILS__' })
                : 'Accession(s) __SGN_SYNONYM_DETAILS__ appear in the database as synonyms of more than one unique accession. Please change to the unique accession name or delete the multiple synonyms',
            { '__SGN_SYNONYM_DETAILS__' => '<strong>'.$multiple_synonym_details.'</strong>' }
        );
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
        my $used_plot_names = join(', ', @already_used_plot_names);
        push @error_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.plot_names_already_used', 'Plot name(s) %{names} are invalid because they are already used in the database.', { names => '__SGN_PLOT_NAMES__' })
                : 'Plot name(s) __SGN_PLOT_NAMES__ are invalid because they are already used in the database.',
            { '__SGN_PLOT_NAMES__' => '<strong>'.$used_plot_names.'</strong>' }
        );
    }

    # Seedlots: names must exist in the database
    my @seedlots_missing = @{$validator->validate($schema,'seedlots',$parsed_values->{'seedlot_name'})->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        my $missing_seedlots = join(',', @seedlots_missing);
        push @error_messages, _multiple_trial_generic_message(
            $multi_generic_validate_i18n
                ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.seedlots_missing', 'Seedlot(s) %{seedlots} are not in the database.  To use a seedlot as a seed source for a plot, the seedlot must already exist in the database.', { seedlots => '__SGN_SEEDLOTS__' })
                : 'Seedlot(s) __SGN_SEEDLOTS__ are not in the database.  To use a seedlot as a seed source for a plot, the seedlot must already exist in the database.',
            { '__SGN_SEEDLOTS__' => '<strong>'.$missing_seedlots.'</strong>' }
        );
    }

    # Verify seedlot pairs: accession name of plot must match seedlot contents
    my @family_seedlot_pairs_array;
    my @accession_cross_seedlot_pairs_array;
    my $family_seedlot_pairs = $seedlot_trial_stock_type{'family_name'};
    if (defined $family_seedlot_pairs) {
        @family_seedlot_pairs_array = @$family_seedlot_pairs;
    }
    my $accession_cross_seedlot_pairs = $seedlot_trial_stock_type{'accession_cross'};
    if (defined $accession_cross_seedlot_pairs) {
        @accession_cross_seedlot_pairs_array = @$accession_cross_seedlot_pairs;
    }

    if ((scalar @entry_names_missing == 0) && (scalar @seedlots_missing == 0)) {
        my $return;
        if (scalar @family_seedlot_pairs_array > 0) {
            $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_family_names($schema, $family_seedlot_pairs);
            if (exists($return->{error})) {
                push @error_messages, $return->{error};
            }
        } elsif ( scalar @accession_cross_seedlot_pairs_array > 0 ) {
            $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, $accession_cross_seedlot_pairs);
            if (exists($return->{error})) {
                push @error_messages, $return->{error};
            }
        }
    }

    # Check for duplicated plot numbers
    foreach my $tk (keys %seen_plot_numbers) {
        foreach my $pk (keys %{$seen_plot_numbers{$tk}}) {
            my $count = $seen_plot_numbers{$tk}{$pk};
            if ( $count > 1 ) {
                push @error_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.plot_number_repeated', 'Plot number %{plot_number} in trial %{trial} is used %{count} times.  Each plot should have a unique plot number in an individual trial.', { plot_number => '__SGN_PLOT_NUMBER__', trial => '__SGN_TRIAL__', count => '__SGN_COUNT__' })
                        : 'Plot number __SGN_PLOT_NUMBER__ in trial __SGN_TRIAL__ is used __SGN_COUNT__ times.  Each plot should have a unique plot number in an individual trial.',
                    { '__SGN_PLOT_NUMBER__' => '<strong>'.$pk.'</strong>', '__SGN_TRIAL__' => '<strong>'.$tk.'</strong>', '__SGN_COUNT__' => $count }
                );
            }
        }
    }

    # Check for duplicated plot names
    foreach my $pk (keys %seen_plot_names) {
        my $count = $seen_plot_names{$pk};
        if ( $count > 1 ) {
            push @error_messages, _multiple_trial_generic_message(
                $multi_generic_validate_i18n
                    ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.plot_name_repeated', 'Plot name %{plot_name} is used %{count} times. Each plot should have a unique plot name across all trials.', { plot_name => '__SGN_PLOT_NAME__', count => '__SGN_COUNT__' })
                    : 'Plot name __SGN_PLOT_NAME__ is used __SGN_COUNT__ times. Each plot should have a unique plot name across all trials.',
                { '__SGN_PLOT_NAME__' => '<strong>'.$pk.'</strong>', '__SGN_COUNT__' => $count }
            );
        }
    }

    # Check for overlapping plot positions (more than one plot assigned the same row/col positions)
    foreach my $tk (keys %seen_plot_positions) {
        foreach my $pk (keys %{$seen_plot_positions{$tk}}) {
            my $plots = $seen_plot_positions{$tk}{$pk};
            my $count = scalar(@$plots);
            if ( $count > 1 ) {
                my @pos = split('-', $pk);
                my $position_details = "row=" . $pos[0] . " col=" . $pos[1] . " trial=" . $tk . " plots=" . join(',', @$plots);
                push @warning_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.overlapping_position', 'More than %{one} plot is assigned to the position %{position}', { one => '__SGN_ONE__', position => '__SGN_POSITION_DETAILS__' })
                        : 'More than __SGN_ONE__ plot is assigned to the position __SGN_POSITION_DETAILS__',
                    { '__SGN_ONE__' => '1', '__SGN_POSITION_DETAILS__' => $position_details }
                );
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
                my $assigned_entry_numbers = join(', ', @ens);
                push @error_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.entry_numbers_mismatch', '%{heading}: Accession %{accession} has multiple entry numbers (%{entry_numbers}) assigned to it in trial %{trial}.', { heading => '__SGN_ENTRY_HEADING__', accession => '__SGN_ACCESSION__', entry_numbers => '__SGN_ENTRY_NUMBERS__', trial => '__SGN_TRIAL__' })
                        : '__SGN_ENTRY_HEADING__: Accession __SGN_ACCESSION__ has multiple entry numbers (__SGN_ENTRY_NUMBERS__) assigned to it in trial __SGN_TRIAL__.',
                    { '__SGN_ENTRY_HEADING__' => 'Entry Number mismatch', '__SGN_ACCESSION__' => '<strong>'.$an.'</strong>', '__SGN_ENTRY_NUMBERS__' => $assigned_entry_numbers, '__SGN_TRIAL__' => '<strong>'.$tk.'</strong>' }
                );
            }
        }

        # check assigments by entry number
        foreach my $en (keys %{$seen_entry_numbers{$tk}{'by_num'}} ) {
            my @ans = uniq @{$seen_entry_numbers{$tk}{'by_num'}{$en}};
            my $count = scalar(@ans);
            if ( scalar(@ans) > 1 ) {
                my $assigned_accessions = join(', ', @ans);
                push @error_messages, _multiple_trial_generic_message(
                    $multi_generic_validate_i18n
                        ? $multi_generic_validate_i18n->p('trial.upload.multi.generic.entry_number_accessions_mismatch', '%{heading}: Entry number %{entry_number} has multiple accessions (%{accessions}) assigned to it in trial %{trial}.', { heading => '__SGN_ENTRY_HEADING__', entry_number => '__SGN_ENTRY_NUMBER__', accessions => '__SGN_ACCESSIONS__', trial => '__SGN_TRIAL__' })
                        : '__SGN_ENTRY_HEADING__: Entry number __SGN_ENTRY_NUMBER__ has multiple accessions (__SGN_ACCESSIONS__) assigned to it in trial __SGN_TRIAL__.',
                    { '__SGN_ENTRY_HEADING__' => 'Entry Number mismatch', '__SGN_ENTRY_NUMBER__' => '<strong>'.$en.'</strong>', '__SGN_ACCESSIONS__' => $assigned_accessions, '__SGN_TRIAL__' => '<strong>'.$tk.'</strong>' }
                );
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
    my @intercrop_accessions = $values->{'intercrop_accession_name'} ? @{$values->{'intercrop_accession_name'}} : ();
    my @merged_accessions = uniq(@accessions, @intercrop_accessions);
    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => \@merged_accessions },
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

    my $plot_name_template_map = $self->_has_plot_name_template_map() ? $self->_get_plot_name_template_map() : {};

    my %all_designs;
    my %single_design;
    my %design_details;
    my %seen_entry_numbers;
    my $trial_name = '';
    for my $row (@$data) {
        my $row_id = $row->{'_row'};
        my $current_trial_name = $row->{'trial_name'};
        my $accession_name = $row->{'accession_name'};
        my $intercrop_accession_name = $row->{'intercrop_accession_name'};
        my $plot_number = $row->{'plot_number'};
        my $block_number = $row->{'block_number'};
        my $is_a_control = $row->{'is_a_control'};
        my $rep_number = $row->{'rep_number'};
        my $range_number = $row->{'range_number'};
        my $row_number = $row->{'row_number'};
        my $col_number = $row->{'col_number'};
        my $plot_name = $row->{'plot_name'} || _generate_plot_name($plot_name_template_map->{$current_trial_name}, {
            breedingProgram => $row->{'breeding_program'},
            trialName       => $current_trial_name,
            accessionName   => $accession_name,
            plotNumber      => $plot_number,
            blockNumber     => $block_number,
            rangeNumber     => $range_number,
            repNumber       => $rep_number,
            rowNumber       => $row_number,
            colNumber       => $col_number,
        }) || _create_plot_name($current_trial_name, $plot_number);
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

            if ( exists $plot_name_template_map->{$current_trial_name} ) {
                $single_design{'plot_name_template'} = $plot_name_template_map->{$current_trial_name};
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
        my @checked_intercrop_accession_names;
        foreach my $accession_name (@$intercrop_accession_name) {
            if ($acc_synonyms_lookup{$accession_name}) {
                my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
                if (scalar(@accession_names)>1) {
                    print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
                }
                $accession_name = $accession_names[0];
            }
            push @checked_intercrop_accession_names, $accession_name;
        }

        my $key = $row_id;
        $design_details{$key}->{plot_name} = $plot_name;
        $design_details{$key}->{stock_name} = $accession_name;
        $design_details{$key}->{intercrop_stock_name} = \@checked_intercrop_accession_names;
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

# Generates a plot name from a resolved plot_name_template (a JSON-encoded
# { format_name => { name_attributes => [...] } } hash, as returned by
# CXGN::BreedersToolbox::Projects->get_autogenerated_name_metadata_by_breeding_program).
# Mirrors the algorithm in CXGN::Trial::TrialDesign::_build_plot_names so that
# generated names are identical between the two upload paths.
sub _generate_plot_name {
    my $template_json_str = shift;
    my $attrs = shift;
    return unless $template_json_str;

    my $template_json = decode_json($template_json_str);
    my ($format_name) = keys %$template_json;
    my $name_attributes = $template_json->{$format_name}->{'name_attributes'} || [];
    my %valid_attrs = map { $_ => 1 } qw(breedingProgram trialName accessionName plotNumber blockNumber rangeNumber repNumber rowNumber colNumber);

    my @components = map {
        ref $_ eq 'HASH' ? ($_->{'text'} // '') :
        $valid_attrs{$_} ? ($attrs->{$_} // '') : ''
    } @$name_attributes;

    return join('_', @components);
}

1;
