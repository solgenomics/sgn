
=head1 NAME

CXGN::Genotype::Delete - an object to delete plate, project or protocol genotyping data

=head1 DESCRIPTION

    my $genotyping_data_delete = CXGN::Genotype::Delete->new( { schema => $schema, plate_id => 37347 });


=head1 AUTHORS

    Titima Tantikanjana

=head1 METHODS

=cut
package CXGN::Genotype::Delete;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
use Try::Tiny;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Stock::TissueSample::Search;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'genotyping_project_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'genotyping_plate_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'empty_protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

sub delete_genotype_data {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $genotyping_project_id = $self->genotyping_project_id();
    my $genotyping_plate_id = $self->genotyping_plate_id();
    my $genotyping_protocol_id = $self->protocol_id();
    my $dbh = $schema->storage->dbh;
    my $empty_protocol_name;
    my $empty_protocol_id;

    eval {
        $dbh->begin_work();

        my $where_clause;
        my $experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

        if ($genotyping_plate_id) {
            my @plate_list = ();
            @plate_list = ($genotyping_plate_id);
            my $plate_samples = CXGN::Stock::TissueSample::Search->new({
                bcs_schema => $schema,
                plate_db_id_list => \@plate_list,
            });

            my $data = $plate_samples->get_sample_data();
            my $sample_list = $data->{sample_list};
            my $stock_ids = join ("," , @$sample_list);
            $where_clause = "nd_experiment_stock.stock_id in ($stock_ids)";

        } elsif ($genotyping_project_id) {
            $where_clause = "nd_experiment_project.project_id = $genotyping_project_id";
        } elsif ($genotyping_protocol_id) {
            $where_clause = "nd_experiment_protocol.nd_protocol_id = $genotyping_protocol_id";
        }

        my $q = "SELECT nd_experiment_genotype.nd_experiment_id, nd_experiment_genotype.genotype_id, nd_experiment_protocol.nd_protocol_id
            FROM nd_experiment
            JOIN nd_experiment_genotype ON (nd_experiment.nd_experiment_id = nd_experiment_genotype.nd_experiment_id) AND nd_experiment.type_id = ?
            JOIN nd_experiment_stock ON (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN nd_experiment_protocol ON (nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            WHERE $where_clause;
        ";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($experiment_cvterm_id);

        my @genotype_ids_to_delete;
        my @nd_experiment_ids_to_delete;
        my %check_protocol_ids;
        while (my ($nd_experiment_id, $genotype_id, $protocol_id) = $h->fetchrow_array()) {
            push @genotype_ids_to_delete, $genotype_id;
            push @nd_experiment_ids_to_delete, $nd_experiment_id;
            $check_protocol_ids{$protocol_id}++;
        }
#        print STDERR "GENOTYPE IDS TO DELETE =".Dumper(\@genotype_ids_to_delete)."\n";
#        print STDERR "ND EXPERIMENT IDS TO DELETE =".Dumper(\@nd_experiment_ids_to_delete)."\n";

        if (scalar (@genotype_ids_to_delete) > 0) {
            my $genotype_ids = join ("," , @genotype_ids_to_delete);
            my $genotype_q = "DELETE from genotype WHERE genotype_id IN ($genotype_ids);";
            my $h = $schema->storage->dbh()->prepare($genotype_q);
            $h->execute();
        }

        if (scalar (@nd_experiment_ids_to_delete) > 0) {
            my $nd_experiment_ids = join ("," , @nd_experiment_ids_to_delete);
            my $nd_experiment_ids_files_delete = "DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id IN ($nd_experiment_ids);";
            my $h2 = $schema->storage->dbh()->prepare($nd_experiment_ids_files_delete);
            $h2->execute();

            my $nd_experiment_ids_delete = "DELETE FROM nd_experiment WHERE nd_experiment_id IN ($nd_experiment_ids);";
            my $h3 = $schema->storage->dbh()->prepare($nd_experiment_ids_delete);
            $h3->execute();
        }

        my @protocol_ids = keys %check_protocol_ids;
        if (scalar (@protocol_ids) > 1) {

        } else {
            my $protocol_id = $protocol_ids[0];
            print STDERR "PROTOCOL ID =".Dumper($protocol_id)."\n";
            my $experiment_count = $schema->resultset('NaturalDiversity::NdExperimentProtocol')->search({nd_protocol_id => $protocol_id})->count();
            print STDERR "EXPERIMENT COUNT =".Dumper($experiment_count)."\n";
            if ($experiment_count == 0) {
                $empty_protocol_name = $schema->resultset("NaturalDiversity::NdProtocol")->find({nd_protocol_id => $protocol_id })->name();
                $empty_protocol_id = $protocol_id;
                print STDERR "EMPTY PROTOCOL NAME =".Dumper($empty_protocol_name)."\n";
            }
        }

#        foreach my $id (keys %check_protocol_ids) {
#            my $experiment_count = $schema->resultset('NaturalDiversity::NdExperimentProtocol')->search({nd_protocol_id => $id})->count();
#            print STDERR "EXPERIMENT COUNT =".Dumper($experiment_count)."\n";
#            if ($experiment_count == 0) {
#                my $delete_protocol_q = "DELETE from nd_protocol WHERE nd_protocol_id=?;";
#                my $delete_protocol_h = $schema->storage->dbh()->prepare($delete_protocol_q);
#                $delete_protocol_h->execute($id);
#            }
#        }
    };

    if ($@) {
        print STDERR "An error occurred while deleting genotyping data"."$@\n";
        $dbh->rollback();
        return $@;
    } else {
        $dbh->commit();
        if ($empty_protocol_id) {
            return {empty_protocol_name => $empty_protocol_name, empty_protocol_id => $empty_protocol_id};
        } else {
            return 0;
        }
    }
}


sub delete_empty_protocol {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $dbh = $schema->storage->dbh;
    my $empty_protocol_id = $self->empty_protocol_id();

    eval {
        $dbh->begin_work();

        my $experiment_count = $schema->resultset('NaturalDiversity::NdExperimentProtocol')->search({nd_protocol_id => $empty_protocol_id})->count();
        print STDERR "EXPERIMENT COUNT =".Dumper($experiment_count)."\n";
        if ($experiment_count == 0) {
            my $delete_protocol_q = "DELETE from nd_protocol WHERE nd_protocol_id=?;";
            my $delete_protocol_h = $schema->storage->dbh()->prepare($delete_protocol_q);
            $delete_protocol_h->execute($empty_protocol_id);
        }
    };

    if ($@) {
        print STDERR "An error occurred while deleting genotyping protocol"."$@\n";
        $dbh->rollback();
        return $@;
    } else {
        $dbh->commit();
        return 0;
    }

}



1;
