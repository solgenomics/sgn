package CXGN::Pedigree::ParseUpload::Plugin::CrossesGeneric;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $cross_additional_info = $self->get_cross_additional_info();

    my @error_messages;
    my %errors;
    my @optional_columns = ('male_parent', 'cross_combination');
    push @optional_columns, @$cross_additional_info;

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'cross_unique_id', 'cross_type', 'female_parent'],
        optional_columns => \@optional_columns,
        column_aliases => {
            'cross_unique_id' => ['cross unique id'],
            'cross_type' => ['cross type', 'type'],
            'female_parent' => ['female', 'female parent'],
            'male_parent' => ['male parent', 'male'],
            'cross_combination' => ['cross combination']
        }
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $additional_columns = $parsed->{additional_columns};

    # return if parsing error
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    if ( $additional_columns && scalar(@$additional_columns) > 0 ) {
        $errors{'error_messages'} = [
            "The following columns are not recognized: " . join(', ', @$additional_columns) . ". Please check the spreadsheet format for the allowed columns."
        ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    #currently supported cross types
    my %supported_cross_types;
    $supported_cross_types{'biparental'} = 1; #both parents required
    $supported_cross_types{'self'} = 1; #only female parent required
    $supported_cross_types{'open'} = 1; #only female parent required
    $supported_cross_types{'sib'} = 1; #both parents required but can be the same.
    $supported_cross_types{'bulk_self'} = 1; #only female population required
    $supported_cross_types{'bulk_open'} = 1; #only female population required
    $supported_cross_types{'bulk'} = 1; #both female population and male accession required
    $supported_cross_types{'doubled_haploid'} = 1; #only female parent required
    $supported_cross_types{'dihaploid_induction'} = 1; # ditto
    $supported_cross_types{'polycross'} = 1; #both parents required
    $supported_cross_types{'backcross'} = 1; #both parents required, parents can be cross or accession stock type

    my $seen_crosses = $parsed_values->{'cross_unique_id'};
    my $seen_cross_types = $parsed_values->{'cross_type'};
    my $seen_female_parents = $parsed_values->{'female_parent'};
    my $seen_male_parents = $parsed_values->{'male_parent'};
    my @all_parents;
    push @all_parents, @$seen_female_parents;
    push @all_parents, @$seen_male_parents;

    foreach my $type (@$seen_cross_types) {
        if (!exists $supported_cross_types{$type}) {
            push @error_messages, "Cross type not supported: $type. Cross type should be biparental, self, open, sib, bulk_self, bulk_open, backcross, polycross, doubled_haploid or dihaploid_induction";
        }
    }

    my $parent_validator = CXGN::List::Validate->new();
    my @parents_missing = @{$parent_validator->validate($schema,'accessions_or_populations_or_crosses_or_plots_or_plants',\@all_parents)->{'missing'}};

    if (scalar(@parents_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as accession names, population names, cross unique ids, plot names or plant names: ".join(',',@parents_missing);
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $seen_crosses }
    });

    while (my $r=$rs->next){
        push @error_messages, "Cross unique id already exists in database: ".$r->uniquename;
    }

    foreach my $row (@$parsed_data) {
        my $cross_name = $row->{'cross_unique_id'};
        my $female_parent = $row->{'female_parent'};
        my $male_parent = $row->{'male_parent'};
        my $cross_type = $row->{'cross_type'};
        my $line_number = $row->{'_row'};

        if ($female_parent eq $male_parent) {
            if ($cross_type ne 'self' && $cross_type ne 'sib' && $cross_type ne 'doubled_haploid' && $cross_type ne 'dihaploid_induction'){
                push @error_messages, "Female parent and male parent are the same on line $line_number, but cross type is not self, sib, doubled_haploid or dihaploid_induction.";
            }
        }
        if ($cross_type eq 'biparental') {
            if (!$male_parent){
                push @error_messages, "For $cross_name on line number $line_number, Cross Type is biparental, but no male parent given";
            }
        }
        if($cross_type eq 'backcross') {
            if (!$male_parent){
                push @error_messages, "For $cross_name on line number $line_number, Cross Type is backcross, but no male parent given";
            }
        }
        if($cross_type eq "sib") {
            if (!$male_parent){
                push @error_messages, "For $cross_name on line number $line_number, Cross Type is sib, but no male parent given";
            }
        }
        if($cross_type eq "polycross") {
            if (!$male_parent){
                push @error_messages, "For $cross_name on line number $line_number, Cross Type is polycross, but no male parent given";
            }
        }
        if($cross_type eq "bulk") {
            if (!$male_parent){
                push @error_messages, "For $cross_name on line number $line_number, Cross Type is bulk, but no male parent given";
            }
        }
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_parsed_data($parsed);
    return 1;

}

sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $parsed = $self->_parsed_data();
    my $parsed_data = $parsed->{data};
    my $cross_additional_info_headers = $self->get_cross_additional_info();
    my %cross_additional_info_hash;
    my @pedigrees;
    my %parsed_result;

    my $accession_stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();

    foreach my $row (@$parsed_data) {
        my $cross_name = $row->{'cross_unique_id'};
        my $female_parent = $row->{'female_parent'};
        my $male_parent = $row->{'male_parent'};
        my $cross_type = $row->{'cross_type'};
        my $cross_combination = $row->{'cross_combination'};

        my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$cross_name, cross_type=>$cross_type, cross_combination=>$cross_combination);

        my $female_rs = $schema->resultset("Stock::Stock")->find({uniquename => $female_parent});
        my $female_stock_id = $female_rs->stock_id();
        my $female_type_id = $female_rs->type_id();

        my $female_accession_name;
        my $female_accession_stock_id;
        if ($female_type_id == $plot_stock_type_id) {
            $female_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$female_stock_id, type_id=>$plot_of_type_id})->object_id();
            $female_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $female_accession_stock_id})->uniquename();
            my $female_plot_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
            $pedigree->set_female_plot($female_plot_individual);
        } elsif ($female_type_id == $plant_stock_type_id) {
            $female_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$female_stock_id, type_id=>$plant_of_type_id})->object_id();
            $female_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $female_accession_stock_id})->uniquename();
            my $female_plant_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
            $pedigree->set_female_plant($female_plant_individual);
        } else {
            $female_accession_name = $female_parent;
        }

        my $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $female_accession_name);
        $pedigree->set_female_parent($female_parent_individual);

        if ($male_parent) {
            my $male_accession_stock_id;
            my $male_accession_name;
            my $male_rs = $schema->resultset("Stock::Stock")->find({uniquename => $male_parent});
            my $male_stock_id = $male_rs->stock_id();
            my $male_type_id = $male_rs->type_id();

            if ($male_type_id == $plot_stock_type_id) {
                $male_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$male_stock_id, type_id=>$plot_of_type_id})->object_id();
                $male_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $male_accession_stock_id})->uniquename();
                my $male_plot_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
                $pedigree->set_male_plot($male_plot_individual);
            } elsif ($male_type_id == $plant_stock_type_id) {
                $male_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$male_stock_id, type_id=>$plant_of_type_id})->object_id();
                $male_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $male_accession_stock_id})->uniquename();
                my $male_plant_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
                $pedigree->set_male_plant($male_plant_individual);
            } else {
                $male_accession_name = $male_parent
            }

            my $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $male_accession_name);
            $pedigree->set_male_parent($male_parent_individual);
        }

        push @pedigrees, $pedigree;

        foreach my $additional_info (@$cross_additional_info_headers) {
            if ($row->{$additional_info}) {
                $cross_additional_info_hash{$cross_name}{$additional_info} = $row->{$additional_info};
            }
        }
    }

    $parsed_result{'additional_info'} = \%cross_additional_info_hash;

    $parsed_result{'crosses'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
