
package CXGN::Phenotypes::ParseUpload::Plugin::Observations;

use Moose;
use File::Slurp;
use List::MoreUtils qw(uniq);
use Data::Dumper;

sub name {
    return "brapi observations";
}

sub check_unique_var_unit_time {
    my $self = shift;
    my $schema = shift;
    my $variable = shift;
    my $unit = shift;
    my $timestamp = shift;
    my %check_result;
    my $variable_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, "|".$variable);

    my $q = "
    SELECT phenotype_id, value
    FROM phenotype
    JOIN nd_experiment_phenotype USING (phenotype_id)
    JOIN nd_experiment_stock USING (nd_experiment_id)
    WHERE observable_id = ? AND stock_id = ? AND collect_date = ?
    ";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($variable_cvterm->cvterm_id(), $unit, $timestamp);
    my ($id, $value) = $h->fetchrow_array();
    if ($id) {
        #print STDERR "Found id $id and value $value\n";
        $check_result{'error'} = "The combination of observationVariableDbId $variable with observationUnitDbId $unit at observationTimeStamp $timestamp already exists in the database with value $value and observationDbId $id. To update this measurement includes its observationDbId in your request";
        return \%check_result;
	}

    $check_result{'success'} = "This combination is unique";
    return \%check_result;
}

sub validate {
    my $self = shift;
    my $observations = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my %validate_result;

    # Check that "observations" key contains an array
    unless (ref($observations) eq 'ARRAY') {
        $validate_result{'error'} = "Request body is not valid. \"observations\" must be an array";
        return \%validate_result;
    }
    my @data = @{$observations};

    # Check that array is not empty
    unless (scalar @data) {
        $validate_result{'error'} = "Request does not contain any observations.";
        return \%validate_result;
    }

    foreach my $obs (@data){
        #check that is hash
        unless (ref($obs) eq 'HASH') {
            $validate_result{'error'} = "Request body is not valid. The \"observations\" array does not contain valid objects";
            return \%validate_result;
        }
        #check that each hash contains required key - value pairs
        if (!$obs->{'observationUnitDbId'}) {
            $validate_result{'error'} = "Request body is not valid. An observation object is missing required field \"observationUnitDbId\"";
            return \%validate_result;
        }
        if (!$obs->{'observationVariableDbId'}) {
            $validate_result{'error'} = "Request body is not valid. An observation object is missing required field \"observationVariableDbId\"";
            return \%validate_result;
        }
        if (!$obs->{'value'}) {
            $validate_result{'error'} = "Request body is not valid. An observation object is missing required field \"value\"";
            return \%validate_result;
        }
    }

    $validate_result{'success'} = "Request structure is valid";
    return \%validate_result;
}

sub parse {
    my $self = shift;
    my $data = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my %parse_result;


    # Check validity of submitted data
    my @data = @{$data};
    my %data = ();
    my %seen = ();
    my (@observations, @units, @variables, @values, @timestamps);
    foreach my $obs (@data){

        ## Check that observation is not duplicated in the request
        my $unique_combo = "observationUnitDbId: ".$obs->{'observationUnitDbId'}.", observationVariableDbId:".$obs->{'observationVariableDbId'}.", observationTimeStamp:".$obs->{'observationTimeStamp'};
        if ($seen{$unique_combo}) {
            $parse_result{'error'} = "Invalid request. The combination of $unique_combo appears more than once in the request";
            return \%parse_result;
        }

        if ($obs->{'observationDbId'} && defined $obs->{'observationDbId'}) {
            push @observations, $obs->{'observationDbId'};
        } else {
            ## If observationDbId is undefined, check that same trait, stock, and timestamp triplet doesn't already exist in the database
            my $unique_observation = $self->check_unique_var_unit_time($schema, $obs->{'observationVariableDbId'}, $obs->{'observationUnitDbId'}, $obs->{'observationTimeStamp'});
            if (!$unique_observation || $unique_observation->{'error'}) {
                $parse_result{'error'} = $unique_observation ? $unique_observation->{'error'} : "Error validating that observations are unique";
                return \%parse_result;
            }
        }
        push @units, $obs->{'observationUnitDbId'};
        push @variables, $obs->{'observationVariableDbId'};
        if (defined $obs->{'observationTimeStamp'}) {
            push @timestamps, $obs->{'observationTimeStamp'};
        }
        push @values, $obs->{'value'};
        $unique_combo = $obs->{'observationUnitDbId'}.$obs->{'observationVariableDbId'}.$obs->{'observationTimeStamp'};
        $seen{$unique_combo} = 1;

        # track data for store
        my $UnitDbId = $obs->{'observationUnitDbId'};
        my $VariableDbId = $obs->{'observationVariableDbId'};
        $data{$UnitDbId}->{$VariableDbId}->{timestamp} = $obs->{'observationTimeStamp'} ? $obs->{'observationTimeStamp'} : '';
        $data{$UnitDbId}->{$VariableDbId}->{value} = $obs->{'value'};
        $data{$UnitDbId}->{$VariableDbId}->{collector} = $obs->{'collector'} ? $obs->{'collector'} : '';
        $data{$UnitDbId}->{$VariableDbId}->{observation} = $obs->{'observationDbId'} ? $obs->{'observationDbId'} : '';
    }
    #print STDERR "Data is ".Dumper(%data)."\n";
    @observations = uniq @observations;
    @units = uniq @units;
    @variables = uniq @variables;
    @timestamps = uniq @timestamps;
    @values = uniq @values;

    my $validator = CXGN::List::Validate->new();

    if (scalar @observations) {

        my $validated_observations = $validator->validate($schema,'observations', \@observations);
        my @observations_missing = @{$validated_observations->{'missing'}};
        if (scalar @observations_missing) {
            $parse_result{'error'} = "The following observations do not exist in the database: ".@observations_missing;
            #print STDERR "Invalid observations: @observations_missing\n";
            return \%parse_result;
        }
    }

    my $t = CXGN::List::Transform->new();
    #print STDERR "Units are: @units\n";
    my $units_transform = $t->transform($schema, 'stock_ids_2_stocks', \@units);
    my @unit_names = @{$units_transform->{'transform'}};
    #print STDERR "Unit names are: @unit_names\n";

    my $validated_units = $validator->validate($schema,'plots_or_subplots_or_plants',\@unit_names);
    my @units_missing = @{$validated_units->{'missing'}};
    if (scalar @units_missing) {
        $parse_result{'error'} = "The following observationUnitDbIds do not exist in the database: @units_missing";
        #print STDERR "Invalid observationUnitDbIds: @units_missing\n";
        return \%parse_result;
    }

    my $validated_variables = $validator->validate($schema,'traits',\@variables);
    my @variables_missing = @{$validated_variables ->{'missing'}};
    if (scalar @variables_missing) {
        $parse_result{'error'} = "The following observationVariableDbIds do not exist in the database: @variables_missing";
        #print STDERR "Invalid observationVariableDbIds: @variables_missing\n";
        return \%parse_result;
    }

    foreach my $value (@values) {
        if ($value eq '.' || ($value =~ m/[^a-zA-Z0-9,.\-\/\_]/ && $value ne '.')) {
            $parse_result{'error'} = "Value $value is not valid. Trait values must be alphanumeric with no spaces";
            print STDERR "Invalid value: $value\n";
            return \%parse_result;
        }
    }

    foreach my $timestamp (@timestamps) {
        if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
            $parse_result{'error'} = "Timestamp $timestamp is not of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
            print STDERR "Invalid Timestamp: $timestamp\n";
            return \%parse_result;
        }
    }

    $parse_result{'success'} = "Request data is valid";
    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@units;
    $parse_result{'variables'} = \@variables;

    return \%parse_result;
}

1;
