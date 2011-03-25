package SGN::Controller::Stock;

=head1 NAME

SGN::Controller::Stock - Catalyst controller for pages dealing with stocks (e.g. accession, poopulation, etc.)

=cut

use Moose;
use namespace::autoclean;
use YAML::Any qw/LoadFile/;

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

# this sub gets all phenotypes measured directly on this stock and stores
# it in a hashref of keys = project name , values = list of BCS::Phenotype::Phenotype objects
sub _stock_project_phenotypes {
    my ($self, $stock) = @_;
    my $nd_experiments = $self->_stock_nd_experiments($stock);
    my %phenotypes;

    while (my $exp = $nd_experiments->next) {
        my $geolocation = $exp->nd_geolocation;
        # there should be one project linked to the experiment ?
        my $project = $exp->nd_experiment_projects->search_related('project')->first;
        my @ph = $exp->nd_experiment_phenotypes->search_related('phenotype')->all;

        push(@{$phenotypes{$project->description}}, @ph) if @ph;
    }
    return \%phenotypes;
}

# this sub gets all phenotypes measured on all subjects of this stock.
# Subjects are in stock_relationship
sub _stock_members_phenotypes {
    my ($self, $stock) = @_;
    my %phenotypes;
    my $has_members_genotypes;
    my $objects = $stock->get_object_row->stock_relationship_objects ;
    # now we have rs of stock_relationship objects. We need to find the phenotypes of their related subjects
    while (my $object = $objects->next ) {

        my $subject = $object->subject;
        my $subject_stock = CXGN::Chado::Stock->new($self->schema, $subject->stock_id);
        my $subject_phenotype_ref = $self->_stock_project_phenotypes($subject_stock);
        $has_members_genotypes = 1 if $self->_stock_genotypes($subject_stock);
        my %subject_phenotypes = %$subject_phenotype_ref;
        foreach my $key (keys %subject_phenotypes) {
            push(@{$phenotypes{$key} } , @{$subject_phenotypes{$key} } );
        }
    }
    return \%phenotypes, $has_members_genotypes;
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

sub _stock_cvterms {
    my ($self,$stock) = @_;

    my $stock_cvterms = $stock->get_object_row()->search_related("stock_cvterms");
    # hash of arrays. Keys are db names , values are lists of StockCvterm objects
    my $scvterms ;
    while ( my $scvterm =  $stock_cvterms->next ) {
        push @{ $scvterms->{$scvterm->cvterm->dbxref->db->name} } , $scvterm;
    }
    return $scvterms;
}

# each stock may be linked with publications, each publication may have several dbxrefs
sub _stock_pubs {
    my ($self, $stock) = @_;
    my $stock_pubs = $stock->get_object_row()->search_related("stock_pubs");
    my $pubs ;
    while (my $spub = $stock_pubs->next ) {
        my $pub = $spub->pub;
        my $pub_dbxrefs = $pub->pub_dbxrefs;
        while (my $pub_dbxref = $pub_dbxrefs->next ) {
            $pubs->{$pub_dbxref->dbxref->db->name . ":" .  $pub_dbxref->dbxref->accession } = $pub ;
        }
    }
    return $pubs;
}

sub _stock_genotypes {
    my ($self, $stock) = @_;
    my $dbh = $stock->get_schema->storage->dbh;
    my $q = "SELECT genotype_id FROM phenome.genotype WHERE stock_id = ?";
    my $sth = $dbh->prepare($q);
    $sth->execute($stock->get_stock_id);
    my @genotypes;
    while (my ($genotype_id) = $sth->fetchrow_array ) {
        push @genotypes, $genotype_id;
    }
    return \@genotypes;
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

    my $cvterms  = $stock ?  $self->_stock_cvterms($stock) : undef ;
    $c->stash->{stock_cvterms} = $cvterms;

    my $direct_phenotypes  = $stock ? $self->_stock_project_phenotypes($stock) : undef;
    $c->stash->{direct_phenotypes} = $direct_phenotypes;

    my ($members_phenotypes, $has_members_genotypes)  = $stock ? $self->_stock_members_phenotypes($stock) : undef;
    $c->stash->{members_phenotypes} = $members_phenotypes;

    my $stock_type = $stock->get_object_row->type->name;
    if ( ( grep { /^$stock_type/ } ('f2 population', 'backcross population') ) &&  $members_phenotypes && $has_members_genotypes ) { $c->stash->{has_qtl_data} = 1 ; }

}

######
1;
######
