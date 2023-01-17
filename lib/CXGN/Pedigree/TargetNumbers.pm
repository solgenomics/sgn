package CXGN::Pedigree::TargetNumbers;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;
use Bio::Chado::Schema;
use Data::Dumper;
use JSON;
use CXGN::Stock::StockLookup;

has 'chado_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
	predicate => 'has_chado_schema',
	required => 1,
);

has 'crossing_experiment_id' => (
    isa =>'Int',
    is => 'rw',
    predicate => 'has_crossing_experiment_id',
    required => 1
);

has 'target_numbers' => (
    isa => 'HashRef',
    is => 'rw'
);


sub store {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $crossing_experiment_id = $self->get_crossing_experiment_id();
    my $target_numbers = $self->get_target_numbers();
    my %new_target_numbers_hash = %{$target_numbers};
    my $transaction_error;
    my $coderef = sub {

        my $experiment_rs = $schema->resultset("Project::Project")->find({project_id => $crossing_experiment_id });
        if (!$experiment_rs) {
            print STDERR "Crossing experiment does not exist in the database\n";
            return;
        }

        my $target_numbers_json;
        my $target_numbers_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'target_numbers_json', 'project_property');
        my $experiment_prop_rs = $schema->resultset("Project::Projectprop")->find({project_id => $crossing_experiment_id, type_id => $target_numbers_cvterm->cvterm_id()});
        if ($experiment_prop_rs){
            my $experiment_prop_id = $experiment_prop_rs->projectprop_id();
            my $previous_value = $experiment_prop_rs->value();
            my $previous_target_info = decode_json $previous_value;
            print STDERR "PREVIOUS TARGET INFO =".Dumper($previous_target_info)."\n";
            my %all_target_info = (%{$previous_target_info}, %new_target_numbers_hash);
            print STDERR "UPDATED TARGET INFO =".Dumper(\%all_target_info)."\n";
            $target_numbers_json = encode_json \%all_target_info;
            $experiment_prop_rs->update({value=>$target_numbers_json});

        } else {
            $target_numbers_json = encode_json \%new_target_numbers_hash;
            $experiment_rs->create_projectprops({$target_numbers_cvterm->name() => $target_numbers_json});
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error storing target numbers: $transaction_error\n";
        return;
    }

    return 1;

}


sub get_target_numbers_and_progress {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $crossing_experiment_id = $self->get_crossing_experiment_id();

    my $target_numbers_json;
    my $target_numbers_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'target_numbers_json', 'project_property');
    my $crossing_experiment_prop_rs = $schema->resultset("Project::Projectprop")->find({project_id => $crossing_experiment_id, type_id => $target_numbers_cvterm->cvterm_id()});
    my $checkmark = qq{<img src="/img/checkmark_green.jpg"/>};

    my @crossing_experiment_target_numbers;
    if ($crossing_experiment_prop_rs){
        my $prop_value = $crossing_experiment_prop_rs->value();
        my $target_info = decode_json $prop_value;
        my %target_numbers_hash = %{$target_info};

        foreach my $female_accession( sort keys %target_numbers_hash) {
            my $female_details = $target_numbers_hash{$female_accession};
            my %female_hash = %{$female_details};
            foreach my $male_accession (sort keys %female_hash) {
                my $seed_target_number = $female_hash{$male_accession}{'target_number_of_seeds'};
                my $progeny_target_number = $female_hash{$male_accession}{'target_number_of_progenies'};
                my $cross_info = $self->_get_cross_and_info($crossing_experiment_id, $female_accession, $male_accession);

                my @cross_array = @$cross_info;
                my $total_number_of_seeds;
                my $total_number_of_progenies;
                my @crosses = ();
                foreach my $cross (@cross_array) {
                    if ($seed_target_number) {
                        $total_number_of_seeds += $cross->[2];
                    }
                    if ($progeny_target_number) {
                        $total_number_of_progenies += $cross->[3];
                    }

                    my $cross_link = qq{<a href="/cross/$cross->[1]">$cross->[0]</a>};
                    push @crosses, $cross_link;
                }
                my $crosses_string = join("<br>", @crosses);

                if (($seed_target_number) && ($total_number_of_seeds >= $seed_target_number)) {
                    $seed_target_number = $seed_target_number.$checkmark;
                }

                if (($progeny_target_number) && ($total_number_of_progenies >= $progeny_target_number)) {
                    $progeny_target_number = $progeny_target_number.$checkmark;
                }

                push @crossing_experiment_target_numbers, [$female_accession, $male_accession, $seed_target_number, $total_number_of_seeds, $progeny_target_number, $total_number_of_progenies, $crosses_string];
            }
        }
    }

    return \@crossing_experiment_target_numbers;

}


sub _get_cross_and_info {
    my $self = shift;
    my $crossing_experiment_id = shift;
    my $female_accession = shift;
    my $male_accession = shift;
    my $schema = $self->get_chado_schema();
    my $female;
    my $female_id;
    my $male;
    my $male_id;
    my $cross_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $female_parent_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id=  SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $cross_info_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_metadata_json', 'stock_property')->cvterm_id();
    my $cross_experiment_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id();
    my $offspring_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "offspring_of", "stock_relationship")->cvterm_id();

    my $female_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    $female_lookup->set_stock_name($female_accession);
    $female = $female_lookup->get_accession_exact();
    if (!$female) {
        print STDERR "female accession name does not exist\n";
        return;
    } else {
        $female_id =  $female->stock_id();
    }

    my $male_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    $male_lookup->set_stock_name($male_accession);
    $male = $male_lookup->get_accession_exact();

    if (!$male) {
        print STDERR "male accession name does not exist\n";
        return;
    } else {
        $male_id =  $male->stock_id();
    }

    my $q = "SELECT info_table.cross_name, info_table.cross_id, info_table.prop_value, progenies_table.number_of_progenies
        FROM
        (SELECT cross_entry.uniquename AS cross_name, cross_entry.stock_id AS cross_id, stockprop.value AS prop_value
        FROM nd_experiment_project JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id) AND nd_experiment_stock.type_id = ?
        LEFT JOIN stock AS cross_entry ON (cross_entry.stock_id = nd_experiment_stock.stock_id) AND cross_entry.type_id = ?
        LEFT JOIN stockprop ON (cross_entry.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stock_relationship AS female_relationship ON (female_relationship.object_id = cross_entry.stock_id) AND female_relationship.type_id = ?
        LEFT JOIN stock_relationship AS male_relationship ON (male_relationship.object_id = cross_entry.stock_id) AND male_relationship.type_id = ?
        WHERE nd_experiment_project.project_id = ? AND female_relationship.subject_id = ? AND male_relationship.subject_id = ?) AS info_table
        LEFT JOIN
        (SELECT DISTINCT stock.stock_id AS cross_id, COUNT (stock_relationship.subject_id) AS number_of_progenies
        FROM nd_experiment_project JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id)
        LEFT JOIN stock_relationship ON (stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        WHERE nd_experiment_project.project_id = ? GROUP BY cross_id) AS progenies_table
        ON (info_table.cross_id = progenies_table.cross_id) ORDER BY cross_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($cross_experiment_type_id, $cross_type_id, $cross_info_type_id, $female_parent_type_id, $male_parent_type_id, $crossing_experiment_id, $female_id, $male_id, $offspring_of_type_id, $crossing_experiment_id);

    my @cross_details = ();
    while (my ($cross_name, $cross_id, $cross_info, $number_of_progenies) = $h->fetchrow_array()){
        my $number_of_seeds;
        if ($cross_info) {
            my $info_hash = decode_json $cross_info;
            $number_of_seeds = $info_hash->{'Number of Seeds'};
        }
        push @cross_details, [$cross_name, $cross_id,  $number_of_seeds, $number_of_progenies]
    }
#    print STDERR Dumper(\@cross_details);

    return \@cross_details;
}



1;
