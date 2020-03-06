package CXGN::BrAPI::v2::CallSets;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
use JSON;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @callset_id = $inputs->{callSetDbId}? @{$inputs->{callSetDbId}} : ();
    my @callset_names = $inputs->{callSetName} ? @{$inputs->{callSetName}} : ();
    my @germplasm_ids = $inputs->{germplasmDbId} ? @{$inputs->{germplasmDbId}} : ();
    # my @study_ids = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @variant_ids = $inputs->{variantSetDbId} ? @{$inputs->{variantSetDbId}} : ();
    my @sample_ids = $inputs->{sampleDbId} ? @{$inputs->{sampleDbId}} : ();

    if (scalar(@variant_ids)>0){
        push @$status, { 'error' => 'Search parameter variantSetDbId not supported' };
    }
    if (scalar(@sample_ids)>0){
        push @$status, { 'error' => 'Search parameter sampleDbId not supported' };
    }
    if (scalar(@callset_names)>0){
        push @$status, { 'error' => 'Search parameter callSetName not supported' };
    }

    my $genotypes_search = CXGN::Genotype::Search->new({
        # trial_list=>\@study_ids,
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        markerprofile_id_list=>\@callset_id,
        accession_list=>\@germplasm_ids,
        # offset=>$page_size*$page,
        # limit=>$page_size
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c, 1); #Metadata only returned
    # my $file_handle1 = $genotypes_search->get_cached_file_search_json($c, 0);

    my @data;
 # print Dumper $file_handle;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;


    # open my $fh1, "<&", $file_handle1 or die "Can't open output file: $!";
    # my $header_line1 = <$fh1>;

    # my $marker_objects = decode_json $header_line1;
    # my $gt_line = <$fh1>;
    # my $gt = decode_json $gt_line;
    # my $genotype = $gt->{selected_genotype_hash};

    # my @variants;
    # foreach my $m_obj (@$marker_objects) {
    #     my $m = $m_obj->{name};
    #     if ($counter >= $start_index && $counter <= $end_index) {
    #         my $geno = '';
    #         if (exists($genotype->{$m}->{'NT'}) && defined($genotype->{$m}->{'NT'})){
    #             $geno = $genotype->{$m}->{'NT'};
    #         }
    #         elsif (exists($genotype->{$m}->{'GT'}) && defined($genotype->{$m}->{'GT'})){
    #             $geno = $genotype->{$m}->{'GT'};
    #         }
    #         elsif (exists($genotype->{$m}->{'DS'}) && defined($genotype->{$m}->{'DS'})){
    #             $geno = $genotype->{$m}->{'DS'};
    #         }
    #         push @variants, {$m => $geno};
    #     }
    #     $counter++;
    # }

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    
    while( <$fh> ) {
        if ($counter >= $start_index && $counter <= $end_index) {
            my $gt = decode_json $_;
            push @data, {
                callSetDbId => qq|$gt->{markerProfileDbId}|,
                callSetName => undef,
                created => undef,
                sampleDbId => qq|$gt->{stock_id}|,
                sampleName => qq|$gt->{stock_name}|,
                studyDbId => qq|$gt->{genotypingDataProjectDbId}|,
                updated => undef,
                variantSetIds => undef #\@variants
            };
        }
        $counter++;
    }


    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'CallSets result constructed');
}

sub detail {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $callset_id = $inputs->{callset_id};
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};

    if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
        push @$status, {'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased'};
    }

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        markerprofile_id_list=>[$callset_id],
        genotypeprop_hash_select=>['DS', 'GT', 'NT'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c, 0);

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    my $marker_objects = decode_json $header_line;
    my $gt_line = <$fh>;
    my $gt = decode_json $gt_line;
    my $genotype = $gt->{selected_genotype_hash};

    my @data;
    foreach my $m_obj (@$marker_objects) {
        my $m = $m_obj->{name};
        if ($counter >= $start_index && $counter <= $end_index) {
            push @data, $m;
        }
        $counter++;
    }

    my %result = (
        additionalInfo=>{analysisMethod=>$gt->{analysisMethod},germplasmDbId=>qq|$gt->{germplasmDbId}|,uniqueDisplayName=>$gt->{genotypeUniquename}},
        callSetDbId=>qq|$gt->{markerProfileDbId}|,
        callSetName=>undef,
        created=>undef,
        sampleDbId=>qq|$gt->{stock_id}|,
        studyDbId=>qq|$gt->{genotypingDataProjectDbId}|,
        updated=>undef,
        variantSetIds=> \@data
    );
    my $pagination;
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles detail result constructed');
}


sub calls {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @callset_id = $inputs->{callset_id};
    my @marker_ids = $inputs->{marker_ids} ? @{$inputs->{marker_ids}} : ();
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};
    my $data_format = 'json'; # $inputs->{format};
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

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        markerprofile_id_list=>\@callset_id,
        genotypeprop_hash_select=>['DS', 'GT', 'NT'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c, 0);

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    my $marker_objects = decode_json $header_line;

    my @data;
    my @scores;
    while (my $gt_line = <$fh>) {
        my $gt = decode_json $gt_line;
        my $genotype = $gt->{selected_genotype_hash};
        my @ordered_refmarkers = sort keys(%$genotype);
        my $genotypeprop_id = $gt->{markerProfileDbId};

        foreach my $m (@ordered_refmarkers) {
            if ($counter >= $start_index && $counter <= $end_index) {
                my $geno = '';
                if (exists($genotype->{$m}->{'NT'}) && defined($genotype->{$m}->{'NT'})){
                    $geno = $genotype->{$m}->{'NT'};
                }
                elsif (exists($genotype->{$m}->{'GT'}) && defined($genotype->{$m}->{'GT'})){
                    $geno = $genotype->{$m}->{'GT'};
                }
                elsif (exists($genotype->{$m}->{'DS'}) && defined($genotype->{$m}->{'DS'})){
                    $geno = $genotype->{$m}->{'DS'};
                }
                push @scores, {
                    additionalInfo=>undef,
                    variantName=>qq|$m|,
                    variantDbId=>qq|$m|,
                    callSetDbId=>qq|$genotypeprop_id|,
                    callSetName=>qq|$genotypeprop_id|,
                    genotype=>{values=>$geno},
                    genotype_likelihood=>undef,
                    phaseSet=>undef,                    
                    expandHomozygotes=>undef, 
                    sepPhased=>undef, 
                    sepUnphased=>undef, 
                    unknownString=>undef
                };
            }
            $counter++;
        }
    }
    #print STDERR Dumper \@scores;

    my @scores_seen;
    if (!$data_format || $data_format eq 'json' ){

        %result = (data=>\@scores);

    } elsif ($data_format eq 'tsv' || $data_format eq 'csv' || $data_format eq 'xls') {

        # my @data = (['marker', 'markerprofileDbId', 'genotype'], @scores);

        # my $file_response = CXGN::BrAPI::FileResponse->new({
        #     absolute_file_path => $file_path,
        #     absolute_file_uri => $inputs->{main_production_site_url}.$uri,
        #     format => $data_format,
        #     data => \@data
        # });
        # @data_files = $file_response->get_datafiles();
    }

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Markerprofiles allelematrix result constructed');
}

1;
