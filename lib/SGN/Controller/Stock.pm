package SGN::Controller::Stock;

=head1 NAME

SGN::Controller::Stock - Catalyst controller for pages dealing with stocks (e.g. accession, poopulation, etc.)

=cut

use Moose;
use namespace::autoclean;
use YAML::Any;

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

    my $results = $c->req->param('search_submitted') ? $self->_make_stock_search_rs($c) : undef;
    my $form = HTML::FormFu->new(Load(<<EOY));
method: GET
action: "/stock/search"
attributes:
    name: stock_search_form
    id: stock_search_form
javascript:
    function toggle_advanced() {
            jQuery('div[class*="advanced"]').toggle();
    }
    jQuery(function(){ jQuery("#advanced_toggle").click(
        function(){
        toggle_advanced();
        });
    });
    jQuery(function() {
        if( jQuery("input#advanced_toggle").attr('checked') ) {
            toggle_advanced();
        }
    });
elements:
    - type: Checkbox
      name: advanced
      label: Advanced
      id: advanced_toggle
      default: 0

    - type: Text
      name: stock_name
      label: Stock name
      size: 30

    - type: Select
      name: stock_type
      label: Stock type

    - type: Select
      name: organism
      label: Organism

    - type: Hidden
      name: search_submitted
      value: 1

    # hidden form values for page and page size
    - type: Hidden
      name: page
      value: 1

    - type: Hidden
      name: page_size
      default: 20

    - type: Text
      name: person
      id: person
      label: Editor
      container_attributes:
        class: advanced

    - type: Text
      name: trait
      id: trait
      label: Trait
      size: 40
      container_attributes:
        class: advanced

    - type: Text
      name: min_limit
      id: min_limit
      label: Min. value
      size: 5
      container_attributes:
        class: advanced

    - type: Text
      name: max_limit
      id: max_limit
      label: Max. value
      size: 5
      container_attributes:
        class: advanced

    - type: Submit
      name: submit
      value: Search
EOY

    $c->stash(
        template                   => '/stock/search.mas',
        request                    => $c->req,
        form                       => $form,
        form_opts                  => { stock_types => stock_types($self->schema), organisms => stock_organisms($self->schema)} ,
        results                    => $results,
        sp_person_autocomplete_uri => $c->uri_for( '/ajax/people/autocomplete' ),
        trait_autocomplete_uri     => $c->uri_for('/ajax/stock/trait_autocomplete'),
        pagination_link_maker      => sub {
            return uri( query => { %{$c->req->params} , page => shift } );
        },
    );
}


# assembles a DBIC resultset for the search based on the submitted
# form values
sub _make_stock_search_rs {
    my ( $self, $c ) = @_;

    my $rs = $self->schema->resultset('Stock::Stock');

    if( my $name = $c->req->param('stock_name') ) {
        # trim and regularize whitespace
        $name =~ s/(^\s+|\s+)$//g;
        $name =~ s/\s+/ /g;

        $rs = $rs->search({
            -or => [
                 'lower(me.name)' => { like => '%'.lc( $name ).'%' } ,
                 'lower(uniquename)' => { like => '%'.lc( $name ).'%' },
                 -and => [
                     'lower(type.name)' => { like =>'%synonym%' },
                     'lower(value)' => { like =>'%'.lc( $name ).'%' },
                 ],
                ],
                          } ,
               {  join =>  { 'stockprops' =>  'type'  }  }, );
    }
    if( my $type = $c->req->param('stock_type') ) {
        $self->_validate_pair($c,'type_id',$type);
        $rs = $rs->search({ 'me.type_id' => $type });
    }
    if( my $organism = $c->req->param('organism') ) {
        $self->_validate_pair( $c, 'organism_id', $organism );
        $rs = $rs->search({ 'organism_id' => $organism });
    }
    if ( my $editor = $c->req->param('person') ) {
        $self->_validate_pair( $c, 'person') ;
        my ($first_name, $last_name) = split ',' , $editor ;
        $first_name  =~ s/\s//g;
        $last_name  =~ s/\s//g;

        my $query = "SELECT sp_person_id FROM sgn_people.sp_person
                     WHERE first_name = ? AND last_name = ?";
        my $sth = $c->dbc->dbh->prepare($query);
        $sth->execute($first_name, $last_name);
        my ($sp_person_id) = $sth->fetchrow_array ;
        if ($sp_person_id) {
            $rs = $rs->search( {
                'type.name' => 'sp_person_id',
                'stockprops.value' => $sp_person_id, } ,
                               { join => { stockprops =>['type'] } },
                ) ; # if no person_id, rs should be empty
        } else { $rs = $rs->search( { name=> '' } , ); }
    }
    # page number and page size, and order by name
    $rs = $rs->search( undef, {
        page => $c->req->param('page')  || 1,
        rows => $c->req->param('page_size') || $self->default_page_size,
        order_by => 'name',
                       });
    return $rs;
}


# sub view_id :Path('/stock/view/id') :Args(1) {
#     my ( $self, $c , $stock_id) = @_;

#     $self->schema( $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' ) );
#     $self->_view_stock($c, 'view', $stock_id);
# }


sub new_stock :Chained('get_stock') : PathPart('new') :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash(
        template => '/stock/index.mas',

        stockref => {
            action    => "new",
            stock_id  => 0 ,
            stock     => $c->stash->{stock},
            schema    => $self->schema,
        },
        );
}


sub view_stock :Chained('get_stock') :PathPart('view') :Args(0) {
    my ( $self, $c, $action) = @_;
    my $logged_user = $c->user;
    my $person_id = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $curator = $logged_user->check_roles('curator') if $logged_user;
    my $submitter = $logged_user->check_roles('submitter') if $logged_user;
    my $sequencer = $logged_user->check_roles('sequencer') if $logged_user;

    my $dbh = $c->dbc->dbh;

    ##################

    ###Check if a stock page can be printed###

    my $stock = $c->stash->{stock};
    my $stock_id = $stock ? $stock->get_stock_id : undef ;

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
    my $owner_ids = $props->{sp_person_id} || [] ;
    if ( $stock && ($curator || $person_id && ( grep /^$person_id$/, @$owner_ids ) ) ) {
        $is_owner = 1;
    }
    my $dbxrefs = $self->_dbxrefs($stock);

    my $nd_experiments = $self->_stock_nd_experiments($stock);
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
            owners    => $owner_ids,
            nd_experiments => $nd_experiments,
        },
        locus_add_uri  => $c->uri_for( '/ajax/stock/associate_locus' ),
        cvterm_add_uri => $c->uri_for( '/ajax/stock/associate_ontology')
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


sub _dbxrefs {
    my ($self,$stock) = @_;

    my $stock_dbxrefs = $stock->get_object_row()->search_related("stock_dbxrefs");

    my $dbxrefs ;
    while ( my $sdbxref =  $stock_dbxrefs->next ) {
        my $url = $sdbxref->dbxref->db->urlprefix . $sdbxref->dbxref->db->url;

        my $accession = $sdbxref->dbxref->accession;
        $url = $url ? qq |<a href = "$url/$accession">$accession</a>| : $accession ;
        push @{ $dbxrefs->{$sdbxref->dbxref->db->name} } , $sdbxref->dbxref;
    }
    return $dbxrefs;
}

sub _stock_nd_experiments {
    my ($self, $stock) = @_;

    my $nd_experiments = $stock->get_object_row->nd_experiment_stocks->search_related('nd_experiment');
    return $nd_experiments;
}

sub _stock_dbxrefs {
    my ($self,$stock) = @_;

    my $stock_dbxrefs = $stock->get_object_row()->search_related("stock_dbxrefs");
    # hash of arrays. Keys are db names , values are lists of StockDbxref objects
    my $sdbxrefs ;
    while ( my $sdbxref =  $stock_dbxrefs->next ) {
        push @{ $sdbxrefs->{$sdbxref->dbxref->db->name} } , $sdbxref;
    }
    return $sdbxrefs;
}
sub get_stock :Chained('/') :PathPart('stock') :CaptureArgs(1) {
    my ($self, $c, $stock_id) = @_;

    $self->schema( $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' ) );
    $c->stash->{stock} = CXGN::Chado::Stock->new($self->schema, $stock_id);

    #add the stockprops to the stash. Props are a hashref of lists.
    # keys are the cvterm name (prop type) and values  are the prop values.
    my $stock = $c->stash->{stock};
    my $properties = $stock ?  $self->_stockprops($stock) : undef ;
    $c->stash->{stockprops} = $properties;

    #add the stock_dbxrefs to the stash. Dbxrefs are hashref of lists.
    # keys are db-names , values are lists of Bio::Chado::Schema::General::Dbxref objects
    my $dbxrefs  = $stock ?  $self->_stock_dbxrefs($stock) : undef ;
    $c->stash->{stock_dbxrefs} = $dbxrefs;
}

######
1;
######
