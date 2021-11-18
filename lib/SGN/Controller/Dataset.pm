
package SGN::Controller::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller' };


sub view_dataset :Path('/dataset/view') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $dataset = CXGN::Dataset->new( { schema => $schema, people_schema => $people_schema, dataset_id => $dataset_id });

    $c->stash->{dataset_id} = $dataset_id;
    $c->stash->{dataset_name}  = $dataset->name();
    $c->stash->{template}  = '/dataset/index.mas';
}

1;
