package CXGN::Pedigree::ParseUpload::Plugin::Intercross;

use Moose;
use File::Slurp;
use Text::CSV;

use Moose::Role;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;


sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
#    my $parent_type = $self->get_data_level();
    my $parent_type = 'accessions';
    my $delimiter = ',';
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $errors{'error_messages'} = "Could not read file.";
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $errors{'error_messages'} = "Could not parse header row.";
        $self->_set_parse_errors(\%errors);
        return;
    }

    #  Check headers
    if ($columns[0] ne 'crossDbId'){
        push @error_messages, "File contents incorrect. The first column must be crossDbId.";
    }

    if ($columns[1] ne 'femaleObsUnitDbId'){
        push @error_messages, "File contents incorrect. The second column must be femaleObsUnitDbId.";
    }

    if ($columns[2] ne 'maleObsUnitDbId'){
        push @error_messages, "File contents incorrect. The third column must be maleObsUnitDbId.";
    }

    if ($columns[3] ne 'timestamp'){
        push @error_messages, "File contents incorrect. The fourth column must be timestamp.";
    }

    if ($columns[4] ne 'person'){
        push @error_messages, "File contents incorrect. The fifth column must be person.";
    }

    if ($columns[5] ne 'experiment'){
        push @error_messages, "File contents incorrect. The sixth column must be experiment.";
    }

    if ($columns[6] ne 'type'){
        push @error_messages, "File contents incorrect. The seventh column must be type.";
    }

    if ($columns[7] ne 'fruits'){
        push @error_messages, "File contents incorrect. The eighth column must be fruits.";
    }

    if ($columns[8] ne 'flowers'){
        push @error_messages, "File contents incorrect. The ninth column must be flowers.";
    }

    if ($columns[9] ne 'seeds'){
        push @error_messages, "File contents incorrect. The tenth column must be seeds.";
    }

    if($parent_type ne 'accession' && $data_level ne 'plot' && $data_level ne 'plant'){
        push @error_messages, "You must specify if the parents are accessions, plots or plants.";
    }

    my %parent_names;
    while ( my $row = <$fh> ){
        my @column_values;
        if ($csv->parse($row)) {
            @column_values = $csv->fields();
        } else {
            $errors{'error_messages'} = "Could not parse row $row.";
            $self->_set_parse_errors(\%errors);
            return;
        }

        my $crossing_experiment_name = $column_values[5]
        my $crossing_experiment_rs = $schema->resultset("Project::Project")->find( { name => $crossing_experiment_name });

        if (!$crossing_experiment_rs) {
            push @error_messages, "Error! Crossing experiment: $crossing_experiment_name was not found in the database.\n";
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
        push @error_messages, "The following parents are not in the database, or are not in the database as uniquenames: ".join(',',@parents_missing);
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1;
}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
#    my $parent_type = $self->get_data_level();
    my $parent_type = 'accessions';
    my $schema = $self->get_chado_schema();
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });
    my %data;

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        return;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        return;
    }

    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            return;
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
    print STDERR "DATA =".Dumper(\%parse_result)."\n";

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}

1;
