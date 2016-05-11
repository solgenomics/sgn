
=head1 NAME

SGN::Controller::AJAX::GenotypeProtocol - a REST controller class to provide the
backend for retrieving genotype protocol (map) data.

=head1 DESCRIPTION

Viewing genotype protocol (map) data.

=head1 AUTHOR

Nicolas Morales nm529@cornell.edu

=cut

package SGN::Controller::AJAX::GenotypeProtocol;

use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);


sub get_folder : Chained('/') PathPart('ajax/folder') CaptureArgs(1) {
    my $c = shift;
    my $self = shift;

    my $folder_id = shift;
    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{folder_id} = $folder_id;

}
