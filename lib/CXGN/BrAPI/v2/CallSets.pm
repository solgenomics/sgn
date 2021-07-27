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
    my $sample_ids = $inputs->{sampleDbId} || ($inputs->{sampleDbIds} || ());
    my $sample_names = $inputs->{sampleName} || ($inputs->{sampleNames} || ());
    my $variantset_ids = $inputs->{variantSetDbId} || ($inputs->{variantSetDbIds} || ());
    my $study_ids = $inputs->{studyDbId} || ($inputs->{studyDbIds} || ());
    my $callset_ids = $inputs->{callSetDbId} || ($inputs->{callSetDbIds} || ());
    my $callset_names = $inputs->{callSetName} || ($inputs->{callSetNames} || ());
    my $germplasm_ids = $inputs->{germplasmDbId} || ($inputs->{germplasmDbIds} || ());
    my $germplasm_names = $inputs->{germplasmName} || ($inputs->{germplasmNames} || ());

    my @trial_ids;
    my @protocol_ids;
    my @accession_ids;
    my @callset_names;

    if ($callset_names){
        push @callset_names, @{$callset_names};      
    }
    if ($sample_names){
        push @callset_names, @{$sample_names};      
    }
    if ($study_ids){
        push @trial_ids, @{$study_ids};
    }
    if ($callset_ids){
        push @accession_ids, @{$callset_ids};
    }
    if ($sample_ids){
        push @accession_ids, @{$sample_ids};
    }
    if ($variantset_ids){
        foreach ( @{$variantset_ids} ){
            my @ids = split /p/, $_;
            push @trial_ids, $ids[0] ? $ids[0] : ();
            push @protocol_ids, $ids[1] ? $ids[1] : ();
        }
    }

    if (scalar @trial_ids == 0){
        my $trial_search = CXGN::Trial::Search->new({
            bcs_schema=>$self->bcs_schema,
            trial_design_list=>['genotype_data_project']
        });
        my ($data, $total_count) = $trial_search->search(); 

        foreach (@$data){
            push @trial_ids, $_->{trial_id};
        }
    }

    my $genotypes_search = CXGN::Genotype::Search->new({
        trial_list=>\@trial_ids,
        bcs_schema=>$self->bcs_schema,
        people_schema => $self->people_schema(),
        cache_root=>$c->config->{cache_file_path},
        genotypeprop_hash_select=>['DS', 'GT', 'NT'],
        accession_list=>\@accession_ids,
        protocol_id_list=>\@protocol_ids,
    });

    my $file_handle = $genotypes_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 1); #Metadata only returned

    my %geno;
    my @variantsets;
    my @studies;
    my $passes_search;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;
    my @data;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    
    while( <$fh> ) {
        my $gt = decode_json $_;

        $passes_search = 1;

        if ( $germplasm_ids && !grep { $_ eq $gt->{germplasmDbId}} @{$germplasm_ids} ) { $passes_search = 0;};
        if ( $germplasm_names && !grep { $_ eq $gt->{germplasmName}} @{$germplasm_names} ) { $passes_search = 0;};
        if ( scalar(@callset_names)>0 && !grep { $_ eq $gt->{stock_name}} @callset_names ) { $passes_search = 0;};

        if ($passes_search){

            if (! exists($geno{$gt->{stock_id}})){
                @variantsets = (); 
                @studies = ();
            }
            my $variantset = $gt->{genotypingDataProjectDbId} . "p" . $gt->{analysisMethodDbId};
            push @variantsets, $variantset if !grep{/^$variantset$/}@variantsets;
            push @studies, qq|$gt->{genotypingDataProjectDbId}| if !grep{/^$gt->{genotypingDataProjectDbId}$/}@studies;

            $geno{$gt->{stock_id}} = {
                    callSetName => $gt->{stock_name},
                    germplasmDbId => $gt->{germplasmDbId},
                    variantSetDbIds=>[@variantsets],
                    studyDbIds=>[@studies],
            };
        }
    }

    foreach my $genoid (keys %geno) {
        if ($counter >= $start_index && $counter <= $end_index) {
            push @data, {
                additionalInfo=>{germplasmDbId=>qq|$geno{$genoid}{germplasmDbId}|},
                callSetDbId=>qq|$genoid|,
                callSetName=>qq|$geno{$genoid}{callSetName}|,
                created=>undef,
                sampleDbId=>qq|$genoid|,
                studyDbId=>$geno{$genoid}{studyDbIds},
                updated=>undef,
                variantSetDbIds=>$geno{$genoid}{variantSetDbIds},
            };
        }
        $counter++;
    }

    if (scalar @data < 1) { @data = ""};
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
        people_schema => $self->people_schema(),
        cache_root=>$c->config->{cache_file_path},
        accession_list=>[$callset_id],
        genotypeprop_hash_select=>['DS', 'GT', 'NT'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[]
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 1);

    my $counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    my @data;
    my %geno;
    my @variantsets;
    my @studies;

    while( <$fh> ) {
        my $gt = decode_json $_;     

        if (! exists($geno{$gt->{stock_id}})){
            @variantsets = ();
            @studies = ();
        }
        my $variantset = $gt->{genotypingDataProjectDbId} . "p" . $gt->{analysisMethodDbId};
        push @variantsets, $variantset if !grep{/^$variantset$/}@variantsets;
        push @studies, qq|$gt->{genotypingDataProjectDbId}| if !grep{/^$gt->{genotypingDataProjectDbId}$/}@studies;

        $geno{$gt->{stock_id}} = {
                callSetName => $gt->{stock_name},
                germplasmDbId => $gt->{germplasmDbId},
                variantSetDbIds=>\@variantsets,
                studyDbIds=>[@studies],
        };
    }

    foreach my $genoid (keys %geno) {
        push @data, {
            additionalInfo=>{germplasmDbId=>qq|$geno{$genoid}{germplasmDbId}|},
            callSetDbId=>qq|$genoid|,
            callSetName=>qq|$geno{$genoid}{callSetName}|,
            created=>undef,
            sampleDbId=>qq|$genoid|,
            studyDbId=>$geno{$genoid}{studyDbIds},
            updated=>undef,
            variantSetDbIds=>$geno{$genoid}{variantSetDbIds},
        };
        $counter++;
    }

    if (scalar @data < 1) { @data = {}; };
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(@data, $pagination, \@data_files, $status, 'CallSets detail result constructed');
}


sub calls {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @callset_id = $inputs->{callset_id};
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
        people_schema => $self->people_schema(),
        cache_root=>$c->config->{cache_file_path},
        accession_list=>[@callset_id],
        genotypeprop_hash_select=>['DS', 'GT', 'NT'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 0);

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
                    callSetDbId=>qq|$gt->{stock_id}|,
                    callSetName=>qq|$gt->{stock_name}|,
                    genotype=>{values=>$geno},
                    genotype_likelihood=>undef,
                    phaseSet=>undef,
                };
            }
            $counter++;
        }
    }


    my @scores_seen;
    if (!$data_format || $data_format eq 'json' ){

        %result = ( data=>\@scores,
            expandHomozygotes=>undef, 
            sepPhased=>undef, 
            sepUnphased=>undef, 
            unknownString=>undef);

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
