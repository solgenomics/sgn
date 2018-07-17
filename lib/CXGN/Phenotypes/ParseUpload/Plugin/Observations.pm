
package CXGN::Phenotypes::ParseUpload::Plugin::Observations;

use Moose;
use File::Slurp;
use List::MoreUtils qw(uniq);
use Data::Dumper;

sub name {
    return "brapi observations";
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
        my $unique_combo = "observationUnitDbId: ".$obs->{'observationUnitDbId'}.", observationVariableDbId:".$obs->{'observationVariableDbId'}.", observationTimeStamp:".$obs->{'observationTimeStamp'};
        print STDERR "Unique combo is $unique_combo\n";
        if ($seen{$unique_combo}) {
            $parse_result{'error'} = "Invalid request. The combination of $unique_combo appears more than once";
            #print STDERR "Invalid request: The combination of $unique_combo appears more than once\n";
            return \%parse_result;
        }
        if (defined $obs->{'observationDbId'}) {
            push @observations, $obs->{'observationDbId'};
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
    print STDERR "Data is ".Dumper(%data)."\n";
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
    print STDERR "Units are: @units\n";
    my $units_transform = $t->transform($schema, 'stock_ids_2_stocks', \@units);
    my @unit_names = @{$units_transform->{'transform'}};
    print STDERR "Unit names are: @unit_names\n";

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

    # Also should check if observationDbId is undefined. Then if so do a search for same trait, plot, and timestamp triplet.
    # If exists, return error: "Must include the existing observationDbId to update this measurement"
    # Not doing yet, as timestamp is still stored in uniquename

    $parse_result{'success'} = "Request data is valid";
    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@units;
    $parse_result{'variables'} = \@variables;

    return \%parse_result;
}

1;
