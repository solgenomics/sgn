package SGN::Controller::Stock;

=head1 NAME

SGN::Controller::Stock - Catalyst controller for pages dealing with stocks (e.g. accession, poopulation, etc.)

=cut

use Moose;
use namespace::autoclean;

use URI::FromHash 'uri';

use CXGN::Chado::Stock;
use SGN::View::Stock qw/stock_link stock_organisms stock_types/;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 0,
);

has 'default_page_size' => (
    is      => 'ro',
    default => 20,
);


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

sub _validate_pair {
    my ($self,$c,$key,$value) = @_;
    $c->throw( is_client_error => 1, public_message => "$value is not a valid value for $key" )
        if ($key =~ m/_id$/ and $value !~ m/\d+/);
}

sub search :Path('/stock/search') Args(0) {
    my ( $self, $c ) = @_;
    $self->schema( $c->dbic_schema('Bio::Chado::Schema','sgn_chado') );

    my $req = $c->req;

    my $results;
    $results = $self->_make_stock_search_rs( $c, $req ) if $req->param('submit');

    $c->stash(
        template  => '/stock/search.mas',
        request   => $req,
        form_opts => { stock_types=>stock_types($self->schema), organisms=>stock_organisms($self->schema)} ,
        results   => $results,
        pagination_link_maker => sub {
            return uri( query => { %{$req}, page => shift } );
        },
    );
}


# assembles a DBIC resultset for the search based on the submitted
# form values
sub _make_stock_search_rs {
    my ( $self, $c, $req ) = @_;

    my $rs = $self->schema->resultset('Stock::Stock');
    my $rs_synonyms;

    if( my $name = $req->param('stock_name') ) {
        $rs = $rs->search({
            -or => [
                 'lower(me.name)' => { like => '%'.lc( $name ).'%' } ,
                 'lower(uniquename)' => { like => '%'.lc( $name ).'%' },
              #   -and => [
              #       'lower(type.name)' => { like =>'%synonym%' },
              #       'lower(value)' => { like =>'%'.lc( $name ).'%' },
              #   ],
              #  ], },
              #            {  join => { 'stockprops' => 'type' } },
                ], } ,
            );
        #add the stockprop values here
        $rs_synonyms =  $self->schema->resultset('Cv::Cvterm')->search( {
            'lower(me.name)' => { like =>'%synonym%' } , } )->search_related('stockprops', {
                'lower(value)' => { like =>'%'.lc( $name ).'%' } , } )->
                    search_related('stock');

    }
    if( my $type = $req->param('stock_type') ) {
        $self->_validate_pair($c,'type_id',$type);
        $rs = $rs->search({ 'type_id' => $type });
    }

    if( my $organism = $req->param('organism') ) {
        $self->_validate_pair( $c, 'organism_id', $organism );
        $rs = $rs->search({ 'organism_id' => $organism });
    }

    # page number and page size, and order by name
    $rs = $rs->search( undef, {
        page => $req->param('page')      || 1,
        rows => $req->param('page_size') || $self->default_page_size,
        order_by => 'name',
                       });
    return $rs;
}


sub view_id :Path('/stock/view/id') :Args(1) {
    my ( $self, $c , $stock_id) = @_;

    $self->schema( $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' ) );
    $self->_view_stock($c, 'view', $stock_id);
}


sub new_stock :Path('/stock/view/new') :Args(0) {
    my ( $self, $c , $stock_id) = @_;
    $self->schema( $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' ) );
    $self->_view_stock($c, 'new', $stock_id);
}


sub _view_stock {
    my ( $self, $c, $action, $stock_id) = @_;

    my $stock       = CXGN::Chado::Stock->new($self->schema, $stock_id);
    my $logged_user = $c->user;
    my $person_id = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $curator = $logged_user->check_roles('curator') if $logged_user;
    my $submitter = $logged_user->check_roles('submitter') if $logged_user;
    my $sequencer = $logged_user->check_roles('sequencer') if $logged_user;

    my $dbh = $c->dbc->dbh;

    ##################

    ###Check if a stock page can be printed###

    # print message if stock_id is not valid
    unless ( ( $stock_id =~ m /^\d+$/ ) || ($action eq 'new' && !$stock_id) ) {
        $c->throw_404( "No stock/accession exists for identifier $stock_id" );
    }
    if (  !$stock->get_object_row  || ($action ne 'new' && !$stock_id) ) {
        $c->throw_404( "No stock/accession exists for identifier $stock_id" );
    }

    # print message if the stock is obsolete
    my $obsolete = $stock->get_is_obsolete();
    if ( $obsolete  && !$curator ) {
        $c->throw(is_client_error => 0,
                  title             => 'Obsolete stock',
                  message           => "Stock $stock_id is obsolete!",
                  developer_message => 'only curators can see obsolete stock',
                  notify            => 0,   #< does not send an error email
            );
    }
    # print message if stock_id does not exist
    if ( !$stock && $action ne 'new' && $action ne 'store' ) {
        $c->throw_404('No stock exists for this identifier');
    }

    ####################
    my $props = $self->_stockprops($stock);
    my $is_owner;
    my $owner_ids = $props->{sp_perons_id} || [] ;
    if ( $stock && ($curator || $person_id && ( grep /^$person_id$/, @$owner_ids ) ) ) {
        $is_owner = 1;
    }
    my $dbxrefs = $self->_stock_dbxrefs($stock);

    ################
    $c->stash(
        template => '/stock/index.mas',

        stockref => {
            action    => $action,
            stock_id  => $stock_id ,
            curator   => $curator,
            submitter => $submitter,
            sequencer => $sequencer,
            person_id => $person_id,
            stock     => $stock,
            schema    => $self->schema,
            dbh       => $dbh,
            is_owner  => $is_owner,
            props     => $props,
            dbxrefs   => $dbxrefs,
        },
       );
}

sub _stockprops {
    my ($self,$stock) = @_;


    my $stockprops = $stock->get_object_row()->search_related("stockprops");

    my $properties ;
    while ( my $prop =  $stockprops->next ) {
        push @{ $properties->{$prop->type->name} } ,   $prop->value ;
    }
    return $properties;
}


sub _stock_dbxrefs {
    my ($self,$stock) = @_;

    my $stock_dbxrefs = $stock->get_object_row()->search_related("stock_dbxrefs");

    my $dbxrefs ;
    while ( my $sdbxref =  $stock_dbxrefs->next ) {
        my $url = $sdbxref->dbxref->db->urlprefix . $sdbxref->dbxref->db->url;

        my $accession = $sdbxref->dbxref->accession;
        $url = $url ? qq |<a href = "$url/$accession">$accession</a>| : $accession ;
        push @{ $dbxrefs->{$sdbxref->dbxref->db->name} } , $accession ;
    }
    return $dbxrefs;
}
######
1;
######
