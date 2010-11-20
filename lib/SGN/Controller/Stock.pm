package SGN::Controller::Stock;

=head1 NAME

SGN::Controller::Stock - Catalyst controller for pages dealing with stocks (e.g. accession, poopulation, etc.)

=cut

use Moose;
use namespace::autoclean;

use CXGN::Login;
use CXGN::People::Person;

use HTML::FormFu;
use URI::FromHash 'uri';
use YAML::Any;
use SGN::View::Stock qw/stock_link/;

has 'schema' => (
is => 'rw',
isa => 'DBIx::Class::Schema',
required => 0,
);

has 'default_page_size' => (
is => 'ro',
default => 20,
);


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';




sub _validate_pair {
    my ($self,$c,$key,$value) = @_;
    $c->throw( message => "$value is not a valid value for $key" )
        if ($key =~ m/_id$/ and $value !~ m/\d+/);
}

sub search :Path('/stock/search') Args(0) {
    my ( $self, $c ) = @_;
    $self->schema( $c->dbic_schema('Bio::Chado::Schema','sgn_chado') );

    my $req = $c->req;
    my $form = $self->_build_form;

    $form->process( $req );

    my $results;
    if( $form->submitted_and_valid ) {
        $results = $self->_make_stock_search_rs( $c, $form );
    }

    $c->forward_to_mason_view(
        '/stock/search.mas',
        form => $form,
        results => $results,
        pagination_link_maker => sub {
            return uri( query => { %{$form->params}, page => shift } );
        },
    );
}


sub _build_form {
    my ($self) = @_;

    my $form = HTML::FormFu->new(Load(<<EOY));
      method: POST
      attributes:
        name: stock_search_form
        id: stock_search_form
      elements:
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

        # hidden form values for page and page size
          - type: Hidden
            name: page
            value: 1

          - type: Hidden
            name: page_size
            default: 20

          - type: Submit
            name: submit
EOY

    # set the stock type multi-select choices from the db
    $form->get_element({ name => 'stock_type'})->options( $self->_stock_types );
    $form->get_element({ name => 'organism'})->options( $self->_organisms );

    return $form;
}

# assembles a DBIC resultset for the search based on the submitted
# form values
sub _make_stock_search_rs {
    my ( $self, $c, $form ) = @_;

    my $rs = $self->schema->resultset('Stock::Stock');

    if( my $name = $form->param_value('stock_name') ) {
        $rs = $rs->search(
            {
                'lower(name)' => { like => '%'.lc( $name ).'%' } , },
            {
                'lower(uniquename)' => { like => '%'.lc( $name ).'%' },
            } );
    }
    if( my $type = $form->param_value('stock_type') ) {
        $self->_validate_pair($c,'type_id',$type);
        $rs = $rs->search({ 'type_id' => $type });
    }

    if( my $organism = $form->param_value('organism') ) {
        $self->_validate_pair( $c, 'organism_id', $organism );
        $rs = $rs->search({ 'organism_id' => $organism });
    }

    # page number and page size, and order by species name
    $rs = $rs->search( undef, {
            page => $form->param_value('page')      || 1,
            rows => $form->param_value('page_size') || $self->default_page_size,
            order_by => 'name',
    });

    return $rs;
}

sub _organisms {
    my ($self) = @_;
    my $ref =  [
        map [ $_->organism_id, $_->species ],
        $self->schema
    ->resultset('Stock::Stock')
    ->search_related('organism' , {}, 
             {select => [qw[ organism.organism_id species ]],
              group_by => [qw[ organism.organism_id species ]],
              order_by => 'species',
             },
    )
    ];
    # add an empty option 
    unshift @$ref , ['0', ''];
    return $ref;
}

sub _stock_types {
    my ($self) = @_;

    my $ref = [
        map [$_->cvterm_id,$_->name],
        $self->schema
    ->resultset('Stock::Stock')
    ->search_related(
        'type',
        {},
        { select => [qw[ cvterm_id type.name ]],
          group_by => [qw[ cvterm_id type.name ]],
          order_by => 'type.name',
        },
    )
    ];
    # add an empty option 
    unshift @$ref , ['0', ''];
    return $ref;
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

    my $stock = CXGN::Chado::Stock->new($self->schema, $stock_id);
    my $logged_user = $c->user;
    my $person_id = $logged_user->get_object->get_sp_person_id if $logged_user;
    my $curator = $logged_user->check_roles('curator') if $logged_user;
    my $submitter = $logged_user->check_roles('submitter') if $logged_user;

    my $dbh = $c->dbc->dbh;

    ##################

    ###Check if a stock page can be printed###

    # print message if stock_id is not valid
    unless ( ( $stock_id =~ m /^\d+$/ ) || ($action eq 'new' && !$stock_id) ) {
        $c->throw(is_error=>0,
                  message=>"No stock/accession exists for identifier $stock_id",
            );
    }
    if (  !$stock->get_object_row  || ($action ne 'new' && !$stock_id) ) {
        $c->throw(is_error=>0,
                  message=>"No stock/accession exists for identifier $stock_id",
            );
    }

    # print message if the stock is obsolete
    my $obsolete = $stock->get_is_obsolete();
    if ( $obsolete  && !$curator ) {
        $c->throw(is_error=>0,
                  title => 'Obsolete stock',
                  message=>"Stock $stock_id is obsolete!",
                  developer_message => 'only curators can see obsolete stock',
                  notify => 0,   #< does not send an error email
            );
    }
    # print message if stock_id does not exist
    if ( !$stock && $action ne 'new' && $action ne 'store' ) {
        $c->throw(is_error=>0, message=>'No stock exists for this identifier',);
    }

    ####################
    my $image_ids = $self->_stock_images($stock);
    my $is_owner;
    my $owner_ids = $self->_stock_owners($stock);
    if ( $stock && ($curator || $person_id && ( grep /^$person_id$/, @$owner_ids ) ) ) {
        $is_owner = 1;
    }
    ################
    $c->forward_to_mason_view('/stock/index.mas',  stockref=>{ action=> $action,  stock_id => $stock_id , curator=>$curator, submitter=>$submitter, person_id => $person_id, stock => $stock, schema=>$self->schema, dbh=>$dbh, image_ids=> $image_ids, is_owner => $is_owner } );
}

sub _stock_images {
    my ($self,$stock) = @_;
    my $image_id_type_id = $self->schema->resultset("Cv::Cvterm")->search( { name => 'sgn image_id' }, )->single->cvterm_id ;
    my $image_stockprops = $stock->get_object_row()->search_related("stockprops" , { type_id => $image_id_type_id }  );

    my @image_ids ;
    while ( my $ip =  $image_stockprops->next ) {
        push @image_ids, $ip->value ;
    }
    return \@image_ids;
}


sub _stock_owners {
    my ($self,$stock) = @_;
    my $person_id_type_id = $self->schema->resultset("Cv::Cvterm")->search( { name => 'sp_person_id' }, )->single->cvterm_id ;
    my $person_stockprops = $stock->get_object_row()->search_related("stockprops" , { type_id => $person_id_type_id }  );

    my @owner_ids ;
    while ( my $pp =  $person_stockprops->next ) {
        push @owner_ids, $pp->value ;
    }
    return \@owner_ids;
}
######
1;
######
