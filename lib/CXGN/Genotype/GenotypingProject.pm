
=head1 NAME

CXGN::Genotype::GenotypingProject - an object representing a genotyping project in the database

=head1 DESCRIPTION

    my $genotyping_project = CXGN::Genotype::GenotypingProject->new( { schema => $schema, trial_id => 37347 });


=head1 AUTHORS

    Titima Tantikanjana

=head1 METHODS

=cut
package CXGN::Genotype::GenotypingProject;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
use CXGN::Trial::Search;
use Try::Tiny;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'project_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'project_facility' => (isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'project_and_plate_relationship_cvterm_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'genotyping_plate_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'new_genotyping_plate_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

sub BUILD {

    my $self = shift;
    my $schema = $self->bcs_schema();
    my $genotyping_project_id = $self->project_id();

    my $genotyping_project = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $genotyping_project_id });
    my $project_facility = $genotyping_project->get_genotyping_facility();

    my $genotyping_project_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_project_and_plate_relationship', 'project_relationship');
    my $project_and_plate_relationship_cvterm_id = $genotyping_project_relationship_cvterm->cvterm_id();
    my $relationships_rs = $schema->resultset("Project::ProjectRelationship")->search ({
        object_project_id => $genotyping_project_id,
        type_id => $project_and_plate_relationship_cvterm_id
    });

    my @plate_list;
    if ($relationships_rs) {
        while (my $each_relationship = $relationships_rs->next()) {
    	    push @plate_list, $each_relationship->subject_project_id();
        }
    }
    $self->project_facility($project_facility);
    $self->project_and_plate_relationship_cvterm_id($project_and_plate_relationship_cvterm_id);
    $self->genotyping_plate_list(\@plate_list);

}


sub get_genotyping_plate_ids {
    my $self = shift;
    my $plate_list = $self->genotyping_plate_list();
    return $plate_list;
}


sub validate_relationship {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $new_plate_ids = $self->new_genotyping_plate_list();
    my $genotyping_project_id = $self->project_id();
    my $project_facility = $self->project_facility();
    my @plate_ids = @$new_plate_ids;
    my @genotyping_plate_errors;

    foreach my $plate_id (@plate_ids) {
        my $genotyping_plate = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $plate_id });
        my $plate_facility = $genotyping_plate->get_genotyping_facility();

        if (($plate_facility ne 'None') && ($project_facility ne 'None')) {
            if ($plate_facility ne $project_facility) {
                my $genotyping_plate_name = $genotyping_plate->get_name();
                push @genotyping_plate_errors, $genotyping_plate_name;
            }
        }
    }

    return {error_messages => \@genotyping_plate_errors}
}


sub set_project_for_genotyping_plate {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $genotyping_project_id = $self->project_id();
    my $new_genotyping_plate_list = $self->new_genotyping_plate_list();
    my @new_genotyping_plates = @$new_genotyping_plate_list;
    my $transaction_error;

    my $coderef = sub {

        foreach my $plate_id (@new_genotyping_plates) {
            my $relationship_rs = $schema->resultset("Project::ProjectRelationship")->find ({
                subject_project_id => $plate_id,
                type_id => $self->project_and_plate_relationship_cvterm_id()
            });

            if($relationship_rs){
                print STDERR "UPDATING...."."\n";
                $relationship_rs->object_project_id($genotyping_project_id);
                $relationship_rs->update();
            } else {
                $relationship_rs = $schema->resultset('Project::ProjectRelationship')->create({
        		    object_project_id => $genotyping_project_id,
        		    subject_project_id => $plate_id,
        		    type_id => $self->project_and_plate_relationship_cvterm_id()
                });
                $relationship_rs->insert();
            }
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error associating genotyping plate: $transaction_error\n";
        return;
    }

    return 1;

}


sub get_plate_info {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $plate_list = $self->genotyping_plate_list();
    my $number_of_plates = scalar (@$plate_list);
    my $data;
    my $total_count;
    if ($number_of_plates > 0) {
        my $trial_search = CXGN::Trial::Search->new({
            bcs_schema => $schema,
            trial_design_list => ['genotyping_plate'],
            trial_id_list => $plate_list
        });
        ($data, $total_count) = $trial_search->search();
    }

    my @all_plates;
    foreach my $plate (@$data){
        my @sample_id_list = ();
        my $folder_string = '';
        if ($plate->{folder_name}){
            $folder_string = "<a href=\"/folder/$plate->{folder_id}\">$plate->{folder_name}</a>";
        }
        my $plate_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $plate->{trial_id}, experiment_type => 'genotyping_layout'});
        my $sample_names = $plate_layout->get_plot_names();
        my $number_of_samples = '';
        if ($sample_names){
            $number_of_samples = scalar(@{$sample_names});
        }

        if ($number_of_samples > 0) {
            foreach my $sample(@$sample_names) {
                my $sample_id = $schema->resultset("Stock::Stock")->find({ name => $sample })->stock_id();
                push @sample_id_list, $sample_id;
            }

            my $where_clause;
            my $query = join ("," , @sample_id_list);
            $where_clause = "nd_experiment_stock.stock_id in ($query)";
            my $q = "SELECT DISTINCT nd_experiment_stock.stock_id
                FROM nd_experiment_stock
                JOIN nd_experiment_genotype ON (nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id)
                JOIN genotypeprop ON (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
                WHERE $where_clause";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute();

            my @sample_with_data = ();
            while(my ($stock_id) = $h->fetchrow_array()){
                push @sample_with_data, [$stock_id];
            }

            my $number_of_samples_with_data = scalar(@sample_with_data);

            push @all_plates, {
                plate_id => $plate->{trial_id},
                plate_name => $plate->{trial_name},
                plate_description => $plate->{description},
                plate_format => $plate->{genotyping_plate_format},
                sample_type => $plate->{genotyping_plate_sample_type},
                folder_id => $plate->{folder_id},
                folder_name => $plate->{folder_name},
                number_of_samples => $number_of_samples,
                number_of_samples_with_data => $number_of_samples_with_data
            };
        }
    }

    return (\@all_plates, $number_of_plates);

}


1;
