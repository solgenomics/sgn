
package SGN::Controller::Dataset;

use Moose;
use CXGN::Dataset;

BEGIN { extends 'Catalyst::Controller'; }

sub dataset :Chained('/') Path('dataset') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    
    my $dataset = CXGN::Dataset->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id=> $dataset_id,
    });

    $c->stash->{dataset_name} = $dataset->name();
    $c->stash->{dataset_id} = $dataset_id;
    print STDERR "dataset name ".$dataset->name();
    $c->stash->{template} = '/dataset/index.mas';
    
}



1;
