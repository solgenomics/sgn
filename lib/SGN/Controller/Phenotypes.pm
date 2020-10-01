package SGN::Controller::Phenotypes;

=head1 NAME

SGN::Controller::Phenotypes - Catalyst controller for pages dealing with
phenotypes submission and associating them with project, experiments, and stock accessions.

=cut

use Moose;
use namespace::autoclean;
use YAML::Any qw/LoadFile/;

use URI::FromHash 'uri';
use List::Compare;
use File::Temp qw / tempfile /;
use File::Slurp;
use JSON::Any;

use CXGN::Chado::Stock;
use SGN::View::Stock qw/stock_link stock_organisms stock_types/;


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

has 'default_page_size' => (
    is      => 'ro',
    default => 20,
);

=head1 PUBLIC ACTIONS

=head2 submission_guidelines

Public path: /phenotype/submission_guide

Display the phenotype submission guidelines page

=cut

sub submission_guidelines :Path('/phenotype/submission_guide') Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => '/phenotypes/submission_guide.mas');

}

#
return 1;
#
