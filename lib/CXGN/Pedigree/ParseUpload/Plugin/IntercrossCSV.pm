package CXGN::Pedigree::ParseUpload::Plugin::Intercross;

use Moose;
use File::Slurp;
use Text::CSV;

use Moose::Role;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;


sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $parent_type = shift;
    my $schema = shift;
    my $delimiter = ',';
    my %parse_result;
    my @error_messages;


    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header.\n";
        return \%parse_result;
    }

    #  Check headers
    if ($columns[0] ne 'crossDbId'){
            $parse_result{'error'} = "File contents incorrect. The first column must be crossDbId.";
            return \%parse_result;
        }

    if ($columns[1] ne 'femaleObsUnitDbId'){
        $parse_result{'error'} = "File contents incorrect. The second column must be femaleObsUnitDbId.";
        return \%parse_result;
    }

    if ($columns[2] ne 'maleObsUnitDbId'){
        $parse_result{'error'} = "File contents incorrect. The third column must be maleObsUnitDbId.";
        return \%parse_result;
    }

    if ($columns[3] ne 'timestamp'){
        $parse_result{'error'} = "File contents incorrect. The fourth column must be timestamp.";
        return \%parse_result;
    }

    if ($columns[4] ne 'person'){
        $parse_result{'error'} = "File contents incorrect. The fifth column must be person.";
        return \%parse_result;
    }

    if ($columns[5] ne 'experiment'){
        $parse_result{'error'} = "File contents incorrect. The sixth column must be experiment.";
        return \%parse_result;
    }

    if ($columns[6] ne 'type'){
        $parse_result{'error'} = "File contents incorrect. The seventh column must be type.";
        return \%parse_result;
    }

    if ($columns[7] ne 'fruits'){
        $parse_result{'error'} = "File contents incorrect. The eighth column must be fruits.";
        return \%parse_result;
    }

    if ($columns[8] ne 'flowers'){
        $parse_result{'error'} = "File contents incorrect. The ninth column must be flowers.";
        return \%parse_result;
    }

    if ($columns[9] ne 'seeds'){
        $parse_result{'error'} = "File contents incorrect. The tenth column must be seeds.";
        return \%parse_result;
    }

    if($parent_type ne 'accession' && $data_level ne 'plot' && $data_level ne 'plant'){
        $parse_result{'error'} = "You must specify if the parents are accessions, plots or plants.";
        return \%parse_result;
    }

    my %parent_names;
    while ( my $row = <$fh> ){
        my @column_values;
        if ($csv->parse($row)) {
            @column_values = $csv->fields();
        } else {
            $parse_result{'error'} = "Could not parse row $row.";
            print STDERR "Could not parse row $row.\n";
            return \%parse_result;
        }

        my $crossing_experiment_name = $column_values[5]
        my $crossing_experiment_rs = $schema->resultset("Project::Project")->find( { name => $crossing_experiment_name });

        if (!$crossing_experiment_rs) {
            $parse_result{'error'} = "Error! Crossing experiment: $crossing_experiment_name was not found in the database.\n";
            return \%parse_result;
    	}

        my $female_parent = $column_values[1];
        $parent_names{$female_parent}++;

        my $male_parent = $column_values[2];
        $parent_names{$male_parent}++;

    }

    my @parent_list = keys %parent_names;
    my $parent_validator = CXGN::List::Validate->new();

    if($parent_type eq 'accessions') {
        my @parents_missing = @{$parent_validator->validate($schema,'uniquenames',\@parent_list)->{'missing'}};
    }

    if($parent_type eq 'plots') {
        my @parents_missing = @{$parent_validator->validate($schema,'plots',\@parent_list)->{'missing'}};
    }

    if($parent_type eq 'plants') {
        my @parents_missing = @{$parent_validator->validate($schema,'plants',\@parent_list)->{'missing'}};
    }

    if (scalar(@parents_missing) > 0) {
        $parse_result{'error'} = "The following parents are not in the database, or are not in the database as uniquenames: ".join(',',@parents_missing);
        return \%parse_result;
    }

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $parent_type = shift;
    my $schema = shift;
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });
    my %data;

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header row.\n";
        return \%parse_result;
    }

    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            $parse_result{'error'} = "Could not parse row $row.";
            print STDERR "Could not parse row $row.\n";
            return \%parse_result;
        }

        my $transaction_id = $columns[0];
        my $female_parent = $columns[1];
        my $male_parent = $columns[2];
        my $timestamp = $columns[3];
        my $person = $columns[4];
        my $crossing_experiment = $columns[5];
        my $cross_type = $columns[6];
        my $number_of_fruits = $columns[7];
        my $number_of_flowers = $columns[8];
        my $number_of_seeds = $columns[9];

        my $cross_identifier = $crossing_experiment.'_'.$female_parent.'_'.$male_parent;
        my $data{$cross_identifier}{'crossing_experiment'} = $crossing_experiment;
        my $data{$cross_identifier}{'female_parent'} = $female_parent;
        my $data{$cross_identifier}{'male_parent'} = $male_parent;
        my $data{$cross_identifier}{'cross_type'} = $cross_type;
        my $data{$cross_identifier}{$transaction_id}{'fruits'} = $number_of_fruits;
        my $data{$cross_identifier}{$transaction_id}{'flowers'} = $number_of_flowers;
        my $data{$cross_identifier}{$transaction_id}{'seeds'} = $number_of_seeds;
    }

    $parse_result{'data'} = \%data;
    #print STDERR Dumper \%parse_result;

    return \%parse_result;
}

1;
