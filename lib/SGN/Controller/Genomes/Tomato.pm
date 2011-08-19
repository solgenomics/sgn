package SGN::Controller::Genomes::Tomato;
use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class 'Dir';

use CXGN::People::BACStatusLog;

BEGIN { extends 'Catalyst::Controller' }

has 'bac_publish_subdir' => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
    );

sub clone_sequencing : Chained('/organism/find_organism') PathPart('clone_sequencing') {
    my ( $self, $c ) = @_;
    $c->throw_404 unless lc $c->stash->{organism}->common_name eq 'tomato';

    my $dbh = $c->dbc->dbh;
    my $log = CXGN::People::BACStatusLog->new( $dbh );

    $c->stash(
        template => '/genomes/Solanum_lycopersicum/clone_sequencing.mas',
        dbh      => $c->dbc->dbh,
        chrnum   => $c->req->params->{chr} || 1,
        basepath => $c->get_conf('basepath'),
        cview_tempfiles_subdir => $c->tempfiles_subdir('cview'),
        bac_by_bac_progress => $log->bac_by_bac_progress_statistics,
        bac_publish_subdir => $self->bac_publish_subdir,
       );
}


1;
