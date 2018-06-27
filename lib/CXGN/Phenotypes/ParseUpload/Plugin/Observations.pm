
package CXGN::Phenotypes::ParseUpload::Plugin::Observations;

use Moose;
use File::Slurp;
use List::MoreUtils qw(uniq);

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
    return 1;
}

sub parse {
    my $self = shift;
    my $observations = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my %parse_result;


    # Check validity of submitted data
    my @data = @{$observations};
    my %seen = ();
    my ( @observations, @units, @variables, @values, @timestamps) = [];
    foreach my $obs (@data){
        my $unique_combo = "observationUnitDbId: ".$obs->{'observationUnitDbId'}.", observationVariableDbId:".$obs->{'observationVariableDbId'}.", observationTimeStamp:".$obs->{'observationTimeStamp'};
        if ($seen{$unique_combo}) {
            $parse_result{'error'} = "Invalid request. The combination of $unique_combo appears more than once";
            #print STDERR "Invalid request: The combination of $unique_combo appears more than once\n";
            return \%parse_result;
        }
        push @observations, $obs->{'observationDbId'} if defined $obs->{'observationDbId'};
        push @units, $obs->{'observationUnitDbId'};
        push @variables, $obs->{'observationVariableDbId'};
        push @timestamps, $obs->{'observationTimeStamp'} if defined $obs->{'observationTimeStamp'};
        push @values, $obs->{'value'};
        #$data{$obs->{'observationUnitDbId'}}->{$obs->{'observationVariableDbId'}} = [$obs->{'value'}, $obs->{'observationTimeStamp'}];
        my $unique_combo = $obs->{'observationUnitDbId'}.$obs->{'observationVariableDbId'}.$obs->{'observationTimeStamp'};
        $seen{$unique_combo} = 1;

        # track data for store
        my $UnitDbId = $obs->{'observationUnitDbId'};
        my $VariableDbId = $obs->{'observationVariableDbId'};
        $data{$UnitDbId}->{$VariableDbId}->{timestamp} = $obs->{'observationTimeStamp'} ? $obs->{'observationTimeStamp'} : '';
        $data{$UnitDbId}->{$VariableDbId}->{value} = $obs->{'value'};
        $data{$UnitDbId}->{$VariableDbId}->{collector} = $obs->{'collector'} ? $obs->{'collector'} : '';
    }
    @observations = uniq @observations;
    @units = uniq @units;
    @variables = uniq @variables;
    @timestamps = uniq @timestamps;
    @values = uniq @values;

    my $validator = CXGN::List::Validate->new();

    if (scalar @observations) {
        my @observations_missing = = @{$validator->validate($schema,'phenotypes',\@observations)->{'missing'}};
        if (scalar @observations_missing) {
            $parse_result{'error'} = "The following observations do not exist in the database: @observations_missing";
            #print STDERR "Invalid observations: @observations_missing\n";
            return \%parse_result;
        }
    }

    my @units_missing = @{$validator->validate($schema,'plots_or_subplots_or_plants',\@units)->{'missing'}};
    if (scalar @units_missing) {
        $parse_result{'error'} = "The following observationUnitDbIds do not exist in the database: @units_missing";
        #print STDERR "Invalid observationUnitDbIds: @units_missing\n";
        return \%parse_result;
    }

    my @variables_missing = @{$validator->validate($schema,'traits',\@variables)->{'missing'}};
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

    # Also should check if observationDbId is undefined. Then if so do a search for same trait, plot, and timestamp triplet. If exists, return error: "Must include the existing observationDbId to update this measurement"
    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@units;
    $parse_result{'variables'} = \@variables;
    # return \%parse_result;
    # $data{$plot_name}->{$trait_name}->{$timestamp}->{value} = $value;
    # $data{$plot_name}->{$trait_name}->{$timestamp}->{collector} = $collect;

    return 1;
}

1;
