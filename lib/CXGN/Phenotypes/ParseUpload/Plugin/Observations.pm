
package CXGN::Phenotypes::ParseUpload::Plugin::Observations;

# Validate Returns %validate_result = (
#   success => 'success message',
#   error => 'error message'
#)

# Parse Returns %parse_result = (
#   success => 'success message',
#   data => {
#        plotdbid1 => {
#           vardbid1 => ['23', '2015-06-16T00:53:26Z', 'collectorname1', phenotypedbid1],
#           vardbid2 => ['25', '2015-06-17T00:53:26Z', 'collectorname1', ''],
#       },
#       plotdbid2 => {
#           vardbid2 => ['2', '2015-08-16T00:53:26Z', 'collector2', '']
#       }
#   },
#   units => [plotdbid1, plotdbid2]
#   variables => [vardbid1, vardbid2]
#)

use Moose;
use File::Slurp;
use List::MoreUtils qw(uniq);
use Data::Dumper;
use CXGN::TimeUtils;
use CXGN::BrAPI::v2::ExternalReferences;
use SGN::Model::Cvterm;

sub name {
    return "brapi observations";
}

sub check_unique_var_unit_time {
    my $self = shift;
    my $schema = shift;
    my $trait_cvterm = shift;
    my $unit = shift;
    my $timestamp = shift;
    my $excluded_id = shift;
    my $variable_id = $trait_cvterm->cvterm_id();
    my %check_result;

    my $q = "
    SELECT phenotype_id, value
    FROM phenotype
    JOIN nd_experiment_phenotype USING (phenotype_id)
    JOIN nd_experiment_stock USING (nd_experiment_id)
    WHERE observable_id = ? AND stock_id = ? AND collect_date IS NOT DISTINCT FROM ?::timestamp
    ";

    my @bind=($variable_id,$unit,$timestamp);
    if (defined($excluded_id)) {
        $q .= ' AND phenotype_id <> ?';
        push @bind,$excluded_id;
    }
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute(@bind);
    my ($id, $value) = $h->fetchrow_array();
    if ($id) {
        #print STDERR "Found id $id and value $value\n";
        $check_result{'error'} = "The combination of observationVariableDbId $variable_id with observationUnitDbId $unit at observationTimeStamp $timestamp already exists in the database with value $value and observationDbId $id. To update this measurement includes its observationDbId in your request";
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
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
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
        if (!$obs->{'value'} && $obs->{'value'} != '0') {
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
    my $zipfile = shift; #not relevant for this plugin
    my $user_name = shift;
    my $c = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my %parse_result;


    # Check validity of submitted data
    my @data = @{$data};
    my %data = ();
    my %seen = ();
    my %seen_observation_ids;
    my (@observations, @unit_dbids, @variables, @values, @timestamps);

    foreach my $obs (@data){

        my $obsunit_db_id = $obs->{'observationUnitDbId'};
        my $variable_db_id = $obs->{'observationVariableDbId'};
        my $timestamp = exists($obs->{'observationTimeStamp'}) ? $obs->{'observationTimeStamp'} : undef;
        my $collector = defined($obs->{'collector'}) && $obs->{'collector'} ne '' ? $obs->{'collector'} : $user_name;
        my $obs_db_id = defined($obs->{'observationDbId'}) ? $obs->{'observationDbId'} : '';
        my $original_timestamp;
        my $value = $obs->{'value'};
        my $additional_info = $obs->{'additionalInfo'};
        my $external_references = $obs->{'externalReferences'};
        if (!defined($obsunit_db_id) || ref($obsunit_db_id) || $obsunit_db_id !~ /^[1-9]\d*$/ || !defined($variable_db_id) || ref($variable_db_id) || $variable_db_id !~ /^[1-9]\d*$/) {
            return {error => 'Observation unit and variable identifiers must be positive integers.'};
        }
        return {error=>'Collector must be a scalar value.'} if defined($collector) && ref($collector);
        return {error=>'additionalInfo must be an object.'} if defined($additional_info) && ref($additional_info) ne 'HASH';
        my $provided = { timestamp => exists($obs->{observationTimeStamp}) ? 1 : 0, collector => exists($obs->{collector}) ? 1 : 0 };
        if (defined($obs_db_id) && $obs_db_id ne '') {
            return {error => 'Observation identifier must be a positive integer.'} if ref($obs_db_id) || $obs_db_id !~ /^[1-9]\d*$/;
            return {error => 'An existing observation identifier appears more than once in the request.'} if $seen_observation_ids{$obs_db_id}++;
            my $rows = $schema->storage->dbh->selectall_arrayref('SELECT DISTINCT p.cvalue_id, p.collect_date, p.operator, nes.stock_id FROM phenotype p JOIN nd_experiment_phenotype nep USING(phenotype_id) JOIN nd_experiment_stock nes USING(nd_experiment_id) WHERE p.phenotype_id = ?', {Slice => {}}, $obs_db_id);
            return {error => "Observation $obs_db_id does not exist."} if !@$rows;
            return {error => "Observation $obs_db_id belongs to a different observation unit or variable; its identity cannot be changed."}
                if @$rows != 1 || $rows->[0]->{stock_id} != $obsunit_db_id || $rows->[0]->{cvalue_id} != $variable_db_id;
            $original_timestamp=$rows->[0]->{collect_date};
            $timestamp = $rows->[0]->{collect_date} if !$provided->{timestamp};
            $collector = $rows->[0]->{operator} if !$provided->{collector};
        }
        $timestamp = eval { CXGN::TimeUtils::normalize_db_timestamp($timestamp) };
        return {error => "Invalid observation timestamp: $@"} if $@;
        return {error => "Observation variable $variable_db_id does not exist."} if !$schema->resultset('Cv::Cvterm')->find({cvterm_id => $variable_db_id});
        my $trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $variable_db_id,"extended");
        my $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name);

        my $unique_combo = join("\x1e", $obsunit_db_id, $variable_db_id, $timestamp // '');
        if ($seen{$unique_combo}) {
            $parse_result{'error'} = "Invalid request. The combination of $unique_combo appears more than once in the request";
            return \%parse_result;
        }
        $seen{$unique_combo} = 1;

        # Existing duplicate keys can be corrected by their distinct IDs.
        # A timestamp change must not introduce a new collision with another ID.
        my $old_time=CXGN::TimeUtils::normalize_db_timestamp($original_timestamp);
        if ($obs_db_id eq '' || ($timestamp // '') ne ($old_time // '')) {
            my $unique_observation = $self->check_unique_var_unit_time($schema, $trait_cvterm, $obsunit_db_id, $timestamp,
                $obs_db_id ne '' ? $obs_db_id : undef);
            if (!$unique_observation || $unique_observation->{error}) {
                return {error=>$unique_observation ? $unique_observation->{error} : 'Error validating that observations are unique'};
            }
        }
        push @observations, $obs_db_id if $obs_db_id ne '';

        push @unit_dbids, $obsunit_db_id;
        push @variables, $trait_name;
        if ($timestamp && defined $timestamp) {
            push @timestamps, $timestamp;
        }
        push @values, $value;

        my $references_error = CXGN::BrAPI::v2::ExternalReferences::validate_payload($external_references);
        return {error => $references_error->{error}} if $references_error;

        # track data for store
        push @{$data{$obsunit_db_id}->{$trait_name}}, [$value, $timestamp, $collector, $obs_db_id, undef, $additional_info,$external_references,$provided];
    }
    #print STDERR "Data is ".Dumper(%data)."\n";
    @observations = uniq @observations;
    @unit_dbids = uniq @unit_dbids;
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
    my $units_transform = $t->transform($schema, 'stock_ids_2_stocks', \@unit_dbids);
    my @unit_names = @{$units_transform->{'transform'}};
    # The common storage contract is keyed by stock name. Refuse ambiguity
    # before its name-to-ID guard can throw, even when this request used IDs.
    my $ambiguous_names=$schema->storage->dbh->selectcol_arrayref(
        'SELECT uniquename FROM stock WHERE uniquename=ANY(?) GROUP BY uniquename HAVING count(*)>1 ORDER BY uniquename',
        undef,\@unit_names);
    return {error=>'Observation unit names are ambiguous; correct the duplicate names before storing measurements: '.join(', ',@$ambiguous_names)} if @$ambiguous_names;


    my $validated_units = $validator->validate($schema,'plots_or_subplots_or_plants_or_tissue_samples',\@unit_names);
    my @units_missing = @{$validated_units->{'missing'}};
    if (scalar @units_missing) {
        $parse_result{'error'} = "The following observationUnitDbIds do not exist in the database: @units_missing";
        return \%parse_result;
    }

    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id;
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id;
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id;
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id;
    my $obsunit_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'stock_id' => { -in => \@unit_dbids },
        'type_id' => [$tissue_sample_cvterm_id, $plant_cvterm_id, $plot_cvterm_id, $subplot_cvterm_id]
    });
    my %found_observation_unit_names;
    while (my $r=$obsunit_rs->next){
        $found_observation_unit_names{$r->stock_id} = $r->uniquename;
    }

    my $validated_variables = $validator->validate($schema,'traits',\@variables);
    my @variables_missing = @{$validated_variables ->{'missing'}};
    if (scalar @variables_missing) {
        $parse_result{'error'} = "The following observationVariableDbIds do not exist in the database: @variables_missing";
        #print STDERR "Invalid observationVariableDbIds: @variables_missing\n";
        return \%parse_result;
    }


    my %formatted_data;
    while (my ($obs_db_id, $val) = each %data){
        $formatted_data{$found_observation_unit_names{$obs_db_id}} = $val;
    }

    $parse_result{'success'} = "Request data is valid";
    $parse_result{'data'} = \%formatted_data;
    $parse_result{'units'} = \@unit_names;
    $parse_result{'variables'} = \@variables;

    return \%parse_result;
}

1;
