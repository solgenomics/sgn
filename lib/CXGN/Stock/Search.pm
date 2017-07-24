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
	uniquename_list=>\@uniquename_list,
	accession_number_list=>\@accession_number_list,
	pui_list=>\@pui_list,
	genus_list=>\@genus_list,
	species_list=>\@species_list,
	stock_id_list=>\@stock_id_list,
	organism_id=>$organism_id,
	stock_type_id=>$stock_type_id,
	stock_type_name=>$stock_type_name,
	owner_first_name=>$owner_first_name,
	owner_last_name=>$owner_last_name,
	trait_cvterm_name_list=>\@trait_cvterm_name_list,
	minimum_phenotype_value=>$minimum_phenotype_value,
	maximum_phenotype_value=>$maximum_phenotype_value,
	trial_id_list=>\@trial_id_list,
	trial_name_list=>\@trial_name_list,
	breeding_program_id_list=>\@breeding_program_id_list,
	location_name_list=>\@location_name_list,
	year_list=>\@year_list,
	organization_list=>\@organization_list,
    property_term=>$property_term,
    $property_value=>$property_value,
	limit=>$limit,
	offset=>$offset,
	minimal_info=>o  #for only returning stock_id and uniquenames
    display_pedigree=>1 #to calculate and display pedigree
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
use CXGN::Stock;
use CXGN::Chado::Stock;
use CXGN::Chado::Organism;

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

#can be 'exactly, starts_with, ends_with, contains'
has 'match_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'match_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'uniquename_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'accession_number_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'pui_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'genus_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'species_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'stock_id_list' => (
    isa => 'ArrayRef[Str]|Undef',
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

has 'stock_type_name' => (
    isa => 'Str|Undef',
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

has 'trial_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
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

has 'property_term' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'property_value' => (
    isa => 'Str|Undef',
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

has 'minimal_info' => (
    isa => 'Bool',
    is => 'rw',
	default => 0
);

has 'display_pedigree' => (
    isa => 'Bool',
    is => 'rw',
	default => 0
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
	my $stock_type_name = $self->stock_type_name;
	my $owner_first_name = $self->owner_first_name;
	my $owner_last_name = $self->owner_last_name;
	my $minimum_phenotype_value = $self->minimum_phenotype_value;
	my $maximum_phenotype_value = $self->maximum_phenotype_value;
	my @uniquename_array = $self->uniquename_list ? @{$self->uniquename_list} : ();
	my @accession_number_array = $self->accession_number_list ? @{$self->accession_number_list} : ();
	my @trait_name_array = $self->trait_cvterm_name_list ? @{$self->trait_cvterm_name_list} : ();
	my @trial_name_array = $self->trial_name_list ? @{$self->trial_name_list} : ();
	my @trial_id_array = $self->trial_id_list ? @{$self->trial_id_list} : ();
	my @location_name_array = $self->location_name_list ? @{$self->location_name_list} : ();
	my @year_array = $self->year_list ? @{$self->year_list} : ();
	my @program_id_array = $self->breeding_program_id_list ? @{$self->breeding_program_id_list} : ();
	my @organization_array = $self->organization_list ? @{$self->organization_list} : ();
	my @genus_array = $self->genus_list ? @{$self->genus_list} : ();
	my @species_array = $self->species_list ? @{$self->species_list} : ();
	my @stock_ids_array = $self->stock_id_list ? @{$self->stock_id_list} : ();
	my @pui_array = $self->pui_list ? @{$self->pui_list} : ();
    my $property_term = $self->property_term;
    my $property_value = $self->property_value;
	my $limit = $self->limit;
	my $offset = $self->offset;

	unless ($matchtype eq 'exactly') { #trim whitespace from both ends unless exact search was specified
		$any_name =~ s/^\s+|\s+$//g;
	}

	my ($or_conditions, $and_conditions);
	$and_conditions->{'me.stock_id'} = { '>' => 0 };

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

	if ($any_name) {
		$or_conditions = [
			{ 'me.name'          => {'ilike' => $start.$any_name.$end} },
			{ 'me.uniquename'    => {'ilike' => $start.$any_name.$end} },
			{ 'me.description'   => {'ilike' => $start.$any_name.$end} },
			{ 'stockprops.value'   => {'ilike' => $start.$any_name.$end} }
		];
	} else {
		$or_conditions = [ { 'me.uniquename' => { '!=' => undef } } ];
	}

	foreach (@uniquename_array){
		if ($_){
			if ($matchtype eq 'contains'){ #for 'wildcard' matching it replaces * with % and ? with _
				$_ =~ tr/*?/%_/;
			}
			push @{$and_conditions->{'me.uniquename'}}, {'ilike' => $start.$_.$end };
		}
	}

	foreach (@stock_ids_array){
		if ($_){
			if ($matchtype eq 'contains'){ #for 'wildcard' matching it replaces * with % and ? with _
				$_ =~ tr/*?/%_/;
			}
			push @{$and_conditions->{'me.stock_id::varchar(255)'}}, {'ilike' => $_ };
		}
	}

	if ($organism_id) {
		$and_conditions->{'me.organism_id'} = $organism_id;
	}

	if ($stock_type_name){
		$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type_name, 'stock_type')->cvterm_id();
	}

	my $stock_type_search = 0;
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

	foreach (@trait_name_array){
		if ($_){
			push @{$and_conditions->{ 'observable.name' }}, $_;
		}
	}
	if ($minimum_phenotype_value) {
		$and_conditions->{ 'phenotype.value' }  = { '>' => $minimum_phenotype_value };
	}
	if ($maximum_phenotype_value) {
		$and_conditions->{ 'phenotype.value' }  = { '<' => $maximum_phenotype_value };
	}

	foreach (@trial_name_array){
		if ($_){
			push @{$and_conditions->{ 'lower(project.name)' }}, { -like  => lc($_) } ;
		}
	}

	foreach (@trial_id_array){
		if ($_){
			push @{$and_conditions->{ 'project.project_id' }}, $_ ;
		}
	}

	foreach (@location_name_array){
		if ($_){
			push @{$and_conditions->{ 'lower(nd_geolocation.description)' }}, { -like  => lc($_) };
		}
	}

	my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id;
	foreach (@year_array){
		if ($_){
			$and_conditions->{ 'projectprops.type_id'} = $year_type_id;
			push @{$and_conditions->{ 'lower(projectprops.value)' }}, { -like  => lc($_) } ;
		}
	}

	foreach (@program_id_array){
		if ($_){
			push @{$and_conditions->{ 'project_relationship_subject_projects.object_project_id' }}, $_ ;
		}
	}

	my $organization_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'organization', 'stock_property')->cvterm_id();
	foreach (@organization_array){
		if ($_){
			$and_conditions->{ 'stockprops.type_id'} = $organization_type_id;
			push @{$and_conditions->{ 'lower(stockprops.value)' }}, { -like  => lc($_) } ;
		}
	}

	my $accession_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession number', 'stock_property')->cvterm_id();
	foreach (@accession_number_array){
		if ($_){
			$and_conditions->{ 'stockprops.type_id'} = $accession_number_type_id;
			push @{$and_conditions->{ 'lower(stockprops.value)' }}, { -like  => lc($_) } ;
		}
	}

	my $pui_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'PUI', 'stock_property')->cvterm_id();
	foreach (@pui_array){
		if ($_){
			$and_conditions->{ 'stockprops.type_id'} = $pui_type_id;
			push @{$and_conditions->{ 'lower(stockprops.value)' }}, { -like  => lc($_) } ;
		}
	}

	foreach (@genus_array){
		if ($_){
			push @{$and_conditions->{ 'lower(organism.genus)' }}, { -like  => lc($_) } ;
		}
	}

	foreach (@species_array){
		if ($_){
			push @{$and_conditions->{ 'lower(organism.species)' }}, { -like  => lc($_) } ;
		}
	}

    if ($property_term && $property_value){
        my $property_term_id = SGN::Model::Cvterm->get_cvterm_row($schema, $property_term, 'stock_property')->cvterm_id();
        $and_conditions->{ 'stockprops.type_id'} = $property_term_id;
        push @{$and_conditions->{ 'lower(stockprops.value)' }}, { -like  => lc($property_value) } ;
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
		'+select' => [ 'type.name' , 'organism.species' , 'organism.common_name', 'organism.genus'],
		'+as'     => [ 'cvterm_name' , 'species', 'common_name', 'genus' ],
		order_by  => 'me.name',
		distinct  => 1,
	}
	);

	my $records_total = $rs->count();
	if (defined($limit) && defined($offset)){
		$rs = $rs->slice($offset, $limit);
	}

    my $owners_hash;
    if (!$self->minimal_info){
        my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
        $owners_hash = $stock_lookup->get_owner_hash_lookup();
    }

	my @result;
	while (my $a = $rs->next()) {
		my $uniquename  = $a->uniquename;
		my $stock_id    = $a->stock_id;
		if (!$self->minimal_info){
			my $type_id     = $a->type_id ;
			my $type        = $a->get_column('cvterm_name');
			my $organism_id = $a->organism_id;
			my $species    = $a->get_column('species');
			my $stock_name  = $a->name;
			my $common_name = $a->get_column('common_name');
			my $genus       = $a->get_column('genus');
			my @owners = $owners_hash->{$stock_id} ? @{$owners_hash->{$stock_id}} : ();
			my $stockprop_hash = CXGN::Chado::Stock->new($self->bcs_schema, $stock_id)->get_stockprop_hash();
			my $organismprop_hash = CXGN::Chado::Organism->new($self->bcs_schema, $organism_id)->get_organismprop_hash();
			my @donor_array;
			my $donor_accessions = $stockprop_hash->{'donor'} ? $stockprop_hash->{'donor'} : [];
			my $donor_institutes = $stockprop_hash->{'donor institute'} ? $stockprop_hash->{'donor institute'} : [];
			my $donor_puis = $stockprop_hash->{'donor PUI'} ? $stockprop_hash->{'donor PUI'} : [];
            if (scalar(@$donor_accessions)>0 && scalar(@$donor_institutes)>0 && scalar(@$donor_puis)>0 && scalar(@$donor_accessions) == scalar(@$donor_institutes) && scalar(@$donor_accessions) == scalar(@$donor_puis)){
                for (0 .. scalar(@$donor_accessions)-1){
                    push @donor_array, { 'donorGermplasmName'=>$donor_accessions->[$_], 'donorAccessionNumber'=>$donor_accessions->[$_], 'donorInstituteCode'=>$donor_institutes->[$_], 'germplasmPUI'=>$donor_puis->[$_] };
                }
            }
			push @result, {
				stock_id => $stock_id,
				uniquename => $uniquename,
				stock_name => $stock_name,
				stock_type => $type,
				stock_type_id => $type_id,
				species => $species,
				genus => $genus,
				common_name => $common_name,
				organism_id => $organism_id,
				owners => \@owners,
				organizations =>$stockprop_hash->{'organization'} ? join ',', @{$stockprop_hash->{'organization'}} : undef,
				accessionNumber=>$stockprop_hash->{'accession number'} ? join ',', @{$stockprop_hash->{'accession number'}} : undef,
				germplasmPUI=>$stockprop_hash->{'PUI'} ? join ',', @{$stockprop_hash->{'PUI'}} : undef,
				pedigree=>$self->display_pedigree ? $self->germplasm_pedigree_string($stock_id) : 'DISABLED',
				germplasmSeedSource=>$stockprop_hash->{'seed source'} ? join ',', @{$stockprop_hash->{'seed source'}} : undef,
				synonyms=> $stockprop_hash->{'stock_synonym'} ? $stockprop_hash->{'stock_synonym'} : [],
				instituteCode=>$stockprop_hash->{'institute code'} ? join ',', @{$stockprop_hash->{'institute code'}} : undef,
				instituteName=>$stockprop_hash->{'institute name'} ? join ',', @{$stockprop_hash->{'institute name'}} : undef,
				biologicalStatusOfAccessionCode=>$stockprop_hash->{'biological status of accession code'} ? join ',', @{$stockprop_hash->{'biological status of accession code'}} : undef,
				countryOfOriginCode=>$stockprop_hash->{'country of origin'} ? join ',', @{$stockprop_hash->{'country of origin'}} : undef,
				typeOfGermplasmStorageCode=>$stockprop_hash->{'type of germplasm storage code'} ? join ',', @{$stockprop_hash->{'type of germplasm storage code'}} : undef,
				speciesAuthority=>$organismprop_hash->{'species authority'} ? join ',', @{$organismprop_hash->{'species authority'}} : undef,
				subtaxa=>$organismprop_hash->{'subtaxa'} ? join ',', @{$organismprop_hash->{'subtaxa'}} : undef,
				subtaxaAuthority=>$organismprop_hash->{'subtaxa authority'} ? join ',', @{$organismprop_hash->{'subtaxa authority'}} : undef,
				donors=>\@donor_array,
				acquisitionDate=>$stockprop_hash->{'acquisition date'} ? join ',', @{$stockprop_hash->{'acquisition date'}} : undef,
			};
		} else {
			push @result, {
				stock_id => $stock_id,
				uniquename => $uniquename
			};
		}
	}

	#print STDERR Dumper \@result;
	return (\@result, $records_total);
}

sub germplasm_pedigree_string {
	my $self = shift;
	my $stock_id = shift;
	my $s = CXGN::Stock->new(schema => $self->bcs_schema, stock_id => $stock_id);
	my $pedigree_string = $s->get_pedigree_string('Parents');
	return $pedigree_string;
}

1;
