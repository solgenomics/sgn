package SGN::Controller::Locus;

=head1 NAME

SGN::Controller::Locus - Catalyst controller for the locus page
(replacing the old cgi script)

=cut

use Moose;
use namespace::autoclean;

use URI::FromHash 'uri';

use CXGN::Phenome::Locus;
use CXGN::Phenome::Schema;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';


has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);

sub _build_schema {
    shift->_app->dbic_schema( 'CXGN::Phenome::Schema' )
}


=head2 new_locus

Public path: /locus/0/new

Create a new locus.

Chained off of L</get_locus> below.

=cut

sub new_locus : Chained('get_locus') PathPart('new') Args(0) {
    my ( $self, $c ) = @_;
    $c->stash(
        template => '/locus/index.mas',

        locusref => {
            action    => "new",
            locus_id  => 0 ,
            locus     => $c->stash->{locus},
            schema    => $self->schema,
        },
        );
}

=head2 view_locus

Public path: /locus/<locus_id>/view

View a locus detail page.

Chained off of L</get_locus> below.

=cut

sub view_locus : Chained('get_locus') PathPart('view') Args(0) {
    my ( $self, $c, $action) = @_;
    my $locus = $c->stash->{locus};
    if( $locus ) {
        $c->forward('get_locus_extended_info');
    }

    my $logged_user = $c->user;
    my $person_id   = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $curator     = $logged_user->check_roles('curator') if $logged_user;
    my $submitter   = $logged_user->check_roles('submitter') if $logged_user;
    my $sequencer   = $logged_user->check_roles('sequencer') if $logged_user;
    my $dbh = $c->dbc->dbh;

    ##################

    ###Check if a locus page can be printed###
    my $locus_id = $locus ? $locus->get_locus_id : undef ;

    # print message if locus_id is not valid
    unless ( ( $locus_id =~ m /^\d+$/ ) || ($action eq 'new' && !$locus_id) ) {
        $c->throw_404( "No locus exists for that identifier." );
    }
    unless ( $locus || !$locus_id && $action && $action eq 'new' ) {
        $c->throw_404( "No locus exists for that identifier." );
    }

    # print message if the locus is obsolete
    my $obsolete = $locus->get_obsolete();
    if ( $obsolete eq 't'  && !$curator ) {
        $c->throw(is_client_error => 0,
                  title             => 'Obsolete locus',
                  message           => "Locus $locus_id is obsolete!",
                  developer_message => 'only curators can see obsolete loci',
                  notify            => 0,   #< does not send an error email
            );
    }
    # print message if locus_id does not exist
    if ( !$locus && $action ne 'new' && $action ne 'store' ) {
        $c->throw_404('No locus exists for this identifier');
    }

    ####################
    my $is_owner;
    my $owner_ids = $c->stash->{owner_ids} || [] ;
    if ( $locus && ($curator || $person_id && ( grep /^$person_id$/, @$owner_ids ) ) ) {
        $is_owner = 1;
    }
    my $dbxrefs = $locus->get_dbxrefs;
    my $image_ids = $locus->get_figure_ids;
    my $cview_tmp_dir = $c->tempfiles_subdir('cview');

    #########
    my @locus_xrefs =
        # 4. look up xrefs for all of them
        map $c->feature_xrefs( $_, { exclude => 'locuspages' } ),
        # 3. plus primary locus name
        $locus->get_locus_name,
        # 2. list of locus alias strings
        map $_->get_locus_alias,
        # 1. list of locus alias objects
        $locus->get_locus_aliases( 'f', 'f' );
    #########
################
    $c->stash(
        template => '/locus/index.mas',
        locusref => {
            action    => $action,
            locus_id  => $locus_id ,
            curator   => $curator,
            submitter => $submitter,
            sequencer => $sequencer,
            person_id => $person_id,
            user      => $logged_user,
            locus     => $locus,
            dbh       => $dbh,
            is_owner  => $is_owner,
            owners    => $owner_ids,
            dbxrefs   => $dbxrefs,
            cview_tmp_dir  => $cview_tmp_dir,
            cview_basepath => $c->get_conf('basepath'),
            image_ids      => $image_ids,
            xrefs      => \@locus_xrefs,
        },
        locus_add_uri  => $c->uri_for( '/ajax/locus/associate_locus' ),
        cvterm_add_uri => $c->uri_for( '/ajax/locus/associate_ontology')
        );
}


=head1 PRIVATE ACTIONS

=head2 get_locus

Chain root for fetching a locus object to operate on.

Path part: /locus/<locus_id>

=cut

sub get_locus : Chained('/')  PathPart('locus')  CaptureArgs(1) {
    my ($self, $c, $locus_id) = @_;

    $c->stash->{locus}     = CXGN::Phenome::Locus->new($c->dbc->dbh, $locus_id);
}



sub get_locus_owner_ids : Private {
    my ( $self, $c ) = @_;
    my $locus = $c->stash->{locus};
    my $owner_ids = $locus ? $locus->get_owners : undef;
    $c->stash->{owner_ids} = $owner_ids;
}


sub get_locus_extended_info : Private {
    my ( $self, $c ) = @_;
    $c->forward('get_locus_owner_ids');


}

#add the locus_dbxrefs to the stash.
sub get_locus_dbxrefs : Private {
    my ( $self, $c ) = @_;
    my $locus = $c->stash->{locus};
    my $locus_dbxrefs = $locus->get_dbxrefs;
    $c->stash->{locus_dbxrefs} = $locus_dbxrefs;
}
__PACKAGE__->meta->make_immutable;
