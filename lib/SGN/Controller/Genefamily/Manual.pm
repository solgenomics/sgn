package SGN::Controller::Genefamily::Manual;


=head1 NAME

SGN::Controller::Genefamily::Manual - Catalyst controller for pages dealing with
manually curated gene families (aka 'locusgroup')

=cut

use Moose;

BEGIN { extends "Catalyst::Controller"; }
with 'Catalyst::Component::ApplicationAttribute';


has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);

sub _build_schema {
    shift->_app->dbic_schema( 'CXGN::Phenome::Schema' )
}

=head2 view_genefamily

Public path: /genefamily/manual/<locusgroup_id>/view

View a gene family (locusgroup) detail page.

Chained off of L</get_genefamily> below.

=cut

sub view_genefamily : Chained('get_genefamily') PathPart('view') Args(0) {
    my ( $self, $c, $action) = @_;
    my $genefamily = $c->stash->{genefamily};
    if( $genefamily ) {
        $c->forward('get_genefamily_extended_info');
    }

    my $logged_user = $c->user;
    my $person_id   = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $curator     = $logged_user->check_roles('curator') if $logged_user;
    my $submitter   = $logged_user->check_roles('submitter') if $logged_user;
    my $sequencer   = $logged_user->check_roles('sequencer') if $logged_user;
    my $dbh = $c->dbc->dbh;

    ##################

    ###Check if a gene family page can be printed###
    my $genefamily_id = $genefamily ? $genefamily->get_locusgroup_id : undef ;

    # print message if locusgroup_id is not valid
    unless ( $genefamily_id =~ m /^\d+$/ )  {
        $c->throw_404( "No gene family exists for that identifier." );
    }
    unless ( $genefamily ) {
        $c->throw_404( "No gene family  exists for that identifier." );
    }
    ####################
    my $is_owner;
    my $owner_id = $c->stash->{owner_id} || undef ;
    if ( $genefamily && ($curator || $person_id && ( $person_id == $owner_id ) ) ) {
        $is_owner = 1;
    }
    my $members = $genefamily->get_locusgroup_members;
    #########
    ################
    $c->stash(
        template => '/genefamily/manual/index.mas',
        hashref => {
            action    => $action,
            genefamily => $genefamily,
            curator   => $curator,
            submitter => $submitter,
            sequencer => $sequencer,
            person_id => $person_id,
            user      => $logged_user,
            genefamily     => $genefamily,
            dbh       => $dbh,
            is_owner  => $is_owner,
            members   => $members,
        },
        locus_add_uri  => $c->uri_for( '/ajax/locus/associate_locus' ),
        );
}


=head1 PRIVATE ACTIONS

=head2 get_genefamily

Chain root for fetching a locusgroup object to operate on.

Path part: /genefamily/manual/<locusgroup_id>

=cut

sub get_genefamily : Chained('/')  PathPart('genefamily/manual')  CaptureArgs(1) {
    my ($self, $c, $locusgroup_id) = @_;
    $c->stash->{genefamily} = CXGN::Phenome::LocusGroup->new($self->schema, $locusgroup_id);
}


sub get_genefamily_extended_info : Private {
    my ( $self, $c ) = @_;
    #$c->forward('get_genefamily_members');
}


__PACKAGE__->meta->make_immutable;
