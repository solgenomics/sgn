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
use CXGN::Tools::Organism;
use CXGN::Phenome::Locus::LinkageGroup;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';


has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);



sub locus_search : Path('/search/locus') Args(0) { 
    my $self = shift;
    my $c = shift;
    my ($organism_names_ref, $organism_ids_ref)=CXGN::Tools::Organism::get_existing_organisms( $c->dbc->dbh);
    
    unshift @$organism_names_ref, '';
    unshift @$organism_ids_ref, '';
    my @organism_ref;
    my $index;
    for my $id ( @$organism_ids_ref ) {
	push( @organism_ref, [$id, $organism_names_ref->[$index]] );
	$index++;
    }
    my $lg_names_ref =  CXGN::Phenome::Locus::LinkageGroup::get_all_lgs( $c->dbc->dbh );
    $c->stash(
	template       => '/search/loci.mas',
	organism_ref   => \@organism_ref,
	lg_names_ref   => $lg_names_ref,
	);
}



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


sub view_by_name : Path('/locus/view/') Args(0) { 

    my ($self, $c) = @_;

    my $symbol = $c->req->param("symbol");
    my $locusname  = $c->req->param("locus");
    my $species = $c->req->param("species");

    my $locus_id = undef;
    my $locus = undef;
    if ($symbol && $species) { 
        $locus = $c->stash->{locus} = CXGN::Phenome::Locus->new_with_symbol_and_species($c->dbc->dbh, $symbol, $species);
    }

    if ($locusname) {
        $locus = $c->stash->{locus} = CXGN::Phenome::Locus->new_with_locusname($c->dbc->dbh, $locusname);
    }
    
    if (defined($locus) && defined($locus->get_locus_id())) { 
        $locus_id = $locus->get_locus_id();
        my $url = "/locus/$locus_id/view";
        $c->res->redirect($url, 301);
    }
    else { 
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "No locus was found for the identifier provided ($symbol $locusname $species).";
        # forward to search page ?
    }


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
#    my $curator     = $logged_user->check_roles('curator') if $logged_user;
    #    my $submitter   = $logged_user->check_roles('submitter') if $logged_user;

    my $curator = $c->stash->{access}->grant( $c->stash->{user_id}, "write", "loci");
    my $submitter = $c->stash->{access}->grant( $c->stash->{user_id}, "write", "loci");
    
    my $sequencer   = $logged_user->check_roles('sequencer') if $logged_user;
    my $dbh = $c->dbc->dbh;

    my $trait_db_name => $c->get_conf('trait_ontology_db_name');
    ##################

    ###Check if a locus page can be printed###
    my $locus_id = $locus ? $locus->get_locus_id : undef ;

    print STDERR "LOCUS_ID: $locus_id ACTION: $action\n\n";

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
    my $dbxrefs = $self->locus_dbxrefs_by_db( $c );
    my $pubs = $self->_locus_pubs( $c);
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
    my ($feature, $src_feature) = $locus->get_src_feature;
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
	    pubs      => $pubs,
            cview_tmp_dir  => $cview_tmp_dir,
            cview_basepath => $c->get_conf('basepath'),
            image_ids      => $image_ids,
            xrefs      => \@locus_xrefs,
	    trait_db_name => $trait_db_name,
	    feature     => $feature,
	    src_feature => $src_feature,
        },
        locus_add_uri  => $c->uri_for( '/ajax/locus/associate_locus' )->relative(),
        cvterm_add_uri => $c->uri_for( '/ajax/locus/associate_ontology')->relative(),
        assign_owner_uri  => $c->uri_for( '/ajax/locus/assign_owner' )->relative(),
        );
}


=head1 PRIVATE ACTIONS

=head2 get_locus

Chain root for fetching a locus object to operate on.

Path part: /locus/<locus_id>

=cut

sub get_locus : Chained('/')  PathPart('locus')  CaptureArgs(1) {
    my ($self, $c, $locus_id) = @_;
    
    my $identifier_type = $c->stash->{identifier_type}
        || $locus_id =~ /[^-\d]/ ? 'locus' : 'locus_id';
    
    if( $identifier_type eq 'locus_id' ) {
        if ( $locus_id == 0 ) { 
	    $c->stash->{locus}     = CXGN::Phenome::Locus->new($c->dbc->dbh);
	    return 1;
	} elsif ( $locus_id < 0 ) {
	    $c->throw_client_error( public_message => 'Locus ID must be a positive integer.' );
	}
    }
    #remove version numbers from locus name locus123.1.2
    while ( $locus_id =~ m/.*\.\d+/ ) {
	$locus_id =~ s/(.*)(\.\d+)/$1/ ;
    }

    my $matching_loci = $self->schema->resultset('Locus')->search(
	{
	    $identifier_type => $locus_id,
	    obsolete         => 'f'
	} );
    
    if( $matching_loci->count > 1 ) {
        $c->throw_client_error( public_message => 'Multiple matching loci' );
    }    
    
    my ( $locus ) = $matching_loci->all
	or $c->throw_404( "Locus not found" );
    my $found_locus_id = $locus->locus_id;
    
    $c->stash->{locus}     = CXGN::Phenome::Locus->new($c->dbc->dbh, $found_locus_id);


    return 1;
}




sub get_locus_owner_ids : Private {
    my ( $self, $c ) = @_;
    my $locus = $c->stash->{locus};
    my @owner_ids = $locus ? $locus->get_owners : ();
    $c->stash->{owner_ids} = \@owner_ids;
}

sub get_locus_owner_objects : Private {
    my ( $self, $c ) = @_;
    my $locus = $c->stash->{locus};
    my $owner_objects = $locus ? $locus->get_owners(1) : ();
    $c->stash->{owner_objects} = $owner_objects;
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

sub locus_dbxrefs_by_db : Private {
    my ( $self, $c ) = @_;
    my $locus = $c->stash->{locus};
    my %locus_dbxrefs = $locus->get_all_dbxrefs;
    $c->stash->{locus_dbxrefs_by_db} = \%locus_dbxrefs;
}


sub _locus_pubs : Private {
    my ($self, $c ) = @_;
    my  $dbxrefs  = $c->stash->{locus_dbxrefs_by_db};

    my @sorted_pubs =  ${$dbxrefs}{PMID} ? sort { $a->[0]->get_accession() <=> $b->[0]->get_accession() } @{ ${$dbxrefs}{PMID} } : () ;
    my @sgn_ref =  ${$dbxrefs}{SGN_ref} ? @{ ${$dbxrefs}{SGN_ref} } : () ;

    my @cxgn_pubs;
    my @pub_dbxrefs = ( @sorted_pubs, @sgn_ref );
    foreach my $d ( @pub_dbxrefs) {
	if ( $d->[1] eq '0') { #if the dbxref is not obsolete
	    my $pub = CXGN::Chado::Publication->new( $c->dbc->dbh, $d->[0]->get_publication()->get_pub_id() );
	    push @cxgn_pubs, $pub;
	}
    }
    $c->stash->{pubs} = \@cxgn_pubs;
}
__PACKAGE__->meta->make_immutable;
