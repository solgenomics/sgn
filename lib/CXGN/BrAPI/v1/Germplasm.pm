package CXGN::BrAPI::v1::Germplasm;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::Chado::Organism;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'metadata_schema' => (
	isa => 'CXGN::Metadata::Schema',
	is => 'rw',
	required => 1,
);

has 'phenome_schema' => (
	isa => 'CXGN::Phenome::Schema',
	is => 'rw',
	required => 1,
);

has 'people_schema' => (
	isa => 'CXGN::People::Schema',
	is => 'rw',
	required => 1,
);

has 'page_size' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'page' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'status' => (
	isa => 'ArrayRef[Maybe[HashRef]]',
	is => 'rw',
	required => 1,
);

sub germplasm_search {
	my $self = shift;
	my $search_params = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my @germplasm_names = $search_params->{germplasmName} ? @{$search_params->{germplasmName}} : ();
	my @accession_numbers = $search_params->{accessionNumber} ? @{$search_params->{accessionNumber}} : ();
	my @genus = $search_params->{germplasmGenus} ? @{$search_params->{germplasmGenus}} : ();
	my $subtaxa = $search_params->{germplasmSubTaxa}->[0];
	my @species = $search_params->{germplasmSpecies} ? @{$search_params->{germplasmSpecies}} : ();
	my @germplasm_ids = $search_params->{germplasmDbId} ? @{$search_params->{germplasmDbId}} : ();
	my @germplasm_puis = $search_params->{germplasmPUI} ? @{$search_params->{germplasmPUI}} : ();
	my $match_method = $search_params->{matchMethod}->[0] || 'wildcard';
	my @data_files;

	if ($match_method ne 'exact' && $match_method ne 'wildcard') {
		push @$status, { 'error' => "matchMethod '$match_method' not recognized. Allowed matchMethods: wildcard, exact. Wildcard allows % or * for multiple characters and ? for single characters." };
	}
	my $match_type;
	if ($match_method eq 'exact'){
		$match_type = 'exactly';
	}
	if ($match_method eq 'wildcard'){
		$match_type = 'contains';
	}

	my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();

	my $limit = $page_size*($page+1)-1;
	my $offset = $page_size*$page;
	my $stock_search = CXGN::Stock::Search->new({
		bcs_schema=>$self->bcs_schema,
		people_schema=>$self->people_schema,
		phenome_schema=>$self->phenome_schema,
		match_type=>$match_type,
		uniquename_list=>\@germplasm_names,
		accession_number_list=>\@accession_numbers,
		pui_list=>\@germplasm_puis,
		genus_list=>\@genus,
		species_list=>\@species,
		stock_id_list=>\@germplasm_ids,
		stock_type_id=>$accession_type_cvterm_id,
		limit=>$limit,
		offset=>$offset,
        display_pedigree=>1
	});
	my ($result, $total_count) = $stock_search->search();

	my @data;
	foreach (@$result){
		push @data, {
			germplasmDbId=>$_->{stock_id},
			defaultDisplayName=>$_->{stock_name},
			germplasmName=>$_->{uniquename},
			accessionNumber=>$_->{accessionNumber},
			germplasmPUI=>$_->{germplasmPUI},
			pedigree=>$_->{pedigree},
			germplasmSeedSource=>$_->{germplasmSeedSource},
			synonyms=> $_->{synonyms},
			commonCropName=>$_->{common_name},
			instituteCode=>$_->{instituteCode},
			instituteName=>$_->{instituteName},
			biologicalStatusOfAccessionCode=>$_->{biologicalStatusOfAccessionCode},
			countryOfOriginCode=>$_->{countryOfOriginCode},
			typeOfGermplasmStorageCode=>$_->{typeOfGermplasmStorageCode},
			genus=>$_->{genus},
			species=>$_->{species},
			speciesAuthority=>$_->{speciesAuthority},
			subtaxa=>$_->{subtaxa},
			subtaxaAuthority=>$_->{subtaxaAuthority},
			donors=>$_->{donors},
			acquisitionDate=>$_->{acquisitionDate},
		};
	}

	my %result = (data => \@data);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm-search result constructed');
}

sub germplasm_detail {
	my $self = shift;
	my $stock_id = shift;
	my $status = $self->status;
	my @data_files;

	my $verify_id = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$stock_id});
	if (!$verify_id) {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId does not exist in the database');
	}

	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	my $stock_search = CXGN::Stock::Search->new({
		bcs_schema=>$self->bcs_schema,
		people_schema=>$self->people_schema,
		phenome_schema=>$self->phenome_schema,
		match_type=>'exactly',
		stock_id_list=>[$stock_id],
		stock_type_id=>$accession_cvterm_id,
        display_pedigree=>1
	});
	my ($result, $total_count) = $stock_search->search();

	if ($total_count != 1){
		return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId did not return 1 result');
	}
	my %result = (
		germplasmDbId=>$result->[0]->{stock_id},
		defaultDisplayName=>$result->[0]->{uniquename},
		germplasmName=>$result->[0]->{stock_name},
		accessionNumber=>$result->[0]->{accessionNumber},
		germplasmPUI=>$result->[0]->{germplasmPUI},
		pedigree=>$result->[0]->{pedigree},
		germplasmSeedSource=>$result->[0]->{germplasmSeedSource},
		synonyms=> $result->[0]->{synonyms},
		commonCropName=>$result->[0]->{common_name},
		instituteCode=>$result->[0]->{instituteCode},
		instituteName=>$result->[0]->{instituteName},
		biologicalStatusOfAccessionCode=>$result->[0]->{biologicalStatusOfAccessionCode},
		countryOfOriginCode=>$result->[0]->{countryOfOriginCode},
		typeOfGermplasmStorageCode=>$result->[0]->{typeOfGermplasmStorageCode},
		genus=>$result->[0]->{genus},
		species=>$result->[0]->{species},
		speciesAuthority=>$result->[0]->{speciesAuthority},
		subtaxa=>$result->[0]->{subtaxa},
		subtaxaAuthority=>$result->[0]->{subtaxaAuthority},
		donors=>$result->[0]->{donors},
		acquisitionDate=>$result->[0]->{acquisitionDate},
	);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm detail result constructed');
}

sub germplasm_pedigree {
	my $self = shift;
	my $inputs = shift;
	my $stock_id = $inputs->{stock_id};
	my $notation = $inputs->{notation};
	my $status = $self->status;
	if ($notation) {
		push @$status, { 'info' => 'Notation not yet implemented. Returns a simple parent1/parent2 string.' };
		if ($notation ne 'purdy') {
			push @$status, { 'error' => 'Unsupported notation code. Allowed notation: purdy' };
		}
	}

	my %result;
	my @data_files;
	my $total_count = 0;
	my $s = CXGN::Stock->new( schema => $self->bcs_schema(), stock_id => $stock_id);
	if ($s) {
		$total_count = 1;
		my $parents = $s->get_parents();
		my $pedigree_string = $s->get_pedigree_string('Parents');
		%result = (
			germplasmDbId=>$stock_id,
			pedigree=>$pedigree_string,
			parent1Id=>$parents->{'mother_id'},
			parent2Id=>$parents->{'father_id'}
		);
	}

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm pedigree result constructed');
}

sub germplasm_progeny {
	my $self = shift;
	my $inputs = shift;
	my $stock_id = $inputs->{stock_id};
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $mother_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $father_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	print STDERR Dumper $stock_id;
	my $stock = $self->bcs_schema()->resultset("Stock::Stock")->find({ 
	    'type_id'=> $accession_cvterm,
		'stock_id'=> $stock_id,
	});
	my $edges = $self->bcs_schema()->resultset("Stock::StockRelationship")->search([
		{ 
		    'me.subject_id' => $stock_id,
		    'me.type_id' => $father_cvterm,
		    'object.type_id'=> $accession_cvterm
		},
		{ 
		    'me.subject_id' => $stock_id,
		    'me.type_id' => $mother_cvterm,
		    'object.type_id'=> $accession_cvterm
		}
	],{join => 'object'});
    my $result = {
		defaultDisplayName=>$stock->uniquename,
		germplasmDbId=>$stock_id,
		data=>[]
	};
    while (my $edge = $edges->next) {
        if ($edge->type_id==$mother_cvterm){
            push @{$result->{data}}, {
				progenyGermplasmDbId => $edge->object_id,
				parentType => "FEMALE"
			};
        } else {
            push @{$result->{data}}, {
				progenyGermplasmDbId => $edge->object_id,
				parentType => "MALE"
			};
        }
    }
	my $total_count = scalar @{$result->{data}};
	my $result->{data} = [@{$result->{data}}[$page_size*$page .. $page_size*($page+1)-1]];
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success($result, $pagination, \@data_files, $status, 'Germplasm progeny result constructed');
}

sub germplasm_markerprofiles {
	my $self = shift;
	my $stock_id = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @marker_profiles;

	my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();

	my $rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
		{'genotypeprops.type_id' => $snp_genotyping_cvterm_id, 'stock.stock_id'=>$stock_id},
		{join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
		select=> ['genotypeprops.genotypeprop_id'],
		as=> ['genotypeprop_id'],
		order_by=>{ -asc=>'genotypeprops.genotypeprop_id' }
		}
	);

	my $rs_slice = $rs->slice($page_size*$page, $page_size*($page+1)-1);
	while (my $gt = $rs_slice->next()) {
		push @marker_profiles, $gt->get_column('genotypeprop_id');
	}
	my $total_count = scalar(@marker_profiles);
	my %result = (
		germplasmDbId=>$stock_id,
		markerProfiles=>\@marker_profiles
	);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm markerprofiles result constructed');
}


1;
