package CXGN::Trial::ParseUpload::Plugin::TrialMetadataGeneric;

use Moose::Role;
use List::MoreUtils qw(uniq);
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;
use CXGN::Trial;

my @REQUIRED_COLUMNS = qw|trial_name|;
my @OPTIONAL_COLUMNS = qw|name breeding_program folder location year transplanting_date planting_date harvest_date design_type description type plot_width plot_length field_size|;
# Any additional columns are unsupported and will return an error

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
            'name' => [ 'new_trial_name' ],
            'type' => [ 'trial_type' ]
        }
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
        if ($transplanting_date && $transplanting_date ne 'remove' && !$calendar_funcs->check_value_format($transplanting_date)) {
            push @error_messages, "Row $row: transplanting_date <strong>$transplanting_date</strong> must be in the format YYYY-MM-DD.";
        }
        if ($planting_date && $planting_date ne 'remove' && !$calendar_funcs->check_value_format($planting_date)) {
            push @error_messages, "Row $row: planting_date <strong>$planting_date</strong> must be in the format YYYY-MM-DD.";
        }
        if ($harvest_date && $harvest_date ne 'remove' && !$calendar_funcs->check_value_format($harvest_date)) {
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
    my $trial_validation = $validator->validate($schema,'trials',$parsed_values->{'trial_name'});
    my @missing_trial_names = @{$trial_validation->{'missing'}};
    if (scalar(@missing_trial_names) > 0) {
        push @error_messages, "Trial name(s) <strong>".join(', ',@missing_trial_names)."</strong> do not exist in the database.";
    }

    # New Trial Names: must NOT already exist in the database, cannot contains spaces
    my @already_used_new_trial_names;
    my @missing_new_trial_names = @{$validator->validate($schema,'trials',$parsed_values->{'name'})->{'missing'}};
    my %unused_new_trial_names = map { $missing_new_trial_names[$_] => $_ } 0..$#missing_new_trial_names;
    foreach (@{$parsed_values->{'name'}}) {
        push(@already_used_new_trial_names, $_) unless exists $unused_new_trial_names{$_};
        if ($_ =~ /\s/) {
            push @error_messages, "new_trial_name <strong>$_</strong> must not contain spaces.";
        }
        # if ($_ =~ /\// || $_ =~ /\\/) {
        #     push @warning_messages, "trial_name <strong>$_</strong> contains slashes. Note that slashes can cause problems for third-party applications; however, trial names can be saved with slashes if you ignore warnings.";
        # }
    }
    if (scalar(@already_used_new_trial_names) > 0) {
        push @error_messages, "New Trial Name(s) <strong>".join(', ',@already_used_new_trial_names)."</strong> are invalid because they are already used in the database.";
    }

    # Breeding Program: must already exist in the database
    my $breeding_programs_missing = $validator->validate($schema,'breeding_programs',$parsed_values->{'breeding_program'})->{'missing'};
    my @breeding_programs_missing = @{$breeding_programs_missing};
    if (scalar(@breeding_programs_missing) > 0) {
        push @error_messages, "Breeding program(s) <strong>".join(', ',@breeding_programs_missing)."</strong> are not in the database.";
    }

    # Location: Transform location abbreviations/codes to full names
    my $locations_hashref = $validator->validate($schema,'locations',$parsed_values->{'location'});
    my @codes = @{$locations_hashref->{'codes'}};
    my %location_code_map;
    foreach my $code (@codes) {
        my $location_code = $code->[0];
        my $found_location_name = $code->[1];
        $location_code_map{$location_code} = $found_location_name;
        # push @warning_messages, "File location <strong>$location_code</strong> matches the code for the location named <strong>$found_location_name</strong> and will be substituted if you ignore warnings.";
    }
    $self->_set_location_code_map(\%location_code_map);

    # Location: must already exist in the database
    my @locations_missing = @{$locations_hashref->{'missing'}};
    my @locations_missing_no_codes = grep { !exists $location_code_map{$_} } @locations_missing;
    if (scalar(@locations_missing_no_codes) > 0) {
        push @error_messages, "Location(s) <strong>".join(', ',@locations_missing_no_codes)."</strong> are not in the database.";
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
    foreach (@{$parsed_values->{'type'}}) {
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

    # Valid Trial Types
    my @valid_trial_types = CXGN::Trial::get_all_project_types($schema);
    my %valid_trial_types = map { @{$_}[1] => @{$_}[0] } @valid_trial_types;

    # Get existing folders (set hash of folder name --> folder id)
    my @existing_folders = CXGN::Trial::Folder->list({ bcs_schema => $schema, folder_for_trials => 1 });
    my %folders_hash = map { @{$_}[1] => @{$_}[0] } @existing_folders;

    my %trial_data;
    my %breeding_programs;
    foreach my $d (@$data) {
        my $trial_name = $d->{'trial_name'};
        my $location = $d->{'location'};
        my $breeding_program = $d->{'breeding_program'};
        my $trial_type = $d->{'type'};
        my $folder_name = $d->{'folder'};

        # Get trial id
        my $rs = $schema->resultset("Project::Project")->search({ name => $trial_name });
        my $trial_id = $rs->first->project_id;

        # Add breeding program name(s)
        my $trial = CXGN::Project->new({ bcs_schema => $schema, trial_id => $trial_id });
        my $original_breeding_program = $trial->get_breeding_program();
        $breeding_programs{$original_breeding_program} = 1;
        $breeding_programs{$breeding_program} = 1 if $breeding_program;

        # Replace breeding program name with ID
        if ( $breeding_program ) {
            my $brs = $schema->resultset("Project::Project")->search({ name => $breeding_program });
            $d->{'breeding_program'} = $brs->first->project_id;
        }

        # Replace location codes and names with ID
        if ( $location ) {
            if ( $self->_has_location_code_map() ) {
                my $location_code_map = $self->_get_location_code_map();
                if ( exists $location_code_map->{$location} ) {
                    $location = $location_code_map->{$location};
                }
            }
            my $lrs = $schema->resultset("NaturalDiversity::NdGeolocation")->search({ description => $location });
            $d->{'location'} = $lrs->first->nd_geolocation_id;
        }

        # Replace trial type with cvterm ID
        if ( $trial_type ) {
            $d->{'type'} = $valid_trial_types{$trial_type};
        }

        # Set folder id, if folder name is present
        my $folder_id;
        if ( defined $folder_name && $folder_name ne '' ) {

            # use existing folder
            if ( exists $folders_hash{$folder_name} ) {
                $folder_id = $folders_hash{$folder_name};
            }

            # create new folder
            else {
                my $bp_name = defined $breeding_program && $breeding_program ne '' ? $breeding_program : $original_breeding_program;
                my $bprs = $schema->resultset("Project::Project")->search({ name => $bp_name });
                my $breeding_program_id = $bprs->first->project_id;
                my $f = CXGN::Trial::Folder->create({
                    bcs_schema => $schema,
                    name => $folder_name,
                    breeding_program_id => $breeding_program_id,
                    folder_for_trials => 1
                });
                $folder_id = $f->folder_id();
                $folders_hash{$folder_name} = $folder_id;
            }

        }
        $d->{'folder'} = $folder_id;

        $trial_data{$trial_id} = $d;
    }

    # Return parsed data and breeding programs
    my @bp = keys %breeding_programs;
    my %rtn = ( trial_data => \%trial_data, breeding_programs => \@bp );
    $self->_set_parsed_data(\%rtn);
    return 1;
}

1;
