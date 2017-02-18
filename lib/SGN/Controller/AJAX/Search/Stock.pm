
package SGN::Controller::AJAX::Search::Stock;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Stock::StockLookup;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub stock_search :Path('/ajax/search/stocks') Args(0) {
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params() || {};
    #print STDERR Dumper $params;

    my %query;


    my $matchtype = $params->{any_name_matchtype};
    my $any_name  = $params->{any_name};

    unless ($matchtype eq 'exactly') { #trim whitespace from both ends unless exact search was specified
      $any_name =~ s/^\s+|\s+$//g;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    #$schema->storage->debug(1);
    my ($or_conditions, $and_conditions);
    $and_conditions->{'me.stock_id'} = { '>' => 0 };

    if (exists($params->{any_name} ) && $params->{any_name} ) {
        my $start = '%';
        my $end = '%';
        if ( $matchtype eq 'exactly' ) {
            $start = '';
            $end = '';
        } elsif ( $matchtype eq 'starts_with' ) {
            $start = '';
        } elsif ( $matchtype eq 'ends_with' ) {
            $end = '';
        }

        $or_conditions = [
            { 'me.name'          => {'ilike', $start.$any_name.$end} },
            { 'me.uniquename'    => {'ilike', $start.$any_name.$end} },
            { 'me.description'   => {'ilike', $start.$any_name.$end} },
            { 'stockprops.value'   => {'ilike', $start.$any_name.$end} }
        ];

    } else {
        $or_conditions = [ { 'me.uniquename' => { '!=', undef } } ];
    }


    ###############
    if (exists($params->{organism} ) && $params->{organism} ) {
        $and_conditions->{'me.organism_id'} = $params->{organism} ;
    }

    if (exists($params->{stock_type} ) && $params->{stock_type} ) {
        $and_conditions->{'me.type_id'} = $params->{stock_type} ;
    }

    if (exists($params->{person} ) && $params->{person} ) {
	my $editor = $params->{person};
	my ($first_name, $last_name ) = split ',' , $editor;
        $first_name =~ s/\s+//g;
        $last_name =~ s/\s+//g;

	my $p_rs = $c->dbic_schema("CXGN::People::Schema")->resultset("SpPerson")->search(
	    {
		first_name => { 'ilike' , '%'.$first_name.'%' } ,
		last_name  => { 'ilike' , '%'.$last_name.'%' }
	    }
	    );

	my $stock_owner_rs = $c->dbic_schema("CXGN::Phenome::Schema")->resultset("StockOwner")->search(
	    {
		sp_person_id => { -in  => $p_rs->get_column('sp_person_id')->as_query },
	    });
	my @stock_ids;
	while ( my $o = $stock_owner_rs->next ) {
	    my $stock_id = $o->stock_id;
	    push @stock_ids, $stock_id ;
	}
	my $stock_ids = $stock_owner_rs->get_column('stock_id');
	$and_conditions->{'me.stock_id'} = { '-in' => \@stock_ids } ;
    }
###############
    if (exists($params->{trait} ) && $params->{trait} ) {
	$and_conditions->{ 'observable.name' }  = $params->{trait} ;
    }
    if (exists($params->{minimum_trait_value} ) && $params->{minimum_trait_value} ) {
        $and_conditions->{ 'phenotype.value' }  = { '>' => $params->{minimum_trait_value} };
    }
    if (exists($params->{maximum_trait_value} ) && $params->{maximum_trait_value} ) {
        $and_conditions->{ 'phenotype.value' }  = { '<' => $params->{maximum_trait_value} };
    }

    if (exists($params->{project} ) && $params->{project} ) {
	$and_conditions->{ 'lower(project.name)' } = { -like  => lc($params->{project} ) } ;
    }

    if (exists($params->{location} ) && $params->{location} ) {
	$and_conditions->{ 'lower(nd_geolocation.description)' } = { -like  => lc($params->{location}) };
    }

    if (exists($params->{year} ) && $params->{year} ) {
	$and_conditions->{ 'lower(projectprops.value)' } = { -like  => lc($params->{year} ) } ;
    }

    if (exists($params->{organization} ) && $params->{organization} ) {
	$and_conditions->{ 'project_relationship_subject_projects.object_project_id' } = $params->{organization} ;

    }

    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my $rows = $params->{length} || 10;
    my $start = $params->{start};

    my $page = int($start / $rows)+1;

    # get the count first
    my $rs = $schema->resultset("Stock::Stock")->search(
	{
	    'me.is_obsolete'   => 'f',
	    -and => [
		 $or_conditions,
		 $and_conditions
		],
	},
	{
	    join => ['type', 'organism', 'stockprops', { nd_experiment_stocks => { nd_experiment => {'nd_experiment_phenotypes' => {'phenotype' => 'observable' }}}}, { nd_experiment_stocks => { nd_experiment => { 'nd_experiment_projects' => { 'project' => ['projectprops', 'project_relationship_subject_projects'] }  } } }, { nd_experiment_stocks => { nd_experiment => 'nd_geolocation' } } ],
	    distinct => 1,
	}
    );


    my $records_total = $rs->count();

    #
    my $rs2 = $schema->resultset("Stock::Stock")->search(
	{
	    'me.is_obsolete'   => 'f',
	    -and => [
		 $or_conditions,
		 $and_conditions
		],
	} ,
	{
	    join => ['type', 'organism', 'stockprops', { nd_experiment_stocks => { nd_experiment => {'nd_experiment_phenotypes' => {'phenotype' => 'observable' }}}} ,  { nd_experiment_stocks => { nd_experiment => { 'nd_experiment_projects' => { 'project' => ['projectprops', 'project_relationship_subject_projects'] } } } } , { nd_experiment_stocks => { nd_experiment => 'nd_geolocation' } } ],

	    '+select' => [ 'type.name' , 'organism.species' ],
	    '+as'     => [ 'cvterm_name' , 'species' ],
	    page      => $page,
	    rows      => $rows,
	    order_by  => 'me.name',
	    distinct  => 1,
	}
	);

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my $synonym_hash = $stock_lookup->get_synonym_hash_lookup();

    my @result;
    while (my $a = $rs2->next()) {
        my $uniquename  = $a->uniquename;
        my $type_id     = $a->type_id ;
        my $type        = $a->get_column('cvterm_name');
        my $organism_id = $a->organism_id;
        my $organism    = $a->get_column('species');
        my $stock_id    = $a->stock_id;
        my $synonym_string = '';
        if (exists($synonym_hash->{$uniquename})) {
            $synonym_string = join ', ', @{$synonym_hash->{$uniquename}};
        }
        push @result, [  "<a href=\"/stock/$stock_id/view\">$uniquename</a>", $type, $organism, $synonym_string ];

    }

    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
}

1;
