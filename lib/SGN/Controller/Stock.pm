package SGN::Controller::Stock;

=head1 NAME

SGN::Controller::Stock - Catalyst controller for pages dealing with
stocks (e.g. accession, population, etc.)

=cut

use Moose;
use namespace::autoclean;
use YAML::Any qw/LoadFile/;

use URI::FromHash 'uri';

use CXGN::Chado::Stock;
use SGN::View::Stock qw/stock_link stock_organisms stock_types/;


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    default  => sub {
        shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
    },
);

has 'default_page_size' => (
    is      => 'ro',
    default => 20,
);

=head1 PUBLIC ACTIONS

=head2 search

Public path: /stock/search

Display a stock search form, or handle stock searching.

=cut

sub search :Path('/stock/search') Args(0) {
    my ( $self, $c ) = @_;

    my $results = $c->req->param('search_submitted') ? $self->_make_stock_search_rs($c) : undef;
    my $form = HTML::FormFu->new(LoadFile($c->path_to(qw{forms stock stock_search.yaml})));

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

=head2 new_stock

Public path: /stock/0/new

Create a new stock.

Chained off of L</get_stock> below.

=cut

sub new_stock : Chained('get_stock') PathPart('new') Args(0) {
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


=head2 view_stock

Public path: /stock/<stock_id>/view

View a stock's detail page.

Chained off of L</get_stock> below.

=cut

sub view_stock : Chained('get_stock') PathPart('view') Args(0) {
    my ( $self, $c, $action) = @_;

    $c->forward('get_stock_extended_info');

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
    unless ( $stock->get_object_row || !$stock_id && $action && $action eq 'new' ) {
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
    my $pubs = $self->_stock_pubs($stock);
    my $image_ids = $self->_stock_images($stock);
    my $cview_tmp_dir = $c->tempfiles_subdir('cview');
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
            pubs      => $pubs,
            members_phenotypes => $c->stash->{members_phenotypes},
            direct_phenotypes  => $c->stash->{direct_phenotypes},
            has_qtl_data   => $c->stash->{has_qtl_data},
            cview_tmp_dir  => $cview_tmp_dir,
            cview_basepath => $c->get_conf('basepath'),
            image_ids      => $image_ids,
        },
        locus_add_uri  => $c->uri_for( '/ajax/stock/associate_locus' ),
        cvterm_add_uri => $c->uri_for( '/ajax/stock/associate_ontology')
        );
}

=head1 PRIVATE ACTIONS

=head2 get_stock

Chain root for fetching a stock object to operate on.

Path part: /stock/<stock_id>

=cut

sub get_stock : Chained('/')  PathPart('stock')  CaptureArgs(1) {
    my ($self, $c, $stock_id) = @_;

    $c->stash->{stock}     = CXGN::Chado::Stock->new($self->schema, $stock_id);
    $c->stash->{stock_row} = $self->schema->resultset('Stock::Stock')
                                  ->find({ stock_id => $stock_id });
}

#add the stockprops to the stash. Props are a hashref of lists.
# keys are the cvterm name (prop type) and values  are the prop values.
sub get_stock_cvterms : Private {
    my ( $self, $c ) = @_;
    my $stock = $c->stash->{stock};
    my $properties = $stock ?  $self->_stockprops($stock) : undef ;
    $c->stash->{stockprops} = $properties;
}

sub get_stock_extended_info : Private {
    my ( $self, $c ) = @_;
    $c->forward('get_stock_cvterms');

    # look up the stock again, this time prefetching a lot of data about its related stocks
    $c->stash->{stock_row} = $self->schema->resultset('Stock::Stock')
                                  ->find({ stock_id => $c->stash->{stock_row}->stock_id },
                                         { prefetch => {
                                             'stock_relationship_objects' => [ { 'subject' => 'type' }, 'type'],
                                           },
                                         },
                                        );

    my $stock = $c->stash->{stock};

    #add the stock_dbxrefs to the stash. Dbxrefs are hashref of lists.
    # keys are db-names , values are lists of Bio::Chado::Schema::General::Dbxref objects
    my $dbxrefs  = $stock ?  $self->_stock_dbxrefs($stock) : undef ;
    $c->stash->{stock_dbxrefs} = $dbxrefs;

    my $cvterms  = $stock ?  $self->_stock_cvterms($stock) : undef ;
    $c->stash->{stock_cvterms} = $cvterms;

    my $direct_phenotypes  = $stock ? $self->_stock_project_phenotypes( $c->stash->{stock_row} ) : undef;
    $c->stash->{direct_phenotypes} = $direct_phenotypes;

    my ($members_phenotypes, $has_members_genotypes)  = $stock ? $self->_stock_members_phenotypes( $c->stash->{stock_row} ) : undef;
    $c->stash->{members_phenotypes} = $members_phenotypes;

    my $allele_ids = $stock ? $self->_stock_allele_ids($stock) : undef;
    $c->stash->{allele_ids} = $allele_ids;

    my $stock_type;
    $stock_type = $stock->get_object_row->type->name if $stock->get_object_row;
    if ( ( grep { /^$stock_type/ } ('f2 population', 'backcross population') ) &&  $members_phenotypes && $has_members_genotypes ) { $c->stash->{has_qtl_data} = 1 ; }

}

############## HELPER METHODS ######################3

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
               {  join =>  { 'stockprops' =>  'type'  }  ,
                  columns => [ qw/stock_id uniquename type_id organism_id / ],
                  distinct => 1
               }
            );
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
        $editor =~ s/,/ /g;
        $editor =~ s/\s+/ /g;

        my $person_ids = $c->dbc->dbh->selectcol_arrayref(<<'', undef, $editor);
SELECT sp_person_id FROM sgn_people.sp_person
WHERE ( first_name || ' ' || last_name ) like '%' || ? || '%'

        if (@$person_ids) {
            $rs = $rs->search({
                      'type.name'        => 'sp_person_id',
                      'stockprops.value' => { -in => $person_ids },
                    },
                    { join => { stockprops => ['type'] }},
                 );
        } else {
            $rs = $rs->search({ name => '' });
        }
    }
    if ( my $trait = $c->req->param('trait') ) {
        $rs = $rs->search( { 'observable.name' => $trait },
                     { join => { nd_experiment_stocks => { nd_experiment => {'nd_experiment_phenotypes' => {'phenotype' => 'observable' }}}},
                       columns => [ qw/stock_id uniquename type_id organism_id / ],
                       distinct => 1
                     } );
    }
    if ( my $min = $c->req->param('min_limit') ) {
        $rs = $rs->search( { 'cast(phenotype.value as numeric) ' => { '>=' => $min }  },
                           { join => { nd_experiment_stocks => { nd_experiment => {'nd_experiment_phenotypes' => 'phenotype' }}},
                             columns => [ qw/stock_id uniquename type_id organism_id / ],
                             distinct => 1
                           } );
    }
    if ( my $max = $c->req->param('max_limit') ) {
        $rs = $rs->search( { 'cast(phenotype.value as numeric) ' => { '<=' => $max }  },
                           { join => { nd_experiment_stocks => { nd_experiment => {'nd_experiment_phenotypes' => 'phenotype' }}},
                             columns => [ qw/stock_id uniquename type_id organism_id / ],
                             distinct => 1
                           } );
    }
    # this is for direct annotations in stock_cvterm
    if ( my $ontology = $c->req->param('ontology') ) {
    }
    if ( my $has_image = $c->req->param('has_image') ) {
    }
    if ( my $has_locus = $c->req->param('has_locus') ) {
    }
    # page number and page size, and order by name
    $rs = $rs->search( undef, {
        page => $c->req->param('page')  || 1,
        rows => $c->req->param('page_size') || $self->default_page_size,
        order_by => 'uniquename',
                       });
    return $rs;
}


sub _stockprops {
    my ($self,$stock) = @_;

    my $bcs_stock = $stock->get_object_row();
    my $properties ;
    if ($bcs_stock) {
        my $stockprops = $bcs_stock->search_related("stockprops");
        while ( my $prop =  $stockprops->next ) {
            push @{ $properties->{$prop->type->name} } ,   $prop->value ;
        }
    }
    return $properties;
}


sub _dbxrefs {
    my ($self,$stock) = @_;
    my $bcs_stock = $stock->get_object_row;
    my $dbxrefs ;
    if ($bcs_stock) {
        my $stock_dbxrefs = $bcs_stock->search_related("stock_dbxrefs");
        while ( my $sdbxref =  $stock_dbxrefs->next ) {
            my $url = $sdbxref->dbxref->db->urlprefix . $sdbxref->dbxref->db->url;
            my $accession = $sdbxref->dbxref->accession;
            $url = $url ? qq |<a href = "$url/$accession">$accession</a>| : $accession ;
            push @{ $dbxrefs->{$sdbxref->dbxref->db->name} } , $sdbxref->dbxref;
        }
    }
    return $dbxrefs;
}

# this sub gets all phenotypes measured directly on this stock and
# stores it in a hashref as { project_name => [ BCS::Phenotype::Phenotype, ... ]

sub _stock_project_phenotypes {
    my ($self, $bcs_stock) = @_;

    return {} unless $bcs_stock;

    # hash of experiment_id => project(s) desc
    my %project_descriptions =
        map { $_->nd_experiment_id => join( ', ', map $_->project->description, $_->nd_experiment_projects ) }
        $bcs_stock->search_related('nd_experiment_stocks')
                  ->search_related('nd_experiment',
                                   {},
                                   { prefetch => { 'nd_experiment_projects' => 'project' } },
                                   );
    my $experiments = $bcs_stock->search_related('nd_experiment_stocks')
                                ->search_related('nd_experiment',
                                                 {},
                                                 { prefetch => { nd_experiment_phenotypes => 'phenotype' } },
                                                );
    my %phenotypes;
    while (my $exp = $experiments->next) {
        # there should be one project linked to the experiment ?
        my @ph = map $_->phenotype, $exp->nd_experiment_phenotypes;
        my $project_desc = $project_descriptions{ $exp->nd_experiment_id }
            or die "no project found for exp ".$exp->nd_experiment_id;
        push @{ $phenotypes{ $project_desc }}, @ph;
    }
    return \%phenotypes;
}

# this sub gets all phenotypes measured on all subjects of this stock.
# Subjects are in stock_relationship
sub _stock_members_phenotypes {
    my ($self, $bcs_stock) = @_;
    return unless $bcs_stock;
    my %phenotypes;
    my ($has_members_genotypes) = $bcs_stock->result_source->schema->storage->dbh->selectrow_array( <<'', undef, $bcs_stock->stock_id );
SELECT COUNT( DISTINCT genotype_id )
  FROM phenome.genotype
  JOIN stock subj using(stock_id)
  JOIN stock_relationship sr ON( sr.subject_id = subj.stock_id )
 WHERE sr.object_id = ?

    # now we have rs of stock_relationship objects. We need to find
    # the phenotypes of their related subjects
    my $subjects = $bcs_stock->search_related('stock_relationship_objects')
                             ->search_related('subject');
    my $subject_phenotypes = $self->_stock_project_phenotypes( $subjects );
    return ( $subject_phenotypes, $has_members_genotypes );
}

sub _stock_dbxrefs {
    my ($self,$stock) = @_;
    my $bcs_stock = $stock->get_object_row;
    # hash of arrays. Keys are db names , values are lists of StockDbxref objects
    my $sdbxrefs ;
    if ($bcs_stock) {
        my $stock_dbxrefs = $bcs_stock->search_related("stock_dbxrefs");
        while ( my $sdbxref =  $stock_dbxrefs->next ) {
            push @{ $sdbxrefs->{$sdbxref->dbxref->db->name} } , $sdbxref;
        }
    }
    return $sdbxrefs;
}

sub _stock_cvterms {
    my ($self,$stock) = @_;
    my $bcs_stock = $stock->get_object_row;
    # hash of arrays. Keys are db names , values are lists of StockCvterm objects
    my $scvterms ;
    if ($bcs_stock) {
        my $stock_cvterms = $bcs_stock->search_related("stock_cvterms");
        while ( my $scvterm =  $stock_cvterms->next ) {
            push @{ $scvterms->{$scvterm->cvterm->dbxref->db->name} } , $scvterm;
        }
    }
    return $scvterms;
}

# each stock may be linked with publications, each publication may have several dbxrefs
sub _stock_pubs {
    my ($self, $stock) = @_;
    my $bcs_stock = $stock->get_object_row;
    my $pubs ;
    if ($bcs_stock) {
        my $stock_pubs = $bcs_stock->search_related("stock_pubs");
        while (my $spub = $stock_pubs->next ) {
            my $pub = $spub->pub;
            my $pub_dbxrefs = $pub->pub_dbxrefs;
            while (my $pub_dbxref = $pub_dbxrefs->next ) {
                $pubs->{$pub_dbxref->dbxref->db->name . ":" .  $pub_dbxref->dbxref->accession } = $pub ;
            }
        }
    }
    return $pubs;
}

sub _stock_images {
    my ($self, $stock) = @_;
    my $query = "select distinct image_id FROM phenome.stock_image
                          WHERE stock_id = ?  ";
    my $ids = $stock->get_schema->storage->dbh->selectcol_arrayref
        ( $query,
          undef,
          $stock->get_stock_id,
        );
    return $ids;
}

sub _stock_allele_ids {
    my ($self, $stock) = @_;
    my $ids = $stock->get_schema->storage->dbh->selectcol_arrayref
	( "SELECT allele_id FROM phenome.stock_allele WHERE stock_id=? ",
	  undef,
	  $stock->get_stock_id
        );
    return $ids;
}

sub _validate_pair {
    my ($self,$c,$key,$value) = @_;
    $c->throw( is_client_error => 1, public_message => "$value is not a valid value for $key" )
        if ($key =~ m/_id$/ and $value !~ m/\d+/);
}



######
1;
######
