package CXGN::Pedigree::TargetNumbers;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;
use Bio::Chado::Schema;
use Data::Dumper;
use JSON;

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
    is => 'rw',
    required => 1
);


sub store {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $crossing_experiment_id = $self->get_crossing_experiment_id();
    my $target_numbers = $self->get_target_numbers();
    my %target_numbers_hash = %{$target_numbers};
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
            %target_numbers_hash = %{$previous_target_info};
            $target_numbers_json = encode_json \%target_numbers_hash;

            $experiment_prop_rs->update({value=>$target_numbers_json});

        } else {
            $target_numbers_json = encode_json \%target_numbers_hash;
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





1;
