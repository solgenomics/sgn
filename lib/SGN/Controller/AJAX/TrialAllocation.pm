package SGN::Controller::AJAX::Allocation;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use File::Path qw(rmtree);
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::MixedModels;
use SGN::Controller::AJAX::Dataset;
use JSON;


BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );


sub accession_lists :Path('/ajax/trialallocation/accession_lists') Args(0) {
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $sp_person_id = $c->user ? $c->user->get_object->get_sp_person_id : undef;

    if (!$sp_person_id) {
        $c->stash->{rest} = { error => 'Not logged in' };
        return;
    }

    # Get cvterm_id for 'accessions' in 'list_types'
    my $accession_type_id = $schema->resultset('Cv::Cvterm')->find({ name => 'accessions' })->cvterm_id;

    # Use CXGN::List::all_lists
    my $lists = CXGN::List::all_lists($dbh, $sp_person_id, 'accessions');

    my @formatted = map {
        {
            list_id   => $_->[0],
            name      => $_->[1],
            desc      => $_->[2],
            count     => $_->[3],
            type_id   => $_->[4],
            type_name => $_->[5],
            is_public => $_->[6]
        }
    } @$lists;

    $c->stash->{rest} = { success => 1, lists => \@formatted };
}


1;