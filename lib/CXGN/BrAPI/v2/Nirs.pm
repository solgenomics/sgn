package CXGN::BrAPI::v2::Nirs;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
	my $c = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
    my $status = $self->status;
	my $schema = $self->bcs_schema();
	my $stock_ids_arrayref = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
	my $stock_id = @$stock_ids_arrayref[0];
	print STDERR Dumper $stock_id;
	my @nirs_protocol_ids;
	my @data;
	my @data_files;
	my $total_count = 1;

	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();

	my $q = "SELECT nd_protocol_id FROM nd_protocol where type_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($high_dim_nirs_protocol_cvterm_id);
	print STDERR Dumper $high_dim_nirs_protocol_cvterm_id;

	while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
		push @nirs_protocol_ids, $nirs_protocol_id;
	}
	print STDERR Dumper @nirs_protocol_ids;


# 	my $accession_ids = $ds->accessions();
#	my @accession_array = ['41786'];
#	my $accession_ids = \@accession_array;
#     my $plot_ids = $ds->plots();
#     my $plant_ids = $ds->plants();
#	foreach (@nirs_protocol_ids){
#		print STDERR Dumper $_;

		my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
	        bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
	        nd_protocol_id=>'6',
	        high_dimensional_phenotype_type=>'NIRS',
	        query_associated_stocks=>0,
	        accession_list=>$stock_ids_arrayref,
	        plot_list=>undef,
	        plant_list=>undef
	    });
		my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
		print STDERR Dumper $data_matrix;
		my %data_matrix = %$data_matrix;
		push @data, {
            device_type=>$data_matrix{$stock_id}->{device_type},
			header_column_names=>$identifier_names,
            header_column_details=>undef,

        };
#	}
	print STDERR Dumper @data;

	my %result = (data => \@data);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs result constructed');
}

sub nirs_matrix {
	my $self = shift;
	my $nd_protocol_id = shift;

	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data_files;
	my $schema = $self->bcs_schema();
	my @nirs_protocol_ids;
	my @data;

	my @protocol_id_array;
	@protocol_id_array[0] = $nd_protocol_id;
	my $protocol_id_arrayref = \@protocol_id_array;

	my $verify_id = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$stock_id});
	if (!$verify_id) {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'ObservationUnitDbId does not exist in the database');
	}

	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();

	my $q = "SELECT nd_protocol_id FROM nd_protocol where type_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($high_dim_nirs_protocol_cvterm_id);

	while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
		push @nirs_protocol_ids, $nirs_protocol_id;
	}

	my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
		bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
		nd_protocol_id=>$protocol_id_arrayref,
		high_dimensional_phenotype_type=>'NIRS',
		query_associated_stocks=>1,
		accession_list=>undef,
		plot_list=>undef,
		plant_list=>undef
	});
	my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();

	my %data_matrix = %$data_matrix;
	push @data, {
		data_matrix=>$data_matrix{$stock_id}->{spectra},
	};

#	my $total_count = scalar(@result);
	my $total_count = 1;

	my %result = (data => \@data);

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs detail result constructed');
}

sub nirs_detail {
	my $self = shift;
	my $stock_id = shift;

	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data_files;
	my $schema = $self->bcs_schema();
	my @nirs_protocol_ids;
	my @data;

	my @stock_id_array;
	@stock_id_array[0] = $stock_id;
	my $stock_id_arrayref = \@stock_id_array;

	my $verify_id = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$stock_id});
	if (!$verify_id) {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'ObservationUnitDbId does not exist in the database');
	}

	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();

	my $q = "SELECT nd_protocol_id FROM nd_protocol where type_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($high_dim_nirs_protocol_cvterm_id);

	while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
		push @nirs_protocol_ids, $nirs_protocol_id;
	}

	my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
		bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
		nd_protocol_id=>'6',
		high_dimensional_phenotype_type=>'NIRS',
		query_associated_stocks=>0,
		accession_list=>$stock_id_arrayref,
		plot_list=>undef,
		plant_list=>undef
	});
	my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();

	my %data_matrix = %$data_matrix;
	push @data, {
		device_type=>$data_matrix{$stock_id}->{device_type},
		header_column_names=>$identifier_names,
		header_column_details=>undef,

	};

#	my $total_count = scalar(@result);
	my $total_count = 1;

	my %result = (data => \@data);

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs detail result constructed');
}
