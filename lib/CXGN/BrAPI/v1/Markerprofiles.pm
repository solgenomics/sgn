package CXGN::BrAPI::v1::Markerprofiles;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
use JSON;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v1::Common';

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
			markerprofileDbId => qq|$_->{markerProfileDbId}|,
			germplasmDbId => qq|$_->{germplasmDbId}|,
			uniqueDisplayName => $_->{genotypeUniquename},
			extractDbId => $_->{genotypeUniquename},
			sampleDbId => $_->{genotypeUniquename},
			analysisMethod => $_->{analysisMethod},
			resultCount => $_->{resultCount}
		};
	}

	my %result = (data => \@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles-search result constructed');
}

sub markerprofiles_detail {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $genotypeprop_id = $inputs->{markerprofile_id};
	my $sep_phased = $inputs->{sep_phased};
	my $sep_unphased = $inputs->{sep_unphased};
	my $unknown_string = $inputs->{unknown_string};
	my $expand_homozygotes = $inputs->{expand_homozygotes};

	if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
		push @$status, {'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased'};
	}

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
	my @data_files;
	my $pagination;
	if ($rs) {
		my $genotype_json = $rs->get_column('value');
		my $genotype = JSON::Any->decode($genotype_json);
		$total_count = scalar keys %$genotype;

		foreach my $m (sort genosort keys %$genotype) {
			push @data, { $m=>$self->convert_dosage_to_genotype($genotype->{$m}) };
		}

		#my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@data,$page_size,$page);
		%result = (
			germplasmDbId=>$rs->get_column('stock_id'),
			uniqueDisplayName=>$rs->get_column('uniquename'),
			extractDbId=>$rs->get_column('genotype_uniquename'),
			markerprofileDbId=>$genotypeprop_id,
			analysisMethod=>$rs->get_column('protocol_name'),
			#encoding=>"AA,BB,AB",
			data => \@data
		);
	}

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles detail result constructed');
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
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles methods result constructed');
}

sub markerprofiles_allelematrix {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @markerprofile_ids = $inputs->{markerprofile_ids} ? @{$inputs->{markerprofile_ids}} : ();
	my @marker_ids = $inputs->{marker_ids} ? @{$inputs->{marker_ids}} : ();
	my $sep_phased = $inputs->{sep_phased};
	my $sep_unphased = $inputs->{sep_unphased};
	my $unknown_string = $inputs->{unknown_string};
	my $expand_homozygotes = $inputs->{expand_homozygotes};
	my $data_format = $inputs->{format};
	my $file_path = $inputs->{file_path};
	my $uri = $inputs->{file_uri};

	if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
		push @$status, { 'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased' };
	}

	my @data_files;
	my %result;

	if ($data_format ne 'json' && $data_format ne 'tsv' && $data_format ne 'csv') {
		push @$status, { 'error' => 'Unsupported Format Given. Supported values are: json, tsv, csv' };
	}

	my $rs = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( { genotypeprop_id => { -in => \@markerprofile_ids }});

	my @scores;
	my $total_pages;
	my $total_count;
	my @ordered_refmarkers;
	my $markers;
	if ($rs->count() > 0) {
		while (my $profile = $rs->next()) {
			my $profile_json = $profile->value();
			my $refmarkers = JSON::Any->decode($profile_json);
			#print STDERR Dumper($refmarkers);
			push @ordered_refmarkers, sort genosort keys(%$refmarkers);
		}
		#print Dumper(\@ordered_refmarkers);
		my %unique_markers;
		foreach (@ordered_refmarkers) {
			$unique_markers{$_} = 1;
		}

		my $json = JSON->new();
		$rs = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->search( { genotypeprop_id => { -in => \@markerprofile_ids }});
		while (my $profile = $rs->next()) {
			my $markers_json = $profile->value();
			$markers = $json->decode($markers_json);
			my $genotypeprop_id = $profile->genotypeprop_id();
			foreach my $m (sort keys %unique_markers) {
				push @scores, [qq|$m|, qq|$genotypeprop_id|, $self->convert_dosage_to_genotype($markers->{$m})];
			}
		}
	}

	#print STDERR Dumper \@scores;

	my @scores_seen;
	if (!$data_format || $data_format eq 'json' ){

		for (my $n = $page_size*$page; $n< ($page_size*($page+1)-1); $n++) {
			push @scores_seen, $scores[$n];
		}
		%result = (data=>\@scores_seen);

	} elsif ($data_format eq 'tsv' || $data_format eq 'csv' || $data_format eq 'xls') {

		my @header_row;
		push @header_row, 'markerprofileDbIds';
		foreach (@markerprofile_ids){
			push @header_row, $_;
		}

		my %markers;
		foreach (@scores){
			$markers{$_->[0]}->{$_->[1]} = $_->[2];
		}
		#print STDERR Dumper \%markers;

		my @data_out;
		push @data_out, \@header_row;
		foreach (keys %markers){
			my @data_row;
			push @data_row, $_;
			foreach my $profile_id (@markerprofile_ids) {
				push @data_row, $markers{$_}->{$profile_id};
			}
			push @data_out, \@data_row;
		}
		my $file_response = CXGN::BrAPI::FileResponse->new({
			absolute_file_path => $file_path,
			absolute_file_uri => $inputs->{main_production_site_url}.$uri,
			format => $data_format,
			data => \@data_out
		});
		@data_files = $file_response->get_datafiles();
	}

	$total_count = scalar(@scores);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles allelematrix result constructed');
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
