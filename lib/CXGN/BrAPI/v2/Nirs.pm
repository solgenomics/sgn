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
	my $inputs = shift;
	my $c = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
    my $status = $self->status;
	my $schema = $self->bcs_schema();
	my $stock_id_arrayref = $inputs->{observationUnitDbId} || ($inputs->{observationUnitDbIds} || ());
#	my $stock_id = @$stock_ids_arrayref[0];
	my @nirs_protocol_ids;
	my @nirs_stock_ids;
	my $nd_protocol_id;
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

	for $nd_protocol_id (@nirs_protocol_ids) {
#	$nd_protocol_id = @nirs_protocol_ids[0];
	print STDERR Dumper $nd_protocol_id;

	if (! defined($stock_id_arrayref)) {
	my $q = "SELECT stock_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($nd_protocol_id);

	while (my ($nirs_stock_id) = $h->fetchrow_array()) {
		push @nirs_stock_ids, $nirs_stock_id;
	}
	$stock_id_arrayref = \@nirs_stock_ids;
	}

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
	        nd_protocol_id=>$nd_protocol_id,
	        high_dimensional_phenotype_type=>'NIRS',
	        query_associated_stocks=>0,
	        accession_list=>$stock_id_arrayref,
	        plot_list=>undef,
	        plant_list=>undef
	    });
		my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
#		my $example_stock = @nirs_stock_ids[0];
		my $example_stock = @$stock_id_arrayref[0];
		my %data_matrix = %$data_matrix;
		push @data, {
			device_type=>$data_matrix{$example_stock}->{device_type},
			header_column_names=>$identifier_names,
			protocol_id=>$nd_protocol_id,
	#		header_column_details=>undef,

		};
	}
	print STDERR Dumper @data;

	my %result = (data => \@data);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs result constructed');
}

# sub nirs_material {
# 	my $self = shift;
# 	my $inputs = shift;
# 	my $c = shift;
# 	my $page_size = $self->page_size;
# 	my $page = $self->page;
#     my $status = $self->status;
# 	my $schema = $self->bcs_schema();
# 	my $stock_id_arrayref = $inputs->{observationUnitDbId} || ($inputs->{observationUnitDbIds} || ());
# #	my $stock_id = @$stock_ids_arrayref[0];
# 	my @nirs_protocol_ids;
# 	my @nirs_stock_ids;
# 	my @nirs_material_ids;
# 	my $nd_protocol_id;
# 	my $nirs_material_id;
# 	my @data;
# 	my @data_files;
# 	my $total_count = 1;
#
# 	my $high_dim_material_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_type', 'stock_property')->cvterm_id();
# 	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();
#
# 	my $q = "SELECT nd_protocol_id FROM nd_protocol where type_id = ?;";
# 	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
# 	$h->execute($high_dim_nirs_protocol_cvterm_id);
# 	print STDERR Dumper $high_dim_material_cvterm_id;
#
# 	while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
# 		push @nirs_protocol_ids, $nirs_protocol_id;
# 	}
# 	print STDERR Dumper @nirs_protocol_ids;
#
# 	for $nd_protocol_id (@nirs_protocol_ids) {
# #	$nd_protocol_id = @nirs_protocol_ids[0];
# 	# print STDERR Dumper $nd_protocol_id;
# 	#
# 	# if (! defined($stock_id_arrayref)) {
# 	# my $q = "SELECT stock_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id = ?;";
# 	# my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
# 	# $h->execute($nd_protocol_id);
# 	#
# 	# while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
# 	# 	push @nirs_stock_ids, $nirs_stock_id;
# 	# }
# 	# $stock_id_arrayref = \@nirs_stock_ids;
# 	# }
#
# 	my $q = "SELECT distinct(value) FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id JOIN stockprop ON nd_experiment_stock.stock_id=stockprop.stock_id WHERE nd_protocol.nd_protocol_id = ? and stockprop.type_id = ?;";
# 	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
# 	$h->execute($nd_protocol_id,$high_dim_material_cvterm_id);
#
# 	while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
# 		push @nirs_material_ids, $nirs_material_id;
# 	}
# 	$stock_id_arrayref = \@nirs_material_ids;
#
#
# # 	my $accession_ids = $ds->accessions();
# #	my @accession_array = ['41786'];
# #	my $accession_ids = \@accession_array;
# #     my $plot_ids = $ds->plots();
# #     my $plant_ids = $ds->plants();
# #	foreach (@nirs_protocol_ids){
# #		print STDERR Dumper $_;
#
# # 		my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
# # 	        bcs_schema=>$schema,
# # #	        nd_protocol_id=>$_,
# # 	        nd_protocol_id=>$nd_protocol_id,
# # 	        high_dimensional_phenotype_type=>'NIRS',
# # 	        query_associated_stocks=>0,
# # 	        accession_list=>$stock_id_arrayref,
# # 	        plot_list=>undef,
# # 	        plant_list=>undef
# # 	    });
# # 		my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
# # #		my $example_stock = @nirs_stock_ids[0];
# # 		my $example_stock = @$stock_id_arrayref[0];
# # 		my %data_matrix = %$data_matrix;
# 		push @data, {
# 			materials=>@nirs_material_ids,
# 			protocol_id=>$nd_protocol_id,
# 	#		header_column_details=>undef,
#
# 		};
# 	}
# 	print STDERR Dumper @data;
#
# 	my %result = (data => \@data);
# 	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
# 	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs result constructed');
# }\

sub nirs_protocols {
	my $self = shift;
	my $nd_protocol_id = shift;
	my $inputs = shift;
	
	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data_files;
	my $schema = $self->bcs_schema();
	my @nirs_stock_ids;
	my $additional_info;
	my $device_frequency_number;
	my $documentation_url;
	my $external_references;
	my @nirs_protocol_ids;
	my @nirs_protocol_names;
	my @nirs_protocol_descriptions;
	my @data;

	my $q = "SELECT stock_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($nd_protocol_id);

	while (my ($nirs_stock_id) = $h->fetchrow_array()) {
		push @nirs_stock_ids, $nirs_stock_id;
	}

	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();

	my $q = "SELECT name FROM nd_protocol WHERE type_id = ? AND nd_protocol_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($high_dim_nirs_protocol_cvterm_id, $nd_protocol_id);
	while (my ($nirs_protocol_name) = $h->fetchrow_array()) {
		push @nirs_protocol_names, $nirs_protocol_name;
	}

	my $q = "SELECT description FROM nd_protocol WHERE type_id = ? AND nd_protocol_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($high_dim_nirs_protocol_cvterm_id, $nd_protocol_id);
	while (my ($nirs_protocol_description) = $h-> fetchrow_array()) {
		push @nirs_protocol_descriptions, $nirs_protocol_description;
	}

	my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
		bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
		nd_protocol_id=>$nd_protocol_id,
		high_dimensional_phenotype_type=>'NIRS',
		query_associated_stocks=>0,
		accession_list=>\@nirs_stock_ids,
		plot_list=>undef,
		plant_list=>undef
	});
	my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
	my $example_stock = @nirs_stock_ids[0];
	my %data_matrix = %$data_matrix;

	push @data, {
		additionalInfo => $additional_info,
		deviceFrequencyNumber => $device_frequency_number,
		deviceType => $data_matrix{$example_stock}->{device_type},
		documentationURL => $documentation_url,
		externalReferences => $external_references,
		protocolDbId => $nd_protocol_id,
		protocolDescription => @nirs_protocol_descriptions[0],
		protocolTitle => @nirs_protocol_names[0]
	};

	my $total_count = 1;

	my %result = (data => \@data);

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs protocol result constructed');

}

sub nirs_matrix {
	my $self = shift;
#	my $c = shift;
	my $nd_protocol_id = shift;
	my $inputs = shift;
	my $stock_id_arrayref = $inputs->{observationUnitDbId} || ($inputs->{observationUnitDbIds} || ());
	my $trial_id = $inputs->{studyDbId} || $inputs->{studyDbIds} || ();
	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data_files;
	my $schema = $self->bcs_schema();
	my @nirs_stock_ids;
	my @data;

#	print STDERR Dumper $trial_id;
#	my @protocol_id_array;
#	@protocol_id_array[0] = $nd_protocol_id;
#	my $protocol_id_arrayref = \@protocol_id_array;
my $high_dim_tissue_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_type', 'stock_property')->cvterm_id();
my $high_dim_accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

#	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();
if (! defined($stock_id_arrayref)) {
	my $q = "SELECT stock_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($nd_protocol_id);

	while (my ($nirs_stock_id) = $h->fetchrow_array()) {
		push @nirs_stock_ids, $nirs_stock_id;
	}
	$stock_id_arrayref = \@nirs_stock_ids;
}
#	print STDERR Dumper \@nirs_stock_ids;

	my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
		bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
		nd_protocol_id=>$nd_protocol_id,
		high_dimensional_phenotype_type=>'NIRS',
		query_associated_stocks=>0,
		accession_list=>$stock_id_arrayref,
#		accession_list=>undef,
		plot_list=>undef,
#		plot_list=>$stock_id_arrayref,
		plant_list=>undef
	});
	my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
#	print STDERR Dumper $identifier_metadata;
	my %data_matrix = %$data_matrix;

	foreach (@$stock_id_arrayref) {

		my $q = "SELECT uniquename FROM stock WHERE stock_id=?;";
		my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
		$h->execute($_);
		my @stock_uniquenames;
		while (my ($stock_uniquename) = $h->fetchrow_array()) {
			push @stock_uniquenames, $stock_uniquename;
		}

				my $q = "SELECT nd_experiment_protocol.nd_experiment_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id=? AND stock_id=?;";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($nd_protocol_id,$_);
				my @nirs_nd_experiment_ids;
				while (my ($nirs_nd_experiment_id) = $h->fetchrow_array()) {
					push @nirs_nd_experiment_ids, $nirs_nd_experiment_id;
				}

				my $q = "SELECT project_id FROM nd_experiment_project WHERE nd_experiment_id=?;";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($nirs_nd_experiment_ids[0]);
				my @nirs_project_ids;
				while (my ($nirs_project_id) = $h->fetchrow_array()) {
					push @nirs_project_ids, $nirs_project_id;
				}

#				my $q = "SELECT project_id FROM nd_experiment_project WHERE nd_experiment_id=?;";
#				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
#				$h->execute($nirs_nd_experiment_ids[0]);
#				my @nirs_project_ids;
#				while (my ($nirs_project_id) = $h->fetchrow_array()) {
#					push @nirs_project_ids, $nirs_project_id;
#				}

				my $q = "SELECT value FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id JOIN stockprop ON nd_experiment_stock.stock_id=stockprop.stock_id WHERE nd_protocol.nd_protocol_id = ? and stockprop.type_id = ? and stockprop.stock_id = ?;";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($nd_protocol_id,$high_dim_tissue_cvterm_id,$_);
				my @stock_tissue_types;
				while (my ($stock_tissue_type) = $h->fetchrow_array()) {
					push @stock_tissue_types, $stock_tissue_type;
				}

				my $q = "SELECT acc.uniquename FROM stock AS acc JOIN stock_relationship ON acc.stock_id = stock_relationship.object_id JOIN stock AS tiss ON stock_relationship.subject_id = tiss.stock_id WHERE tiss.stock_id = ? AND acc.type_id = ?;";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($_,$high_dim_accession_cvterm_id);
				my @stock_accession_names;
				while (my ($stock_accession_name) = $h->fetchrow_array()) {
					push @stock_accession_names, $stock_accession_name;
				}

				my $q = "SELECT acc.stock_id FROM stock AS acc JOIN stock_relationship ON acc.stock_id = stock_relationship.object_id JOIN stock AS tiss ON stock_relationship.subject_id = tiss.stock_id WHERE tiss.stock_id = ? AND acc.type_id = ?;";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($_,$high_dim_accession_cvterm_id);
				my @stock_germplasm_dbids;
				while (my ($stock_germplasm_dbid) = $h->fetchrow_array()) {
					push @stock_germplasm_dbids, $stock_germplasm_dbid;
				}

if (defined($trial_id)) {

#		print STDERR Dumper @nirs_nd_experiment_ids;
		if (@nirs_project_ids[0] == @$trial_id[0]) {
			my @current_row_values;
			# ordered keys was only included for verifying consistent order
			#my @ordered_keys;
			my $current_values = $data_matrix{$_}->{spectra};
			my %current_values = %$current_values;
	#		print STDERR Dumper $current_values;
	#		print STDERR Dumper %current_values;
			foreach my $name (sort keys %current_values) {
				my $curr_val = $current_values{$name};
	#			print STDERR Dumper $curr_val;
				push @current_row_values, $curr_val;
				# ordered keys was only included for verifying consistent order
	#			push @ordered_keys, $name;
			}
	#		print STDERR Dumper @current_row_values;
			push @data, {
	#			data_matrix=>$data_matrix{$stock_id}->{spectra},
			#	data_matrix=>$data_matrix,
				observationUnitDbId=>$_,
				observationUnitName=>$stock_uniquenames[0],
				sampleDbId=>$_,
#				nd_experiment_id=>$nirs_nd_experiment_ids[0],
				studyDbId=>$nirs_project_ids[0],
				tissue_type=>@stock_tissue_types[0],
				germplasmName=>@stock_accession_names[0],
				germplasmDbId=>@stock_germplasm_dbids[0],
				# ordered keys was only included for verifying consistent order
	#			labels=>\@ordered_keys,
				row=>\@current_row_values,
			};
		};
} else {
		my @current_row_values;
		# ordered keys was only included for verifying consistent order
		#my @ordered_keys;
		my $current_values = $data_matrix{$_}->{spectra};
		my %current_values = %$current_values;
#		print STDERR Dumper $current_values;
#		print STDERR Dumper %current_values;
		foreach my $name (sort keys %current_values) {
			my $curr_val = $current_values{$name};
#			print STDERR Dumper $curr_val;
			push @current_row_values, $curr_val;
			# ordered keys was only included for verifying consistent order
#			push @ordered_keys, $name;
		}
#		print STDERR Dumper @current_row_values;
		push @data, {
#			data_matrix=>$data_matrix{$stock_id}->{spectra},
		#	data_matrix=>$data_matrix,
			observationUnitDbId=>$_,
			observationUnitName=>$stock_uniquenames[0],
			sampleDbId=>$_,
#				nd_experiment_id=>$nirs_nd_experiment_ids[0],
			studyDbId=>$nirs_project_ids[0],
			tissue_type=>@stock_tissue_types[0],
			germplasmName=>@stock_accession_names[0],
			germplasmDbId=>@stock_germplasm_dbids[0],
			# ordered keys was only included for verifying consistent order
#			labels=>\@ordered_keys,
			row=>\@current_row_values,
		};
	};
	}

#	my $total_count = scalar(@result);
	my $total_count = 1;

	my %result = (data => \@data);

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs detail result constructed');
}

sub nirs_detail {
	my $self = shift;
	my $nd_protocol_id = shift;

	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data_files;
	my $schema = $self->bcs_schema();
	my @nirs_stock_ids;
	my @data;

	my $q = "SELECT stock_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($nd_protocol_id);

	while (my ($nirs_stock_id) = $h->fetchrow_array()) {
		push @nirs_stock_ids, $nirs_stock_id;
	}

#	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();

#	my $q = "SELECT nd_protocol_id FROM nd_protocol where type_id = ?;";
#	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
#	$h->execute($high_dim_nirs_protocol_cvterm_id);

#	while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
#		push @nirs_protocol_ids, $nirs_protocol_id;
#	}

	my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
		bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
		nd_protocol_id=>$nd_protocol_id,
		high_dimensional_phenotype_type=>'NIRS',
		query_associated_stocks=>0,
		accession_list=>\@nirs_stock_ids,
		plot_list=>undef,
		plant_list=>undef
	});
	my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
	my $example_stock = @nirs_stock_ids[0];
	my %data_matrix = %$data_matrix;
	push @data, {
		device_type=>$data_matrix{$example_stock}->{device_type},
		header_column_names=>$identifier_names,
#		header_column_details=>undef,

	};

#	my $total_count = scalar(@result);
	my $total_count = 1;

	my %result = (data => \@data);

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs detail result constructed');
}
