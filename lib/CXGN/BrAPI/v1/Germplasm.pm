package CXGN::BrAPI::v1::Germplasm;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Stock::Search;
use CXGN::Chado::Stock;
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
		offset=>$offset
	});
	my ($result, $total_count) = $stock_search->search();

	my @data;
	foreach (@$result){
		push @data, {
			germplasmDbId=>$_->{stock_id},
			defaultDisplayName=>$_->{uniquename},
			germplasmName=>$_->{stock_name},
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

sub germplasm_pedigree_string {
	my $self = shift;
	my $stock_id = shift;
	my $s = CXGN::Chado::Stock->new($self->bcs_schema, $stock_id);
	my $pedigree_root = $s->get_parents('1');
	my $pedigree_string = $pedigree_root ? $pedigree_root->get_pedigree_string('1') : '';
	return $pedigree_string;
}

sub germplasm_detail {
	my $self = shift;
	my $stock_id = shift;
	my $status = $self->status;
	my %result;
	my @data_files;

	my $verify_id = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$stock_id});
	my $stock = CXGN::Chado::Stock->new($self->bcs_schema(), $stock_id);

	my $total_count = 0;
	if ($verify_id) {
		$total_count = 1;
	} else {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId does not exist in the database');
	}
	my $stockprop_hash = $stock->get_stockprop_hash();

	my @donor_array;
	my $donor_accessions = $stockprop_hash->{'donor'} ? $stockprop_hash->{'donor'} : [];
	my $donor_institutes = $stockprop_hash->{'donor institute'} ? $stockprop_hash->{'donor institute'} : [];
	my $donor_puis = $stockprop_hash->{'donor PUI'} ? $stockprop_hash->{'donor PUI'} : [];
	for (0 .. scalar(@$donor_accessions)){
		push @donor_array, { 'donorGermplasmName'=>$donor_accessions->[$_], 'donorAccessionNumber'=>$donor_accessions->[$_], 'donorInstituteCode'=>$donor_institutes->[$_], 'germplasmPUI'=>$donor_puis->[$_] };
	}

	%result = (
		germplasmDbId=>$stock_id,
		defaultDisplayName=>$stock->get_name(),
		germplasmName=>$stock->get_uniquename(),
		accessionNumber=>$stock->get_uniquename(),
		germplasmPUI=>$stock->get_uniquename(),
		pedigree=>$self->germplasm_pedigree_string($stock_id),
		germplasmSeedSource=>$stockprop_hash->{'seed source'} ? join ',', @{$stockprop_hash->{'seed source'}} : '',
		synonyms=>$stockprop_hash->{'stock_synonym'} ? join ',', @{$stockprop_hash->{'stock_synonym'}} : '',
		commonCropName=>$stock->get_organism->common_name(),
		instituteCode=>$stockprop_hash->{'institute code'} ? join ',', @{$stockprop_hash->{'institute code'}} : '',
		instituteName=>$stockprop_hash->{'institute name'} ? join ',', @{$stockprop_hash->{'institute name'}} : '',
		biologicalStatusOfAccessionCode=>$stockprop_hash->{'biological status of accession code'} ? join ',', @{$stockprop_hash->{'biological status of accession code'}} : '',
		countryOfOriginCode=>$stockprop_hash->{'country of origin'} ? join ',', @{$stockprop_hash->{'country of origin'}} : '',
		typeOfGermplasmStorageCode=>$stockprop_hash->{'type of germplasm storage code'} ? join ',', @{$stockprop_hash->{'type of germplasm storage code'}} : '',
		genus=>$stock->get_organism->genus(),
		species=>$stock->get_organism->species(),
		speciesAuthority=>'',
		subtaxa=>'',
		subtaxaAuthority=>'',
		donors=>\@donor_array,
		acquisitionDate=>'',
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
	my $s = CXGN::Chado::Stock->new($self->bcs_schema(), $stock_id);
	if ($s) {
		$total_count = 1;
		my @direct_parents = $s->get_direct_parents();
		%result = (
			germplasmDbId=>$stock_id,
			pedigree=>$self->germplasm_pedigree_string($stock_id),
			parent1Id=>$direct_parents[0][0],
			parent2Id=>$direct_parents[1][0]
		);
	}

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm pedigree result constructed');
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
