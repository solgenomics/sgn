package CXGN::Trial::ParseUpload::Plugin::TrialMetadataGeneric;

use Moose::Role;
use List::MoreUtils qw(uniq);
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;
use CXGN::Trial;

my @REQUIRED_COLUMNS = qw|trial_name|;
my @OPTIONAL_COLUMNS = qw|breeding_program location year transplanting_date planting_date harvest_date design_type description trial_type plot_width plot_length field_size|;
# Any additional columns are unsupported and will return an error

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
    my $additional_columns = $parsed->{'additional_columns'};

    # Return file parsing errors
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Unsupported column headers
    if ( $additional_columns && scalar(@$additional_columns) > 0 ) {
        $errors{'error_messages'} = [ 'The follow column headers are not supported: ' . join(', ', @$additional_columns) ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    ##
    ## ROW BY ROW VALIDATION
    ##
    foreach my $data (@$parsed_data) {
        my $row = $data->{'_row'};
        my $transplanting_date = $data->{'transplanting_date'};
        my $planting_date = $data->{'planting_date'};
        my $harvest_date = $data->{'harvest_date'};
        my $plot_width = $data->{'plot_width'};
        my $plot_length = $data->{'plot_length'};
        my $field_size = $data->{'field_size'};

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
    }

    ##
    ## OVERALL VALIDATION
    ##

    # Trial Name: must already exist in the database
    my @missing_trial_names = @{$validator->validate($schema,'trials',$parsed_values->{'trial_name'})->{'missing'}};
    if (scalar(@missing_trial_names) > 0) {
        push @error_messages, "Trial name(s) <strong>".join(', ',@missing_trial_names)."</strong> do not exist in the database.";
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

    my %parsed_data;
    foreach my $d (@$data) {
        my $trial_name = $d->{'trial_name'};
        my $location = $d->{'location'};

        # Get location and replace codes with names
        if ( $self->_has_location_code_map() ) {
            my $location_code_map = $self->_get_location_code_map();
            if ( exists $location_code_map->{$location} ) {
                $d->{'location'} = $location_code_map->{$location};
            }
        }

        $parsed_data{$trial_name} = $d;
    }

    $self->_set_parsed_data(\%parsed_data);
    return 1;
}

1;
