package CXGN::Trial::ParseUpload::Plugin::TrialGeneric;

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
use CXGN::Trial;
use Data::Dumper;

my @REQUIRED_COLUMNS = qw|stock_name plot_number block_number|;
# stock_name can also be accession_name, cross_unique_id, or family_name
my @OPTIONAL_COLUMNS = qw|intercrop_stock_name plot_name is_a_control rep_number range_number row_number col_number seedlot_name num_seed_per_plot weight_gram_seed_per_plot entry_number|;
# Any additional columns that are not required or optional will be used as a treatment

sub _single_trial_generic_message {
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
    my SGN::I18N $single_generic_validate_i18n = $self->i18n;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $trial_name = $self->get_trial_name();
    my $trial_stock_type = $self->get_trial_stock_type();
    my $plot_name_template = $self->get_plot_name_template();
    my $breeding_program_name = $self->get_breeding_program_name();

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
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.treatment_column_format', "Column %{column} is not formatted like a treatment. Use only full, valid treatment names.\n", { column => '__SGN_TREATMENT_COLUMN__' })
                    : "Column __SGN_TREATMENT_COLUMN__ is not formatted like a treatment. Use only full, valid treatment names.\n",
                { '__SGN_TREATMENT_COLUMN__' => $treatment }
            );
        }
    }

    if (@{$validate->{missing}}>0) {
        foreach my $missing (@{$validate->{missing}}) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.treatment_missing', "Treatment %{treatment} does not exist in the database.\n", { treatment => '__SGN_TREATMENT__' })
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
        my $plot_name = $data->{'plot_name'} || _generate_plot_name($plot_name_template, {
            breedingProgram => $breeding_program_name,
            trialName       => $trial_name,
            accessionName   => $stock_name,
            plotNumber      => $plot_number,
            blockNumber     => $block_number,
            rangeNumber     => $range_number,
            repNumber       => $rep_number,
            rowNumber       => $row_number,
            colNumber       => $col_number,
        }) || _create_plot_name($trial_name, $plot_number);

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
                push @error_messages, _single_trial_generic_message(
                    $single_generic_validate_i18n
                        ? $single_generic_validate_i18n->p('trial.upload.multi.generic.treatment_value_below_minimum', 'Row %{row}: value for %{treatment} is lower than the allowed minimum for that treatment.', { row => '__SGN_ROW__', treatment => '__SGN_TREATMENT__' })
                        : 'Row __SGN_ROW__: value for __SGN_TREATMENT__ is lower than the allowed minimum for that treatment.',
                    { '__SGN_ROW__' => $row, '__SGN_TREATMENT__' => $treatment }
                );
            }
            if ($treatment_obj->format() eq "numeric" && defined($treatment_obj->maximum()) && defined($data->{$treatment}) && $data->{$treatment} > $treatment_obj->maximum()) {
                push @error_messages, _single_trial_generic_message(
                    $single_generic_validate_i18n
                        ? $single_generic_validate_i18n->p('trial.upload.multi.generic.treatment_value_above_maximum', 'Row %{row}: value for %{treatment} is higher than the allowed maximum for that treatment.', { row => '__SGN_ROW__', treatment => '__SGN_TREATMENT__' })
                        : 'Row __SGN_ROW__: value for __SGN_TREATMENT__ is higher than the allowed maximum for that treatment.',
                    { '__SGN_ROW__' => $row, '__SGN_TREATMENT__' => $treatment }
                );
            }
            if ($treatment_obj->format() eq "qualitative" && defined($treatment_obj->categories()) && defined($data->{$treatment})) {
                my $qual_value = $data->{$treatment};
                my $categories = $treatment_obj->categories();
                if ( $categories !~ m/$qual_value/) {
                    push @error_messages, _single_trial_generic_message(
                        $single_generic_validate_i18n
                            ? $single_generic_validate_i18n->p('trial.upload.multi.generic.treatment_value_category', 'Row %{row}: value for %{treatment} is not in the valid categories for that treatment.', { row => '__SGN_ROW__', treatment => '__SGN_TREATMENT__' })
                            : 'Row __SGN_ROW__: value for __SGN_TREATMENT__ is not in the valid categories for that treatment.',
                        { '__SGN_ROW__' => $row, '__SGN_TREATMENT__' => $treatment }
                    );
                }
            }
        }


        # Plot Number: must be a positive number
        if (!($plot_number =~ /^\d+?$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot number', '__SGN_VALUE__' => '<strong>'.$plot_number.'</strong>' }
            );
        }

        # Block Number: must be a positive integer
        if (!($block_number =~ /^\d+?$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'block number', '__SGN_VALUE__' => '<strong>'.$block_number.'</strong>' }
            );
        }

        # Rep Number: must be a positive integer, if provided
        if ($rep_number && !($rep_number =~ /^\d+?$/)){
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'rep_number', '__SGN_VALUE__' => '<strong>'.$rep_number.'</strong>' }
            );
        }

        # Plot Name: cannot contain spaces, should not contain slashes
        if ($plot_name =~ /\s/ ) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.no_spaces_row', 'Row %{row}: %{field} %{value} must not contain spaces.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must not contain spaces.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot name', '__SGN_VALUE__' => '<strong>'.$plot_name.'</strong>' }
            );
        }
        if ($plot_name =~ /\// || $plot_name =~ /\\/) {
            push @warning_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.plot_name_slashes_warning', 'Row %{row}: %{field} %{value} contains slashes. Note that slashes can cause problems for third-party applications; however, plot names can be saved with slashes if you ignore warnings.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ contains slashes. Note that slashes can cause problems for third-party applications; however, plot names can be saved with slashes if you ignore warnings.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot name', '__SGN_VALUE__' => '<strong>'.$plot_name.'</strong>' }
            );
        }

        # Plot Width / Plot Length / Field Size: must be a positive number, if provided
        if ($plot_width && !($plot_width =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_number', 'Row %{row}: %{field} %{value} must be a positive number.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive number.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot_width', '__SGN_VALUE__' => '<strong>'.$plot_width.'</strong>' }
            );
        }
        if ($plot_length && !($plot_length =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_number', 'Row %{row}: %{field} %{value} must be a positive number.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive number.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot_length', '__SGN_VALUE__' => '<strong>'.$plot_length.'</strong>' }
            );
        }
        if ($field_size && !($field_size =~ /^([\d]*)([\.]?)([\d]+)$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_number', 'Row %{row}: %{field} %{value} must be a positive number.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive number.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'plot_width', '__SGN_VALUE__' => '<strong>'.$field_size.'</strong>' }
            );
        }

        # Is A Control: must be blank, 0, or 1, if provided
        if ( $is_a_control && $is_a_control ne '' && $is_a_control ne '0' && $is_a_control ne '1' ) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.control_value_invalid', 'Row %{row}: %{field} value of %{value} is invalid.  It must be %{blank} (not a control), %{zero} (not a control), or %{one} (is a control).', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__', blank => '__SGN_BLANK__', zero => '__SGN_ZERO__', one => '__SGN_ONE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ value of __SGN_VALUE__ is invalid.  It must be __SGN_BLANK__ (not a control), __SGN_ZERO__ (not a control), or __SGN_ONE__ (is a control).',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'is_a_control', '__SGN_VALUE__' => '<strong>'.$is_a_control.'</strong>', '__SGN_BLANK__' => 'blank', '__SGN_ZERO__' => '0', '__SGN_ONE__' => '1' }
            );
        }

        # Range Number / Row Number / Col Number: must be a positive integer, if provided
        if ($range_number && !($range_number =~ /^\d+?$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'range_number', '__SGN_VALUE__' => '<strong>'.$range_number.'</strong>' }
            );
        }
        if ($row_number && !($row_number =~ /^\d+?$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'row_number', '__SGN_VALUE__' => '<strong>'.$row_number.'</strong>' }
            );
        }
        if ($col_number && !($col_number =~ /^\d+?$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'col_number', '__SGN_VALUE__' => '<strong>'.$col_number.'</strong>' }
            );
        }

        # Seedlots: add seedlot_name / accession_name to seedlot_pairs
        # count and weight must be a positive integer
        # return a warning if both count and weight are not provided
        if ( $seedlot_name ) {
            push @seedlot_pairs, [$seedlot_name, $stock_name];
            if ( $num_seed_per_plot && $num_seed_per_plot ne '' && !($num_seed_per_plot =~ /^\d+?$/) ) {
                push @error_messages, _single_trial_generic_message(
                    $single_generic_validate_i18n
                        ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                        : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                    { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'num_seed_per_plot', '__SGN_VALUE__' => '<strong>'.$num_seed_per_plot.'</strong>' }
                );
            }
            if ( $weight_gram_seed_per_plot && $weight_gram_seed_per_plot ne '' && !($weight_gram_seed_per_plot =~ /^\d+?$/) ) {
                push @error_messages, _single_trial_generic_message(
                    $single_generic_validate_i18n
                        ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                        : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                    { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'weight_gram_seed_per_plot', '__SGN_VALUE__' => '<strong>'.$weight_gram_seed_per_plot.'</strong>' }
                );
            }
            if ( !$num_seed_per_plot && !$weight_gram_seed_per_plot ) {
                push @warning_messages, _single_trial_generic_message(
                    $single_generic_validate_i18n
                        ? $single_generic_validate_i18n->p('trial.upload.multi.generic.seedlot_no_seed_quantity', 'Row %{row}: this plot does not have a count or weight of seed to be used from seedlot %{seedlot}.', { row => '__SGN_ROW__', seedlot => '__SGN_SEEDLOT__' })
                        : 'Row __SGN_ROW__: this plot does not have a count or weight of seed to be used from seedlot __SGN_SEEDLOT__.',
                    { '__SGN_ROW__' => $row, '__SGN_SEEDLOT__' => '<strong>'.$seedlot_name.'</strong>' }
                );
            }
        }

        # Entry Number: must be a positive integer, if provided
        if ($entry_number && !($entry_number =~ /^\d+?$/)) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.positive_integer', 'Row %{row}: %{field} %{value} must be a positive integer.', { row => '__SGN_ROW__', field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : 'Row __SGN_ROW__: __SGN_FIELD__ __SGN_VALUE__ must be a positive integer.',
                { '__SGN_ROW__' => $row, '__SGN_FIELD__' => 'entry_number', '__SGN_VALUE__' => '<strong>'.$entry_number.'</strong>' }
            );
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
    if ($schema->resultset('Project::Project')->find({ name => $trial_name })) {
        push @already_used_trial_names, $trial_name;
    }
    foreach (($trial_name)) {
        if ($_ =~ /\s/) {
            push @error_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.no_spaces', '%{field} %{value} must not contain spaces.', { field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : '__SGN_FIELD__ __SGN_VALUE__ must not contain spaces.',
                { '__SGN_FIELD__' => 'trial_name', '__SGN_VALUE__' => '<strong>'.$_.'</strong>' }
            );
        }
        if ($_ =~ /\// || $_ =~ /\\/) {
            push @warning_messages, _single_trial_generic_message(
                $single_generic_validate_i18n
                    ? $single_generic_validate_i18n->p('trial.upload.multi.generic.slashes_warning', '%{field} %{value} contains slashes. Note that slashes can cause problems for third-party applications; however, trial names can be saved with slashes if you ignore warnings.', { field => '__SGN_FIELD__', value => '__SGN_VALUE__' })
                    : '__SGN_FIELD__ __SGN_VALUE__ contains slashes. Note that slashes can cause problems for third-party applications; however, trial names can be saved with slashes if you ignore warnings.',
                { '__SGN_FIELD__' => 'trial_name', '__SGN_VALUE__' => '<strong>'.$_.'</strong>' }
            );
        }
    }
    if (scalar(@already_used_trial_names) > 0) {
        push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.multi.generic.trial_names_already_used", "Trial name(s) %{names} are invalid because they are already used in the database.", {names => "__SGN_SINGLE_0__"}) : "Trial name(s) __SGN_SINGLE_0__ are invalid because they are already used in the database.", {"__SGN_SINGLE_0__" => "<strong>".join(', ',@already_used_trial_names)."</strong>"});
    }

    # Stock Names: must exist in the database
    my @entry_names = @{$parsed_values->{'stock_name'}};
    my @intercrop_names = $parsed_values->{'intercrop_stock_name'} ? @{$parsed_values->{'intercrop_stock_name'}} : ();
    my @merged_names = uniq(@entry_names, @intercrop_names);
    my $entry_name_validator = CXGN::List::Validate->new();
    my @entry_names_missing = ();
    if ($trial_stock_type eq 'cross') {
        @entry_names_missing = @{$entry_name_validator->validate($schema,'accessions_or_synonyms_or_crosses',\@merged_names)->{'missing'}};
        if (scalar(@entry_names_missing) > 0) {
            $errors{'missing_stocks'} = \@entry_names_missing;
            push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.entry_names_cross", "The following entry names are not in the database or are not accession or cross stock type: %{names}", {names => "__SGN_SINGLE_0__"}) : "The following entry names are not in the database or are not accession or cross stock type: __SGN_SINGLE_0__", {"__SGN_SINGLE_0__" => join(',',@entry_names_missing)});
        }
    } elsif ($trial_stock_type eq 'family_name') {
        @entry_names_missing = @{$entry_name_validator->validate($schema,'accessions_or_family_names',\@merged_names)->{'missing'}};
        if (scalar(@entry_names_missing) > 0) {
            $errors{'missing_stocks'} = \@entry_names_missing;
            push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.entry_names_family", "The following entry names are not in the database or are not accession or family name stock type: %{names}", {names => "__SGN_SINGLE_0__"}) : "The following entry names are not in the database or are not accession or family name stock type: __SGN_SINGLE_0__", {"__SGN_SINGLE_0__" => join(',',@entry_names_missing)});
        }
    } else {
        @entry_names_missing = @{$entry_name_validator->validate($schema,'accessions',\@merged_names)->{'missing'}};
        if (scalar(@entry_names_missing) > 0) {
            $errors{'missing_stocks'} = \@entry_names_missing;
            push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.entry_names_accession", "The following entry names are not in the database as uniquenames or synonyms of accession stock type: %{names}", {names => "__SGN_SINGLE_0__"}) : "The following entry names are not in the database as uniquenames or synonyms of accession stock type: __SGN_SINGLE_0__", {"__SGN_SINGLE_0__" => join(',',@entry_names_missing)});
        }
    }

    # Seedlots: names must exist in the database
    my @seedlots_missing = @{$validator->validate($schema,'seedlots',$parsed_values->{'seedlot_name'})->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.multi.generic.seedlots_missing", "Seedlot(s) %{seedlots} are not in the database.  To use a seedlot as a seed source for a plot, the seedlot must already exist in the database.", {seedlots => "__SGN_SINGLE_0__"}) : "Seedlot(s) __SGN_SINGLE_0__ are not in the database.  To use a seedlot as a seed source for a plot, the seedlot must already exist in the database.", {"__SGN_SINGLE_0__" => "<strong>".join(',',@seedlots_missing)."</strong>"});
    }

    # Verify seedlot pairs: accession name of plot must match seedlot contents
    if ((scalar @entry_names_missing == 0) && (scalar @seedlots_missing == 0)) {
        if ( scalar(@seedlot_pairs) > 0 ) {
            my $return;
            if ($trial_stock_type eq 'family_name') {
                $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_family_names($schema, \@seedlot_pairs);
            } else {
                $return = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, \@seedlot_pairs);
            }
            if (exists($return->{error})){
                push @error_messages, $return->{error};
            }
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
        push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.multi.generic.plot_names_already_used", "Plot name(s) %{names} are invalid because they are already used in the database.", {names => "__SGN_SINGLE_0__"}) : "Plot name(s) __SGN_SINGLE_0__ are invalid because they are already used in the database.", {"__SGN_SINGLE_0__" => "<strong>".join(', ',@already_used_plot_names)."</strong>"});
    }

    # Check for duplicated plot numbers
    foreach my $pk (keys %seen_plot_numbers) {
        my $count = $seen_plot_numbers{$pk};
        if ( $count > 1 ) {
            push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.plot_number_count", "Plot number %{number} is used %{count} times.  Each plot should have a unique plot number.", {number => "__SGN_SINGLE_0__", count => "__SGN_SINGLE_1__"}) : "Plot number __SGN_SINGLE_0__ is used __SGN_SINGLE_1__ times.  Each plot should have a unique plot number.", {"__SGN_SINGLE_0__" => "<strong>$pk</strong>", "__SGN_SINGLE_1__" => $count});
        }
    }

    # Check for duplicated plot names
    foreach my $pk (keys %seen_plot_names) {
        my $count = $seen_plot_names{$pk};
        if ( $count > 1 ) {
            push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.plot_name_count", "Plot name %{name} is used %{count} times. Each plot should have a unique plot name.", {name => "__SGN_SINGLE_0__", count => "__SGN_SINGLE_1__"}) : "Plot name __SGN_SINGLE_0__ is used __SGN_SINGLE_1__ times. Each plot should have a unique plot name.", {"__SGN_SINGLE_0__" => "<strong>$pk</strong>", "__SGN_SINGLE_1__" => $count});
        }
    }

    # Check for overlapping plot positions (more than one plot assigned the same row/col positions)
    foreach my $pk (keys %seen_plot_positions) {
        my $plots = $seen_plot_positions{$pk};
        my $count = scalar(@$plots);
        if ( $count > 1 ) {
            my @pos = split('-', $pk);
            push @warning_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.position", "More than 1 plot is assigned to the position row=%{row} col=%{col} plots=%{plots}", {row => "__SGN_SINGLE_0__", col => "__SGN_SINGLE_1__", plots => "__SGN_SINGLE_2__"}) : "More than 1 plot is assigned to the position row=__SGN_SINGLE_0__ col=__SGN_SINGLE_1__ plots=__SGN_SINGLE_2__", {"__SGN_SINGLE_0__" => $pos[0], "__SGN_SINGLE_1__" => $pos[1], "__SGN_SINGLE_2__" => join(',', @$plots)});
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
            push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.accession_entry_mismatch", "Entry Number mismatch: Accession %{name} has multiple entry numbers (%{numbers}) assigned to it.", {name => "__SGN_SINGLE_0__", numbers => "__SGN_SINGLE_1__"}) : "Entry Number mismatch: Accession __SGN_SINGLE_0__ has multiple entry numbers (__SGN_SINGLE_1__) assigned to it.", {"__SGN_SINGLE_0__" => "<strong>$an</strong>", "__SGN_SINGLE_1__" => join(', ', @ens)});
        }
    }

    # check assignments by entry number
    foreach my $en (keys %{$seen_entry_numbers{'by_num'}} ) {
        my @ans = uniq @{$seen_entry_numbers{'by_num'}{$en}};
        my $count = scalar(@ans);
        if ( scalar(@ans) > 1 ) {
            push @error_messages, _single_trial_generic_message($single_generic_validate_i18n ? $single_generic_validate_i18n->p("trial.upload.single.generic.entry_accession_mismatch", "Entry Number mismatch: Entry number %{number} has multiple accessions (%{names}) assigned to it.", {number => "__SGN_SINGLE_0__", names => "__SGN_SINGLE_1__"}) : "Entry Number mismatch: Entry number __SGN_SINGLE_0__ has multiple accessions (__SGN_SINGLE_1__) assigned to it.", {"__SGN_SINGLE_0__" => "<strong>$en</strong>", "__SGN_SINGLE_1__" => join(', ', @ans)});
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
    my $plot_name_template = $self->get_plot_name_template();
    my $breeding_program_name = $self->get_breeding_program_name();
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
    my $plot_name_template_used = 0;
    foreach (@$data) {
        my $r = $_;
        my $row = $r->{'_row'};
        my $stock_name = $r->{'stock_name'};
        my $intercrop_stock_name = $r->{'intercrop_stock_name'};
        my $plot_number = $r->{'plot_number'};
        my $block_number = $r->{'block_number'};
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
        if (!$r->{'plot_name'} && $plot_name_template) {
            $plot_name_template_used = 1;
        }
        my $plot_name = $r->{'plot_name'} || _generate_plot_name($plot_name_template, {
            breedingProgram => $breeding_program_name,
            trialName       => $trial_name,
            accessionName   => $stock_name,
            plotNumber      => $plot_number,
            blockNumber     => $block_number,
            rangeNumber     => $range_number,
            repNumber       => $rep_number,
            rowNumber       => $row_number,
            colNumber       => $col_number,
        }) || _create_plot_name($trial_name, $plot_number);

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
        treatment_design => $treatment_design,
        plot_name_template_used => $plot_name_template_used
    );

    $self->_set_parsed_data(\%parsed_data);

    return 1;
}

sub _create_plot_name {
  my $trial_name = shift;
  my $plot_number = shift;
  return $trial_name . "-PLOT_" . $plot_number;
}

# Generates a plot name from a plot_name_template (a JSON-encoded
# { format_name => { name_attributes => [...] } } hash, as returned by
# CXGN::BreedersToolbox::Projects->get_autogenerated_name_metadata_by_breeding_program).
# Mirrors the algorithm in CXGN::Trial::TrialDesign::_build_plot_names and
# CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignGeneric::_generate_plot_name
# so that generated names are identical between the different upload paths.
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
