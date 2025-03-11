package SGN::Controller::Publication;

=head1 NAME

SGN::Controller::Publication - Catalyst controller for the SGN publication page
(replacing the old cgi script)

=cut

use Moose;
use namespace::autoclean;
use File::Slurp;

use URI::FromHash 'uri';

use CXGN::Chado::Publication ;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';


has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);



sub pub_search : Path('/search/publication') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->stash(
	template       => '/search/pub.mas',
	
	);
}


sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}


=head2 new_pub

Public path: /pub/0/new

Create a new publication.

Chained off of L</get_pub> below.

=cut

sub new_pub : Chained('get_pub') PathPart('new') Args(0) {
    my ( $self, $c ) = @_;
    $c->stash(
        template => '/publication/index.mas',

        pubref => {
            action    => "new",
            pub_id  => 0 ,
            pub       => $c->stash->{pub},
            schema    => $self->schema,
        },
        );
}

=head2 view_by_doi

Public path: /doi/pub/

View publication by doi.

Since DOIs can have "/" in them this path captures 3 args and then concatenates to recreate the DOI (hopefully no DOI has more than 3 slashes! ) 

=cut


sub view_by_doi : Path('/doi/pub/') CaptureArgs(3) {
    my ($self, $c , @doi_parts) = @_;
    my $doi = join '/' , @doi_parts;
    my $matching_pubs = $self->schema->resultset('Pub::Pub')->search(
	    {
		'dbxref.accession' => $doi,
	    }, {
		join => { 'pub_dbxrefs' => 'dbxref' },
	    } );
    
    if( $matching_pubs->count > 1 ) {
        $c->throw_client_error( public_message => 'Multiple matching publications' );
    }    
    
    my ( $publication ) = $matching_pubs->all
	or $c->throw_404( "publication $doi  not found" );
    my $found_pub_id = $publication->pub_id;
    my $pub =  CXGN::Chado::Publication->new($c->dbc->dbh, $found_pub_id);
    $c->{stash}->{pub} = $pub;

    my $logged_user = $c->user;
    my $person_id   = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $curator     = $c->stash->{access}->grant( $c->stash->{user_id}, "write", "loci"); #$logged_user->check_roles('curator') if $logged_user;
    my $submitter   = $c->stash->{access}->grant( $c->stash->{user_id}, "read", "loci"); # $logged_user->check_roles('submitter') if $logged_user;
    my $sequencer   = 0; #$logged_user->check_roles('sequencer') if $logged_user;
    my $dbh = $c->dbc->dbh;
    my $dbxrefs = $pub->get_dbxrefs;
    my $stocks = $self->_get_stocks( $c);

     $c->stash(
        template => '/publication/index.mas',
        pubref => {
	    pub_id    => $found_pub_id ,
            curator   => $curator,
            submitter => $submitter,
            sequencer => $sequencer,
            person_id => $person_id,
	    pub       => $pub,
            dbh       => $dbh,
            dbxrefs   => $dbxrefs,
	    doi       => $doi,
	    stocks    => $stocks,
	 },
	 );
}
    


=head2 view_pub

Public path: /publication/<pub_id>/view

View a publication detail page.

Chained off of L</get_pub> below.

=cut

sub view_pub : Chained('get_pub') PathPart('view') Args(0) {
    my ( $self, $c, $action) = @_;
    my $pub = $c->stash->{pub};
   

    my $logged_user = $c->user;
    my $person_id   = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $curator     = $c->stash->{access}->grant( $c->stash->{user_id}, "write", "loci"); #$logged_user->check_roles('curator') if $logged_user;
    my $submitter   = $c->stash->{access}->grant( $c->stash->{user_id}, "read", "loci"); # $logged_user->check_roles('submitter') if $logged_user;
    my $sequencer   = 0; #$logged_user->check_roles('sequencer') if $logged_user;

#    my $curator     = $logged_user->check_roles('curator') if $logged_user;
 #   my $submitter   = $logged_user->check_roles('submitter') if $logged_user;
  #  my $sequencer   = $logged_user->check_roles('sequencer') if $logged_user;
    my $dbh = $c->dbc->dbh;

    ##################

    ###Check if a publication page can be printed###
    my $pub_id = $pub ? $pub->get_pub_id : undef ;

    # print message if pub_id is not valid
    unless ( ( $pub_id =~ m /^\d+$/ ) || ($action eq 'new' && !$pub_id) ) {
        $c->throw_404( "No publication exists for that identifier." );
    }
    unless ( $pub || !$pub_id && $action && $action eq 'new' ) {
        $c->throw_404( "No publication exists for that identifier." );
    }

    # print message if pub_id does not exist
    if ( !$pub && $action ne 'new' && $action ne 'store' ) {
        $c->throw_404('No publication exists for this identifier');
    }

    ####################
   
    my $dbxrefs = $pub->get_dbxrefs;
    my $stocks = $self->_get_stocks( $c );
    #########
    ################
    $c->stash(
        template => '/publication/index.mas',
        pubref => {
            action    => $action,
            pub_id  => $pub_id ,
            curator   => $curator,
            submitter => $submitter,
            sequencer => $sequencer,
            person_id => $person_id,
            user      => $logged_user,
            pub       => $pub,
            dbh       => $dbh,
            dbxrefs   => $dbxrefs,
	    stocks    => $stocks,
        },
        );
}


=head1 PRIVATE ACTIONS

=head2 get_pub

Chain root for fetching a publication object to operate on.

Path part: /publication/<pub_id>

=cut

sub get_pub : Chained('/')  PathPart('publication')  CaptureArgs(1) {
    my ($self, $c, $pub_id) = @_;
  
    my $identifier_type = $c->stash->{identifier_type}
        || $pub_id =~ /[^-\d]/ ? 'accession' : 'pub_id';
    
    if( $identifier_type eq 'pub_id' ) {
        if ( $pub_id == 0 ) {
	    $c->stash->{pub} = CXGN::Chado::Publication->new($c->dbc->dbh);
	    return 1;
	}
	$pub_id > 0
            or $c->throw_client_error( public_message => 'Publication ID must be a positive integer.' );
    }
    my $matching_pubs;
    
    if ($identifier_type eq 'pub_id' ) {
	$matching_pubs =  $self->schema->resultset('Pub::Pub')->search(
	    {
		pub_id => $pub_id,
	    } );
    }
    if( $matching_pubs->count > 1 ) {
        $c->throw_client_error( public_message => 'Multiple matching publications' );
    }    
    
    my ( $publication ) = $matching_pubs->all
	or $c->throw_404( "publication $pub_id  not found" );
    my $found_pub_id = $publication->pub_id;

    $c->stash->{pub} = CXGN::Chado::Publication->new($c->dbc->dbh, $found_pub_id);

    return 1;
}



sub _get_stocks {
    my ( $self, $c)  = @_;
    my $pub = $c->stash->{pub};
    my $schema = $self->schema;
    my @stock_ids = $pub->get_stock_ids;
    my @stocks;
    foreach my $stock_id (@stock_ids) {
	my $stock = CXGN::Stock->new( { schema => $schema, stock_id => $stock_id } ) ;
	push @stocks, $stock;
    }
    return \@stocks;
}



=head2 doi_banner

Public path: /doibanner/

Return SGN logo if DOI exists, or a 1x1 empty pixel if does not exist.
Used by Elsevier for banner linking publications to solgenomics publication page /pub/doi/<doi>

=cut


sub doi_banner : Path('/doibanner/') CaptureArgs(3) {
    my ($self, $c , @doi_parts) = @_;
    my $doi = join '/' , @doi_parts;
    my $matching_pubs = $self->schema->resultset('Pub::Pub')->search(
	    {
		'dbxref.accession' => $doi,
	    }, {
		join => { 'pub_dbxrefs' => 'dbxref' },
	    } );
    my $pub_count = $matching_pubs->count;
    if( $matching_pubs->count > 1 ) {
        $c->throw_client_error( public_message => 'Multiple matching publications' );
    }

    my $image = $c->path_to('/documents/img/white_pixel.png');

    if ($pub_count == 1 ) {
	$image = $c->path_to( '/documents/img/sgn_logo_26x60.png') ;
    }
      
    my $image_file = read_file($image , { binmode => ':raw' } );
    
    $c->response->content_type('image/png');
    $c->response->body($image_file);

}

__PACKAGE__->meta->make_immutable;
