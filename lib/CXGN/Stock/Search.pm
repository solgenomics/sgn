package CXGN::Stock::Search;

=head1 NAME

CXGN::Stock::Search - an object to handle searching for stocks (accessions,plots,plants,etc) given criteria

=head1 USAGE

my $stock_search = CXGN::Stock::Search->new({
	bcs_schema=>$schema,
	people_schema=>$people_schema,
	phenome_schema=>$phenome_schema,
	match_type=>$match_type,
	match_name=>$match_name,
	organism_id=>$organism_id,
	stock_type_id=>$stock_type_id,
	owner_first_name=>$owner_first_name,
	owner_last_name=>$owner_last_name,
	trait_cvterm_name_list=>\@trait_cvterm_name_list,
	minimum_phenotype_value=>$minimum_phenotype_value,
	maximum_phenotype_value=>$maximum_phenotype_value,
	trial_name_list=>\@trial_name_list,
	breeding_program_id_list=>\@breeding_program_id_list,
	location_name_list=>\@location_name_list,
	year_list=>\@year_list,
	organization_list=>\@organization_list,
	limit=>$limit,
	offset=>$offset
});
my ($result, $records_total) = $stock_search->search();

=head1 DESCRIPTION


=head1 AUTHORS

 With code adapted from SGN::Controller::AJAX::Search::Stock

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'people_schema' => ( isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1,
);

has 'phenome_schema' => ( isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
);

has 'match_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'match_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'organism_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'stock_type_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'owner_first_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'owner_last_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'trait_cvterm_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'minimum_phenotype_value' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'maximum_phenotype_value' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'trial_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'breeding_program_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'location_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'year_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'organization_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw',
);

sub search {
	my $self = shift;
	my $schema = $self->bcs_schema;
	my $people_schema = $self->people_schema;
	my $phenome_schema = $self->phenome_schema;
	my $matchtype = $self->match_type || 'contains';
	my $any_name = $self->match_name;
	my $organism_id = $self->organism_id;
	my $stock_type_id = $self->stock_type_id;
	my $owner_first_name = $self->owner_first_name;
	my $owner_last_name = $self->owner_last_name;
	my $minimum_phenotype_value = $self->minimum_phenotype_value;
	my $maximum_phenotype_value = $self->maximum_phenotype_value;
	my @trait_name_array = $self->trait_cvterm_name_list ? @{$self->trait_cvterm_name_list} : ();
	my @trial_name_array = $self->trial_name_list ? @{$self->trial_name_list} : ();
	my @location_name_array = $self->location_name_list ? @{$self->location_name_list} : ();
	my @year_array = $self->year_list ? @{$self->year_list} : ();
	my @program_id_array = $self->breeding_program_id_list ? @{$self->breeding_program_id_list} : ();
	my @organization_array = $self->organization_list ? @{$self->organization_list} : ();
	my $limit = $self->limit;
	my $offset = $self->offset;

	unless ($matchtype eq 'exactly') { #trim whitespace from both ends unless exact search was specified
		$any_name =~ s/^\s+|\s+$//g;
	}

	my ($or_conditions, $and_conditions);
	$and_conditions->{'me.stock_id'} = { '>' => 0 };

	if ($any_name) {
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

	if ($organism_id) {
		$and_conditions->{'me.organism_id'} = $organism_id;
	}

	my $stock_type_search;
	if ($stock_type_id) {
		$and_conditions->{'me.type_id'} = $stock_type_id;
		$stock_type_search = $stock_type_id;
	}
	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

	if ( $owner_first_name || $owner_last_name ){
		my %person_params;
		if ($owner_first_name) {
			$owner_first_name =~ s/\s+//g;
			$person_params{first_name} = {'ilike' => '%'.$owner_first_name.'%'};
		}
		if ($owner_last_name) {
			$owner_last_name =~ s/\s+//g;
			$person_params{last_name} = {'ilike' => '%'.$owner_last_name.'%'};
		}

		$people_schema->storage->debug(1);
		my $p_rs = $people_schema->resultset("SpPerson")->search(\%person_params);

		my $stock_owner_rs = $phenome_schema->resultset("StockOwner")->search({
			sp_person_id => { -in  => $p_rs->get_column('sp_person_id')->as_query },
		});
		my @stock_ids;
		while ( my $o = $stock_owner_rs->next ) {
			push @stock_ids, $o->stock_id;
		}
		$and_conditions->{'me.stock_id'} = { '-in' => \@stock_ids } ;
	}

	my $stock_join;
	if ($stock_type_search == $accession_cvterm_id){
		$stock_join = { stock_relationship_objects => { subject => { nd_experiment_stocks => { nd_experiment => [ 'nd_geolocation', {'nd_experiment_phenotypes' => {'phenotype' => 'observable' }}, { 'nd_experiment_projects' => { 'project' => ['projectprops', 'project_relationship_subject_projects' ] } } ] }}}};
	} else {
		$stock_join = { nd_experiment_stocks => { nd_experiment => [ 'nd_geolocation', {'nd_experiment_phenotypes' => {'phenotype' => 'observable' }}, { 'nd_experiment_projects' => { 'project' => ['projectprops', 'project_relationship_subject_projects' ] } } ] } };
	}

	if (scalar(@trait_name_array) > 0) {
		foreach (@trait_name_array){
			if ($_){
				push @{$and_conditions->{ 'observable.name' }}, $_;
			}
		}
	}
	if ($minimum_phenotype_value) {
		$and_conditions->{ 'phenotype.value' }  = { '>' => $minimum_phenotype_value };
	}
	if ($maximum_phenotype_value) {
		$and_conditions->{ 'phenotype.value' }  = { '<' => $maximum_phenotype_value };
	}

	if (scalar(@trial_name_array) > 0 ){
		foreach (@trial_name_array){
			if ($_){
				push @{$and_conditions->{ 'lower(project.name)' }}, { -like  => lc($_) } ;
			}
		}
	}

	if (scalar(@location_name_array) > 0 ){
		foreach (@location_name_array){
			if ($_){
				push @{$and_conditions->{ 'lower(nd_geolocation.description)' }}, { -like  => lc($_) };
			}
		}
	}

	if (scalar(@year_array) > 0){
		my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id;
		foreach (@year_array){
			if ($_){
				$and_conditions->{ 'projectprops.type_id'} = $year_type_id;
				push @{$and_conditions->{ 'lower(projectprops.value)' }}, { -like  => lc($_) } ;
			}
		}
	}

	if (scalar(@program_id_array) > 0){
		foreach (@program_id_array){
			if ($_){
				push @{$and_conditions->{ 'project_relationship_subject_projects.object_project_id' }}, $_ ;
			}
		}
	}

	if (scalar(@organization_array) > 0){
		foreach (@organization_array){
			if ($_){
				push @{$and_conditions->{ 'lower(stockprops.value)' }}, { -like  => lc($_) } ;
			}
		}
	}

	#$schema->storage->debug(1);
	my $rs = $schema->resultset("Stock::Stock")->search(
	{
		'me.is_obsolete'   => 'f',
		-and => [
		$or_conditions,
		$and_conditions
		],
	},
	{
		join => ['type', 'organism', 'stockprops', $stock_join],
		'+select' => [ 'type.name' , 'organism.species' ],
		'+as'     => [ 'cvterm_name' , 'species' ],
		order_by  => 'me.name',
		distinct  => 1,
	}
	);

	my $records_total = $rs->count();
	if (defined($limit) && defined($offset)){
		$rs = $rs->slice($offset, $limit);
	}

	my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
	my $synonym_hash = $stock_lookup->get_synonym_hash_lookup();
	my $owners_hash = $stock_lookup->get_owner_hash_lookup();
	my $organizations_hash = $stock_lookup->get_organization_hash_lookup();

	my @result;
	while (my $a = $rs->next()) {
		my $uniquename  = $a->uniquename;
		my $type_id     = $a->type_id ;
		my $type        = $a->get_column('cvterm_name');
		my $organism_id = $a->organism_id;
		my $organism    = $a->get_column('species');
		my $stock_id    = $a->stock_id;
		my @synonyms = $synonym_hash->{$uniquename} ? @{$synonym_hash->{$uniquename}} : ();
		my @owners = $owners_hash->{$stock_id} ? @{$owners_hash->{$stock_id}} : ();
		my @organizations = $organizations_hash->{$stock_id} ? @{$organizations_hash->{$stock_id}} : ();
		push @result, {
			stock_id => $stock_id,
			uniquename => $uniquename,
			stock_type => $type,
			stock_type_id => $type_id,
			organism => $organism,
			organism_id => $organism_id,
			synonyms => \@synonyms,
			owners => \@owners,
			organizations => \@organizations
		};
	}

	#print STDERR Dumper \@result;
	return (\@result, $records_total);
}

1;
