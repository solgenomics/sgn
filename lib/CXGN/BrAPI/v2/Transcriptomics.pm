package CXGN::BrAPI::v2::Transcriptomics;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;
use JSON;

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
	my @transcriptomics_protocol_ids;
	my @transcriptomics_stock_ids;
	my $nd_protocol_id;
	my @data;
	my @data_files;
	my $total_count = 1;

	my $high_dim_transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();

	my $q = "SELECT nd_protocol_id FROM nd_protocol where type_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($high_dim_transcriptomics_protocol_cvterm_id);
	print STDERR Dumper $high_dim_transcriptomics_protocol_cvterm_id;

	while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
		push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
	}
	#print STDERR Dumper @transcriptomics_protocol_ids;

	for my $nd_protocol_id (@transcriptomics_protocol_ids) {

		if (! defined($stock_id_arrayref)) {
			my $q = "SELECT stock_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id = ?;";
			my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
			$h->execute($nd_protocol_id);

			while (my ($transcriptomics_stock_id) = $h->fetchrow_array()) {
				push @transcriptomics_stock_ids, $transcriptomics_stock_id;
			}
			$stock_id_arrayref = \@transcriptomics_stock_ids;
		}

		my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
	        bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
	        nd_protocol_id=>$nd_protocol_id,
	        high_dimensional_phenotype_type=>'Transcriptomics',
	        query_associated_stocks=>0,
	        accession_list=>$stock_id_arrayref,
	        plot_list=>undef,
	        plant_list=>undef
	    });
		my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
#		my $example_stock = @transcriptomics_stock_ids[0];
		my $example_stock = @$stock_id_arrayref[0];
		my %data_matrix = %$data_matrix;
		push @data, {
			device_type=>$data_matrix{$example_stock}->{device_type},
			header_column_names=>$identifier_names,
			protocol_id=>$nd_protocol_id,
	#		header_column_details=>undef,

		};
	}

	my %result = (data => \@data);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Transcriptomics result constructed');
}

sub transcriptomics_protocols {
    my $self = shift;
    my $inputs = shift;
    my $nd_protocol_id_arrayref = $inputs->{protocolDbId} || ($inputs->{protocolDbIds} || ());
    my $stock_id_arrayref = $inputs->{observationUnitDbId} || ($inputs->{observationUnitDbIds} || ());
    my $nd_protocol_id = @$nd_protocol_id_arrayref[0];
    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my @data_files;
    my $schema = $self->bcs_schema();
    my $transcriptomics_stock_ids;
    my $additional_info;
    my $external_references;
    my @transcriptomics_protocol_ids;

    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();
    my $high_dim_transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();
    my @data;

    if (! defined($stock_id_arrayref)) {
        if (!(@$nd_protocol_id_arrayref)) {
            my $q = "SELECT nd_protocol_id from nd_protocol WHERE type_id = ?";
            my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
            $h->execute($high_dim_transcriptomics_protocol_cvterm_id);
            while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
                push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
            }
        } else {
            @transcriptomics_protocol_ids = @$nd_protocol_id_arrayref;
        }
    } else {
		if (!(@$nd_protocol_id_arrayref)) {
			foreach my $stock_id (@$stock_id_arrayref) {
				my $q = "SELECT DISTINCT nd_protocol.nd_protocol_id FROM nd_experiment_stock JOIN nd_experiment_protocol USING (nd_experiment_id) JOIN nd_protocol USING (nd_protocol_id) WHERE nd_experiment_stock.stock_id = ?";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($stock_id);
				while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
					push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
				}
			}
		} else {
			foreach my $stock_id (@$stock_id_arrayref) {
				my $q = "SELECT DISTINCT nd_protocol.nd_protocol_id FROM nd_experiment_stock JOIN nd_experiment_protocol USING (nd_experiment_id) JOIN nd_protocol USING (nd_protocol_id) WHERE nd_experiment_stock.stock_id = ? AND nd_protocol.nd_protocol_id = ?";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($stock_id, $nd_protocol_id);
				while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
					push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
				}
			}
		}
	}

    foreach my $protocol_id (@transcriptomics_protocol_ids) {
        my $q = "SELECT nd_protocol.name, nd_protocol.description, nd_protocolprop.value
        FROM nd_protocol
        JOIN nd_protocolprop USING(nd_protocol_id)
        WHERE nd_protocol.nd_protocol_id = ? AND nd_protocol.type_id=$high_dim_transcriptomics_protocol_cvterm_id AND nd_protocolprop.type_id=$protocolprop_type_cvterm_id";
        my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
        $h->execute($protocol_id);
        while (my ($transcriptomics_protocol_name, $transcriptomics_protocol_description, $props_json) = $h->fetchrow_array()) {
            my $props = decode_json $props_json;
            my $layout = $props->{layout};
            my $read_length = $props->{read_length};
            my $library_methods = $props->{library_method};
            my $instrument_model = $props->{instrument_model};
            my $library_comments = $props->{library_comments};
            my $mapping_software = $props->{mapping_software};
            my $sequencing_software = $props->{sequencing_software};
            my $sequencing_platform = $props->{sequencing_platform};
            my $extraction_method = $props->{nucleic_acid_extraction_method};
            my $reference_genome;
            my $sequencing_center;
            my $units;
            my $annotation_file;
            my $counting_software;


            push @data, {
            additionalInfo => $additional_info,
            annotationFile => $annotation_file,
            countingSoftware => $counting_software,
            instrumentModel => $instrument_model,
            layout => $layout,
            libraryComments => $library_comments,
            libraryMethod => $library_methods,
            mappingSoftware => $mapping_software,
            nucleicAcidExtractionMethod => $extraction_method,
            readLength => $read_length,
            referenceGenome => $reference_genome,
            sequencingCenter => $sequencing_center,
            sequencingPlatform => $sequencing_platform,
            units => $units,
            externalReferences => $external_references,
            protocolDbId => $protocol_id,
            protocolDescription => $transcriptomics_protocol_description,
            protocolTitle => $transcriptomics_protocol_name
            };
        }
    }

    my $total_count = 1;
    my %result = (data => \@data);

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count, $page_size, $page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, "Transcriptomics protocol result constructed");
}

sub transcriptomics_instances {
	my $self = shift;
	my $inputs = shift;
	my $instance_id_arrayref = $inputs->{instanceDbId} || ($inputs->{instanceDbIds} || ());
	my $instance_id = @$instance_id_arrayref[0];
	my $nd_protocol_id_arrayref = $inputs->{protocolDbId} || ($inputs->{protocolDbIds} || ());
	my $nd_protocol_id = @$nd_protocol_id_arrayref[0];
	my $stock_id_arrayref = $inputs->{observationUnitDbId} || ($inputs->{observationUnitDbIds} || ());
	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data_files;
	my $schema = $self->bcs_schema();
	my @transcriptomics_stock_ids;
	my $additional_info;
	my $documentation_url;
	my $external_references;
	my @transcriptomics_protocol_ids;
	my @transcriptomics_protocol_names;
	my @transcriptomics_instance_ids;
	my $col_headers;
	my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();
	my $high_dim_transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();
	my @data;
	my @column_headers;
	my $research_purpose;
	my $sra_accession;

	if (! defined($stock_id_arrayref)) {
		if (!(@$nd_protocol_id_arrayref)) {
			if (! (@$instance_id_arrayref)) {
				my $q = "SELECT nd_protocol_id from nd_protocol where type_id = ?";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($high_dim_transcriptomics_protocol_cvterm_id);
				while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
					push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
				}
			} else {
				my $q = "SELECT DISTINCT nd_protocol.nd_protocol_id FROM metadata.md_files JOIN phenome.nd_experiment_md_files ON metadata.md_files.file_id = phenome.nd_experiment_md_files.file_id JOIN nd_experiment ON phenome.nd_experiment_md_files.nd_experiment_id = nd_experiment.nd_experiment_id JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id JOIN nd_protocolprop ON nd_protocol.nd_protocol_id = nd_protocolprop.nd_protocol_id WHERE metadata.md_files.file_id = ? AND nd_protocolprop.type_id = $protocolprop_type_cvterm_id AND nd_protocol.type_id = $high_dim_transcriptomics_protocol_cvterm_id";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($instance_id);
				while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
					push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
				}
			}
		} elsif (@$nd_protocol_id_arrayref) {
			@transcriptomics_protocol_ids = @$nd_protocol_id_arrayref;
		}
	} else {
		if (!(@$instance_id_arrayref) && !(@$nd_protocol_id_arrayref)) {
			foreach my $stock_id (@$stock_id_arrayref) {
				my $q = "SELECT DISTINCT nd_protocol.nd_protocol_id FROM nd_experiment_stock JOIN nd_experiment_protocol USING (nd_experiment_id) JOIN nd_protocol USING (nd_protocol_id) WHERE nd_experiment_stock.stock_id = ?";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($stock_id);
				while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
					push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
				}
			}
		}
		if (!(@$instance_id_arrayref) || @$nd_protocol_id_arrayref) {
			foreach my $stock_id (@$stock_id_arrayref) {
				my $q = "SELECT DISTINCT nd_protocol.nd_protocol_id FROM nd_experiment_stock JOIN nd_experiment_protocol USING (nd_experiment_id) JOIN nd_protocol USING (nd_protocol_id) WHERE nd_experiment_stock.stock_id = ? AND nd_protocol.nd_protocol_id = ?";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($stock_id, $nd_protocol_id);
				while (my ($transcriptomics_protocol_id) = $h->fetchrow_array()) {
					push @transcriptomics_protocol_ids, $transcriptomics_protocol_id;
				}
			}
		}
	}
	if (@$instance_id_arrayref) {
		if (@$nd_protocol_id_arrayref || $stock_id_arrayref) {
			foreach my $protocol_id (@transcriptomics_protocol_ids) {
				my $q = "SELECT DISTINCT metadata.md_files.file_id, nd_protocol.nd_protocol_id, nd_protocol.create_date, nd_protocolprop.value AS header_column_names FROM metadata.md_files JOIN phenome.nd_experiment_md_files ON metadata.md_files.file_id = phenome.nd_experiment_md_files.file_id JOIN nd_experiment ON phenome.nd_experiment_md_files.nd_experiment_id = nd_experiment.nd_experiment_id JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id JOIN nd_protocolprop ON nd_protocol.nd_protocol_id = nd_protocolprop.nd_protocol_id WHERE nd_protocol.nd_protocol_id = ? AND metadata.md_files.file_id = ? AND nd_protocolprop.type_id = $protocolprop_type_cvterm_id AND nd_protocol.type_id = $high_dim_transcriptomics_protocol_cvterm_id";
				my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
				$h->execute($protocol_id, $instance_id);
				while (my ($instance_id, $protocol_id, $create_date, $props_json) = $h->fetchrow_array) {
					my $props = decode_json $props_json;
					my $header_col_names = $props->{header_column_names};
					my $header_column_details = $props->{header_column_details};
					my @column_headers;
					foreach my $gene_id (sort keys %$header_column_details) {
						my $gene = $header_column_details->{$gene_id};

						push @column_headers, {
							geneId => $gene_id,
							chromosome => $gene->{chr},
							functionalAnnotation => $gene->{gene_desc},
							positionLeft => 0 + $gene->{start},
							positionRight => 0 + $gene->{end},
						};
					}
					push @data, {
						columnHeaders => \@column_headers,
						instanceDbId => $instance_id,
						protocolDbId => $protocol_id,
						uploadTimestamp => $create_date,
						researchPurpose => $research_purpose,
						sraAccession => $sra_accession
					};
				}
			}
		} else {
			my $q = "SELECT DISTINCT metadata.md_files.file_id, nd_protocol.nd_protocol_id, nd_protocol.create_date, nd_protocolprop.value AS header_column_names FROM metadata.md_files JOIN phenome.nd_experiment_md_files ON metadata.md_files.file_id = phenome.nd_experiment_md_files.file_id JOIN nd_experiment ON phenome.nd_experiment_md_files.nd_experiment_id = nd_experiment.nd_experiment_id JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id JOIN nd_protocolprop ON nd_protocol.nd_protocol_id = nd_protocolprop.nd_protocol_id WHERE metadata.md_files.file_id = ? AND nd_protocolprop.type_id = $protocolprop_type_cvterm_id AND nd_protocol.type_id = $high_dim_transcriptomics_protocol_cvterm_id";
			my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
			$h->execute($instance_id);
			while (my ($instance_id, $protocol_id, $create_date, $props_json) = $h->fetchrow_array) {
				my $props = decode_json $props_json;
				my $header_col_names = $props->{header_column_names};
				my $header_column_details = $props->{header_column_details};
				my @column_headers;
				foreach my $gene_id (sort keys %$header_column_details) {
					my $gene = $header_column_details->{$gene_id};

					push @column_headers, {
						geneId => $gene_id,
						chromosome => $gene->{chr},
						functionalAnnotation => $gene->{gene_desc},
						positionLeft => 0 + $gene->{start},
						positionRight => 0 + $gene->{end},
					};
				}
				push @data, {
					columnHeaders => \@column_headers,
					instanceDbId => $instance_id,
					protocolDbId => $protocol_id,
					uploadTimestamp => $create_date,
					researchPurpose => $research_purpose,
					sraAccession => $sra_accession
				};
			}
		}
	} else {
		foreach my $protocol_id (@transcriptomics_protocol_ids) {
			my $q = "SELECT DISTINCT metadata.md_files.file_id, nd_protocol.nd_protocol_id, nd_protocol.create_date, nd_protocolprop.value AS header_column_names FROM metadata.md_files JOIN phenome.nd_experiment_md_files ON metadata.md_files.file_id = phenome.nd_experiment_md_files.file_id JOIN nd_experiment ON phenome.nd_experiment_md_files.nd_experiment_id = nd_experiment.nd_experiment_id JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id JOIN nd_protocolprop ON nd_protocol.nd_protocol_id = nd_protocolprop.nd_protocol_id WHERE nd_protocol.nd_protocol_id = ? AND nd_protocolprop.type_id = $protocolprop_type_cvterm_id AND nd_protocol.type_id = $high_dim_transcriptomics_protocol_cvterm_id";
			my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
			$h->execute($protocol_id);
			while (my ($instance_id, $protocol_id, $create_date, $props_json) = $h->fetchrow_array) {
				my $props = decode_json $props_json;
				my $header_col_names = $props->{header_column_names};
				my $header_column_details = $props->{header_column_details};
				my @column_headers;
				foreach my $gene_id (sort keys %$header_column_details) {
					my $gene = $header_column_details->{$gene_id};

					push @column_headers, {
						geneId => $gene_id,
						chromosome => $gene->{chr},
						functionalAnnotation => $gene->{gene_desc},
						positionLeft => 0 + $gene->{start},
						positionRight => 0 + $gene->{end},
					};
				}

				push @data, {
					columnHeaders => \@column_headers,
					instanceDbId => $instance_id,
					protocolDbId => $protocol_id,
					uploadTimestamp => $create_date,
					researchPurpose => $research_purpose,
					sraAccession => $sra_accession
				};
			}
		}
	}

	my $total_count = 1;

	my %result = (data => \@data);

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'transcriptomics instance result constructed');

}

sub transcriptomics_matrix {
	my $self = shift;
#	my $c = shift;
	my $inputs = shift;
	my $nd_protocol_id_arrayref = $inputs->{protocolDbId} || ($inputs->{protocolDbIds} || ());
	my $nd_protocol_id = @$nd_protocol_id_arrayref[0];
	my $instance_id_arrayref = $inputs->{instanceDbId} || ($inputs->{instanceDbIds} || ());
	my $instance_id = @$instance_id_arrayref[0];
	my $stock_id_arrayref = $inputs->{observationUnitDbId} || ($inputs->{observationUnitDbIds} || ());
	my $trial_id = $inputs->{studyDbId} || $inputs->{studyDbIds} || ();
	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data_files;
	my $schema = $self->bcs_schema();
	my @transcriptomics_stock_ids;
	my @data;
    my @column_headers;
    my $upload_timestamp;
    my $sra_accession;
    my $research_purpose;
    my $comments;
    my $tissue_dev_stage;
    my $tissue_harvest_date;
    my $tissue_harvester;

    my $high_dim_tissue_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_type', 'stock_property')->cvterm_id();
    my $high_dim_accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();
    my $high_dim_transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();

	print STDERR "protocol id: $nd_protocol_id instance_id: $instance_id";

	if ($nd_protocol_id) {
		my $q = "SELECT nd_protocolprop.value
		FROM nd_protocol
		JOIN nd_protocolprop USING(nd_protocol_id)
		WHERE nd_protocol.nd_protocol_id = ? AND nd_protocol.type_id=$high_dim_transcriptomics_protocol_cvterm_id AND nd_protocolprop.type_id=$protocolprop_type_cvterm_id";
		my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
		$h->execute($nd_protocol_id);
		while (my ($props_json) = $h->fetchrow_array()) {
			my $response = decode_json $props_json;
			my $header_column_details = $response->{header_column_details};
			foreach my $gene_id (sort keys %$header_column_details) {
				my $gene = $header_column_details->{$gene_id};

				push @column_headers, {
					geneId => $gene_id,
					chromosome => $gene->{chr},
					functionalAnnotation => $gene->{gene_desc},
					positionLeft => 0 + $gene->{start},
					positionRight => 0 + $gene->{end},
				};
			}
		}
	} elsif ($instance_id) {
		my $q = " SELECT DISTINCT nd_protocol.nd_protocol_id, nd_protocolprop.value FROM metadata.md_files JOIN phenome.nd_experiment_md_files ON metadata.md_files.file_id = phenome.nd_experiment_md_files.file_id JOIN nd_experiment ON phenome.nd_experiment_md_files.nd_experiment_id = nd_experiment.nd_experiment_id JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id JOIN nd_protocolprop ON nd_protocol.nd_protocol_id = nd_protocolprop.nd_protocol_id WHERE metadata.md_files.file_id = ? AND nd_protocol.type_id = ? AND nd_protocolprop.type_id = ? ";		
		my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
		$h->execute( $instance_id, $high_dim_transcriptomics_protocol_cvterm_id, $protocolprop_type_cvterm_id );

		while (my ($protocol_id, $props_json) = $h->fetchrow_array()) {
			my $response = decode_json $props_json;
			my $header_column_details = $response->{header_column_details};
			$nd_protocol_id = $protocol_id;

			foreach my $gene_id (sort keys %$header_column_details) {
				my $gene = $header_column_details->{$gene_id};

				push @column_headers, {
					geneId => $gene_id,
					chromosome => $gene->{chr},
					functionalAnnotation => $gene->{gene_desc},
					positionLeft => 0 + $gene->{start},
					positionRight => 0 + $gene->{end},
				};
			}
		}
	} else {
		my $total_count = 1;
		my %result;
		my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
		return CXGN::BrAPI::JSONResponse->return_error($status, 'Transcriptomics matrix call must include a protocolDbId or an instanceDbId', 404);
	}


    if (! defined($stock_id_arrayref) || ! defined($instance_id)) {
        my $q = "SELECT stock_id FROM nd_protocol JOIN nd_experiment_protocol ON nd_protocol.nd_protocol_id = nd_experiment_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id=nd_experiment_stock.nd_experiment_id WHERE nd_protocol.nd_protocol_id = ?;";
        my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
        $h->execute($nd_protocol_id);

        while (my ($transcriptomics_stock_id) = $h->fetchrow_array()) {
            push @transcriptomics_stock_ids, $transcriptomics_stock_id;
        }
        $stock_id_arrayref = \@transcriptomics_stock_ids;
    } elsif ($instance_id) {
		my $q = "SELECT DISTINCT metadata.md_files.file_id, nd_protocol.nd_protocol_id, nd_experiment_stock.stock_id FROM metadata.md_files JOIN phenome.nd_experiment_md_files ON metadata.md_files.file_id = phenome.nd_experiment_md_files.file_id JOIN nd_experiment ON phenome.nd_experiment_md_files.nd_experiment_id = nd_experiment.nd_experiment_id JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id JOIN nd_experiment_stock ON nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id WHERE metadata.md_files.file_id = ?;";
		my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
		$h->execute($instance_id);

		while (my ($instance_id, $protocol_id, $transcriptomics_stock_id) = $h->fetchrow_array()) {
			push @transcriptomics_stock_ids, $transcriptomics_stock_id;
			$nd_protocol_id = $protocol_id;
		}
		$stock_id_arrayref = \@transcriptomics_stock_ids;
	} elsif (! defined($instance_id) || ! defined($nd_protocol_id)) {

	}
	#print STDERR Dumper \@transcriptomics_stock_ids;

	my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
		bcs_schema=>$schema,
		#nd_protocol_id=>$_,
		nd_protocol_id=>$nd_protocol_id,
		high_dimensional_phenotype_type=>'Transcriptomics',
		query_associated_stocks=>0,
		accession_list=>$stock_id_arrayref,
		plot_list=>undef,
		plant_list=>undef
	});
	my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
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
		my @transcriptomics_nd_experiment_ids;
		while (my ($transcriptomics_nd_experiment_id) = $h->fetchrow_array()) {
			push @transcriptomics_nd_experiment_ids, $transcriptomics_nd_experiment_id;
		}

		my $q = "SELECT project_id FROM nd_experiment_project WHERE nd_experiment_id=?;";
		my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
		$h->execute($transcriptomics_nd_experiment_ids[0]);
		my @transcriptomics_project_ids;
		while (my ($transcriptomics_project_id) = $h->fetchrow_array()) {
			push @transcriptomics_project_ids, $transcriptomics_project_id;
		}
		
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
			if (@transcriptomics_project_ids[0] == @$trial_id[0]) {
				my @current_row_values;
				# ordered keys was only included for verifying consistent order
				#my @ordered_keys;
				my $current_values = $data_matrix{$_}->{transcriptomics};
				my %current_values = %$current_values;

				foreach my $name (sort keys %current_values) {
					my $curr_val = $current_values{$name};
					push @current_row_values, $curr_val;
					# ordered keys was only included for verifying consistent order
		#			push @ordered_keys, $name;
				}
				push @data, {
					observationUnitDbId=>$_,
					observationUnitName=>$stock_uniquenames[0],
					sampleDbId=>$_,
					studyDbId=>$transcriptomics_project_ids[0],
					tissueType=>@stock_tissue_types[0],
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
                my $current_values = $data_matrix{$_}->{transcriptomics};
                my %current_values = %$current_values;

                foreach my $name (sort keys %current_values) {
                    my $curr_val = $current_values{$name};
                    push @current_row_values, $curr_val;

                }
                push @data, {

                    observationUnitDbId=>$_,
                    observationUnitName=>$stock_uniquenames[0],
                    sampleDbId=>$_,
                    studyDbId=>$transcriptomics_project_ids[0],
                    tissueType=>@stock_tissue_types[0],
                    germplasmName=>@stock_accession_names[0],
                    germplasmDbId=>@stock_germplasm_dbids[0],
                    comments=>$comments,
                    row=>\@current_row_values,
                    tissueDevStage=>$tissue_dev_stage,
                    tissueHarvestDate=>$tissue_harvest_date,
                    tissueHarvester=>$tissue_harvester
                };
            };
        }

	my $total_count = 1;
	my %result = (
        columnHeaders => \@column_headers,
        data => \@data,
        protocolDbId => $nd_protocol_id,
        instanceDbId => $instance_id,
        researchPurpose => $research_purpose,
        sraAccession => $sra_accession,
        uploadTimestamp => $upload_timestamp
        );

	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Transcriptomics matrix result constructed');
}

1;