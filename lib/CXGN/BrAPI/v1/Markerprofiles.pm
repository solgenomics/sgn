package CXGN::BrAPI::v1::Markerprofiles;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
use JSON;
use CXGN::BrAPI::Pagination;

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

sub markerprofiles_search {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @germplasm_ids = $inputs->{stock_ids} ? @{$inputs->{stock_ids}} : ();
	my @study_ids = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
	my @extract_ids = $inputs->{extract_ids} ? @{$inputs->{extract_ids}} : ();
	my @sample_ids = $inputs->{sample_ids} ? @{$inputs->{sample_ids}} : ();
	my $method = $inputs->{protocol_id};
	
	if (scalar(@extract_ids)>0){
		push @$status, { 'error' => 'Search parameter extractDbId not supported' };
	}
	if (scalar(@sample_ids)>0){
		push @$status, { 'error' => 'Search parameter sampleDbId not supported' };
	}

	my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        accession_list=>\@germplasm_ids,
        trial_list=>\@study_ids,
        protocol_id=>$method,
        offset=>$page_size*$page,
        limit=>$page_size*($page+1)-1
    });
    my ($total_count, $genotypes) = $genotypes_search->get_genotype_info();

	my @data;
    foreach (@$genotypes){
        push @data, {
            markerProfileDbId => $_->{markerProfileDbId},
            germplasmDbId => $_->{germplasmDbId},
            uniqueDisplayName => $_->{genotypeUniquename},
            extractDbId => $_->{genotypeUniquename},
            sampleDbId => $_->{genotypeUniquename},
            analysisMethod => $_->{analysisMethod},
            resultCount => $_->{resultCount}
        };
    }

    my %result = (data => \@data);
	push @$status, { 'success' => 'Markerprofiles-search result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub markerprofiles_detail {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $genotypeprop_id = $inputs->{markerprofile_id};

	my $total_count = 0;
    my $rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->find(
        {'genotypeprops.genotypeprop_id' => $genotypeprop_id },
        {join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
         select=> ['genotypeprops.value', 'nd_protocol.name', 'stock.stock_id', 'stock.uniquename', 'genotype.uniquename'],
         as=> ['value', 'protocol_name', 'stock_id', 'uniquename', 'genotype_uniquename'],
        }
    );

	my @data;
	my %result;
    if ($rs) {
        my $genotype_json = $rs->get_column('value');
        my $genotype = JSON::Any->decode($genotype_json);
        $total_count = scalar keys %$genotype;

        foreach my $m (sort genosort keys %$genotype) {
            push @data, { $m=>$self->convert_dosage_to_genotype($genotype->{$m}) };
        }

        my $start = $page_size*$page;
        my $end = $page_size*($page+1)-1;
        my @data_window = splice @data, $start, $end;

        %result = (
            germplasmDbId=>$rs->get_column('stock_id'),
            uniqueDisplayName=>$rs->get_column('uniquename'),
            extractDbId=>$rs->get_column('genotype_uniquename'),
            markerprofileDbId=>$genotypeprop_id,
            analysisMethod=>$rs->get_column('protocol_name'),
            #encoding=>"AA,BB,AB",
            data => \@data_window
        );
    }

	push @$status, { 'success' => 'Markerprofiles detail result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub markerprofiles_methods {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdProtocol")->search({});
	my $total_count = $rs->count;
	my $rs_slice= $rs->slice($page_size*$page, $page_size*($page+1)-1);
	my @data;
	while (my $row = $rs_slice->next()) {
		push @data, {
			'analysisMethodDbId' => $row->nd_protocol_id(),
			'analysisMethod' => $row->name()
		};
	}
	my %result = (data => \@data);
	push @$status, { 'success' => 'Markerprofiles methods result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}


sub genosort {
    my ($a_chr, $a_pos, $b_chr, $b_pos);
    if ($a =~ m/S(\d+)\_(.*)/) {
	$a_chr = $1;
	$a_pos = $2;
    }
    if ($b =~ m/S(\d+)\_(.*)/) {
	$b_chr = $1;
	$b_pos = $2;
    }

    if ($a_chr && $b_chr) {
      if ($a_chr == $b_chr) {
          return $a_pos <=> $b_pos;
      }
      return $a_chr <=> $b_chr;
    } else {
      return -1;
    }
}


sub convert_dosage_to_genotype {
    my $self = shift;
    my $dosage = shift;

    my $genotype;
    if ($dosage eq "NA") {
	return "NA";
    }
    if ($dosage == 1) {
	return "AA";
    }
    elsif ($dosage == 0) {
	return "BB";
    }
    elsif ($dosage == 2) {
	return "AB";
    }
    else {
	return "NA";
    }
}

1;
