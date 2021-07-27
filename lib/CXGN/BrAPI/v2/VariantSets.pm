package CXGN::BrAPI::v2::VariantSets;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
use JSON;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use List::Util qw(sum);

extends 'CXGN::BrAPI::v2::Common';


sub search {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_ids = $inputs->{variantSetDbId} || ($inputs->{variantSetDbIds} || ());
    my $study_ids = $inputs->{studyDbId} || ($inputs->{studyDbIds} || ());
    my $study_names = $inputs->{studyName} || ($inputs->{studyNames} || ());
    my $variant_id = $inputs->{variantDbId} || ($inputs->{variantDbIds} || ());
    my $callset_id = $inputs->{callSetDbId} || ($inputs->{callSetDbIds} || ());

    my @trial_ids;
    my @protocol_ids;
    if ( $variantset_ids){
        foreach ( @{$variantset_ids} ){
            my @ids = split /p/, $_;
            if(scalar @ids>1){
                push @trial_ids, $ids[0] ? $ids[0] : ();
                push @protocol_ids, $ids[1] ? $ids[1] : ();
            } else{
                push @trial_ids, 0;
            }
        }
    }
    if ($study_ids){
        push @trial_ids, @{$study_ids};
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
    
    my $genotype_search = CXGN::Genotype::Search->new({
            bcs_schema=>$self->bcs_schema,
            people_schema => $self->people_schema(),
            cache_root=>$c->config->{cache_file_path},
            trial_list=>\@trial_ids,
            genotypeprop_hash_select=>['DS'],
            protocolprop_top_key_select=>[],
            protocolprop_marker_hash_select=>[],
            accession_list=>$callset_id,
            protocol_id_list=>\@protocol_ids,
    });

    my %variant_sets;

    $genotype_search->init_genotype_iterator();

    while (my ($count, $gt) = $genotype_search->get_next_genotype_info) {

        if( ! $study_names || grep { $_ eq $gt->{genotypingDataProjectName}} @{$study_names} ){

            my $set_id = $gt->{genotypingDataProjectDbId} . "p" . $gt->{analysisMethodDbId};

            if( ! $variant_sets{$set_id}{'analysisIds'} {$gt->{analysisMethodDbId}}) {
                my @analysis;
                push @analysis, {
                    analysisDbId=> qq|$gt->{analysisMethodDbId}|, #protocolid
                    analysisName=> $gt->{analysisMethod},
                    created=>undef,
                    description=>undef,
                    software=>undef,
                    type=>undef,
                    updated=>undef,
                };
                
                push( @{ $variant_sets { $set_id  }{'analysisIds'} {$gt->{analysisMethodDbId}} }, 1 );
                push( @{ $variant_sets { $set_id  }{'markerCount'}}, $gt->{resultCount} );
                push( @{ $variant_sets { $set_id  }{'analysis'}  }, @analysis);
            }

            push( @{ $variant_sets { $set_id  } {'genotypes'} }, $gt->{genotypeDbId});
            $variant_sets { $set_id  } {'name'}  = $gt->{genotypingDataProjectName} . " - " . $gt->{analysisMethod};
            $variant_sets { $set_id  } {'dataProject'} = $gt->{genotypingDataProjectDbId};
        }
    }

    my @data;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;
    
    foreach my $id (keys %variant_sets){

        if ($counter >= $start_index && $counter <= $end_index) {
            my @availableFormats; 
     
            push @availableFormats,{
                dataFormat => "json",
                fileFormat => "json",
                fileURL => undef,
            };
            push @data, {
                additionalInfo=>{},
                analysis =>$variant_sets{$id} {'analysis'},
                availableFormats => \@availableFormats,
                callSetCount => scalar @{$variant_sets{$id}{'genotypes'}},
                referenceSetDbId => keys %{ $variant_sets{$id} {'analysisIds'} },          
                studyDbId => qq|$variant_sets{$id}{'dataProject'}|,          
                variantCount => _sum($variant_sets{$id}{'markerCount'}),
                variantSetDbId => qq|$id|,
                variantSetName => $variant_sets{$id} {'name'},
            };
        }
        $counter++;
    }

    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
}


sub detail { 
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_id = $inputs->{variantSetDbId};

    my @trial_ids;
    my @protocol_ids;
    if ( $variantset_id){
        my @ids = split /p/, $variantset_id;
        push @trial_ids, $ids[0] ? $ids[0] : ();
        push @protocol_ids, $ids[1] ? $ids[1] : ();
    }

    my $genotype_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema => $self->people_schema(),
        cache_root=>$c->config->{cache_file_path},
        trial_list=>\@trial_ids,
        protocol_id_list=>\@protocol_ids,
        genotypeprop_hash_select=>['DS'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
    });
    my $file_handle = $genotype_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 1); #Metadata only returned

    my @data;
    my %variant_sets;

    $genotype_search->init_genotype_iterator();

    while (my ($count, $gt) = $genotype_search->get_next_genotype_info) {

        my $set_id = $gt->{genotypingDataProjectDbId} . "p" . $gt->{analysisMethodDbId};

        if( ! $variant_sets{$set_id}{'analysisIds'} {$gt->{analysisMethodDbId}}) {
            my @analysis;
            push @analysis, {
                analysisDbId=> qq|$gt->{analysisMethodDbId}|, #protocolid
                analysisName=> $gt->{analysisMethod},
                created=>undef,
                description=>undef,
                software=>undef,
                type=>undef,
                updated=>undef,
            };
            
            push( @{ $variant_sets { $set_id  }{'analysisIds'} {$gt->{analysisMethodDbId}} }, 1 );
            push( @{ $variant_sets { $set_id  }{'markerCount'}}, $gt->{resultCount} );
            push( @{ $variant_sets { $set_id  }{'analysis'}  }, @analysis);
        }

        push( @{ $variant_sets { $set_id  } {'genotypes'} }, $gt->{genotypeDbId});
        $variant_sets { $set_id  } {'name'}  = $gt->{genotypingDataProjectName} . " - " . $gt->{analysisMethod};
        $variant_sets { $set_id  } {'dataProject'} = $gt->{genotypingDataProjectDbId};
    }

    foreach my $id (keys %variant_sets){
 
        my @availableFormats; 
 
        push @availableFormats,{
            dataFormat => "json",
            fileFormat => "json",
            fileURL => undef,
        };
        push @data, {
            additionalInfo=>{},
            analysis =>$variant_sets{$id} {'analysis'},
            availableFormats => \@availableFormats,
            callSetCount => scalar @{$variant_sets{$id}{'genotypes'}},
            referenceSetDbId => keys %{ $variant_sets{$id} {'analysisIds'} },          
            studyDbId => qq|$variant_sets{$id}{'dataProject'}|,          
            variantCount => _sum($variant_sets{$id}{'markerCount'}),
            variantSetDbId => qq|$id|,
            variantSetName => $variant_sets{$id} {'name'},
        };
    }

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(@data, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub callsets {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_id = $inputs->{variantSetDbId};
    my @callset_id = $inputs->{callSetDbId} ? @{$inputs->{callSetDbId}} : ();
    my @callset_name = $inputs->{callSetName} ? @{$inputs->{callSetName}} : ();

    my @trial_ids;
    my @protocol_ids;
    if ( $variantset_id){
        my @ids = split /p/, $variantset_id;
        push @trial_ids, $ids[0] ? $ids[0] : ();
        push @protocol_ids, $ids[1] ? $ids[1] : ();
    }

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema => $self->people_schema(),
        cache_root=>$c->config->{cache_file_path},
        trial_list=>\@trial_ids,
        protocol_id_list=>\@protocol_ids,
        genotypeprop_hash_select=>['DS'],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
        accession_list=>\@callset_id,
        # offset=>$page_size*$page,
        # limit=>$page_size
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 1); #Metadata only returned
    my @data;

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;

    open my $fh, "<&", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;

    while( <$fh> ) {
        if ($counter >= $start_index && $counter <= $end_index) {
            my $gt = decode_json $_;
            my @analysis;
            my @availableFormats;
            
            push @data, {
                additionalInfo=>{},
                callSetDbId=> qq|$gt->{stock_id}|,
                callSetName=> qq|$gt->{stock_name}|,
                created=>undef,
                sampleDbId=>qq|$gt->{stock_id}|,
                studyDbId=>qq|$gt->{genotypingDataProjectDbId}|, 
                updated=>undef,
                variantSetDbIds => [ $gt->{genotypingDataProjectDbId}. "p". $gt->{analysisMethodDbId} ],
            };
        }
        $counter++;
    }

    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub calls {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_id = $inputs->{variantSetDbId};
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};
    my $file_path = $inputs->{file_path};
    my $uri = $inputs->{file_uri};

    if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
        push @$status, { 'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased' };
    }
    
    my @trial_ids;
    my @protocol_ids;
    if ( $variantset_id){
        my @ids = split /p/, $variantset_id;
        push @trial_ids, $ids[0] ? $ids[0] : ();
        push @protocol_ids, $ids[1] ? $ids[1] : ();
    }

    my @data_files;
    my %result;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema => $self->people_schema(),
        cache_root=>$c->config->{cache_file_path},
        trial_list=>\@trial_ids,
        protocol_id_list=>\@protocol_ids,
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
                push @data, {
                    additionalInfo=>{},
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

    %result = ( data=>\@data,
                expandHomozygotes=>undef, 
                sepPhased=>undef, 
                sepUnphased=>undef, 
                unknownString=>undef);



    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub variants {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $variantset_id = $inputs->{variantSetDbId};
    my $marker_ids = $inputs->{variantDbId}  || ($inputs->{variantDbIds} || []);
    my $pageToken = $inputs->{pageToken}->[0] || undef;
    my $schema = $self->bcs_schema;
    my @data_out;

    my @trial_ids;
    my @protocol_ids;
    if ( $variantset_id){
        my @ids = split /p/, $variantset_id;
        push @trial_ids, $ids[0] ? $ids[0] : ();
        push @protocol_ids, $ids[1] ? $ids[1] : ();
    }

    my $marker_search = CXGN::Marker::SearchBrAPI->new({
        bcs_schema => $schema,
        protocol_id_list => \@protocol_ids, 
        project_id_list => \@trial_ids,
        marker_name_list => $marker_ids,
        offset=>$page_size*$page,
        limit=>$page_size
    });

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;

    my ($data, $total_count) = $marker_search->search();

    foreach (@$data){
        if ($counter >= $start_index && $counter <= $end_index) {
            my $info = $_->{info};
            my $svtype = $1 if ($_->{info} =~ /SVTYPE=(\w+);/) ;
            my @cipos = _get_info($info,'CIPOS');
            my @ciend = _get_info($info,'CIEND');
            my @svlen = _get_info($info,'SVLEN');

            my %data_obj = (
                additionalInfo => {},
                alternate_bases => $_->{alt},
                ciend => [@ciend],
                cipos => [@cipos],
                created => undef,
                end => $_->{pos} + length($_->{ref}),
                filtersApplied => $_->{filter} eq "." ? JSON::false : JSON::true,
                filtersFailed => ( $_->{filter} eq "PASS" || $_->{filter} eq "." ) ? undef : $_->{filter},
                filtersPassed => $_->{filter} eq "PASS" ? JSON::true : JSON::false,
                referenceBases => $_->{ref},
                referenceName =>  $_->{chrom} ? $_->{chrom} : undef,
                start => $_->{pos},
                svlen => @svlen,
                updated => undef,
                variantDbId => qq|$_->{marker_name}|,
                variantNames => $_->{marker_name},
                variantSetDbId => _quote($_->{project_id}, $_->{nd_protocol_id} ),
                variantType => $svtype,
            );
            push @data_out, \%data_obj;
        }
        $counter++;
    }

    my %result = (data=>\@data_out);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Variants result constructed');
}

sub extract {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $variantset_ids = $inputs->{variantSetDbId} || ($inputs->{variantSetDbIds} || ());
    my $study_ids = $inputs->{studyDbId} || ($inputs->{studyDbIds} || ());
    my $study_names = $inputs->{studyName} || ($inputs->{studyNames} || ());
    my $variant_id = $inputs->{variantDbId} || ($inputs->{variantDbIds} || ());
    my $callset_id = $inputs->{callSetDbId} || ($inputs->{callSetDbIds} || ());

    my @trial_ids;
    my @protocol_ids;
    if ( $variantset_ids){
        foreach ( @{$variantset_ids} ){
            my @ids = split /p/, $_;
            if(scalar @ids>1){
                push @trial_ids, $ids[0] ? $ids[0] : ();
                push @protocol_ids, $ids[1] ? $ids[1] : ();
            } else {
                @trial_ids = 0;
            }

        }
    }
    if ($study_ids){
        push @trial_ids, @{$study_ids};
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

    my $genotype_search = CXGN::Genotype::Search->new({
            bcs_schema=>$self->bcs_schema,
            people_schema => $self->people_schema(),
            cache_root=>$c->config->{cache_file_path},
            trial_list=>\@trial_ids,
            genotypeprop_hash_select=>['DS'],
            protocolprop_top_key_select=>[],
            protocolprop_marker_hash_select=>[],
            accession_list=>$callset_id,
            protocol_id_list=>\@protocol_ids,
    });

    my %variant_sets;

    $genotype_search->init_genotype_iterator();

    while (my ($count, $gt) = $genotype_search->get_next_genotype_info) {

        if( ! $study_names || grep { $_ eq $gt->{genotypingDataProjectName}} @{$study_names} ){

            my $set_id = $gt->{genotypingDataProjectDbId} . "p" . $gt->{analysisMethodDbId};

            if( ! $variant_sets{$set_id}{'analysisIds'} {$gt->{analysisMethodDbId}}) {
                my @analysis;
                push @analysis, {
                    analysisDbId=> qq|$gt->{analysisMethodDbId}|, #protocolid
                    analysisName=> $gt->{analysisMethod},
                    created=>undef,
                    description=>undef,
                    software=>undef,
                    type=>undef,
                    updated=>undef,
                };
                
                push( @{ $variant_sets { $set_id  }{'analysisIds'} {$gt->{analysisMethodDbId}} }, 1 );
                push( @{ $variant_sets { $set_id  }{'markerCount'}}, $gt->{resultCount} );
                push( @{ $variant_sets { $set_id  }{'analysis'}  }, @analysis);
            }

            push( @{ $variant_sets { $set_id  } {'genotypes'} }, $gt->{genotypeDbId});
            $variant_sets { $set_id  } {'name'}  = $gt->{genotypingDataProjectName} . " - " . $gt->{analysisMethod};
            $variant_sets { $set_id  } {'dataProject'} = $gt->{genotypingDataProjectDbId};
        }
    }

    my @data;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;
    
    foreach my $id (keys %variant_sets){

        if ($counter >= $start_index && $counter <= $end_index) {
            my @availableFormats; 
     
            push @availableFormats,{
                dataFormat => "json",
                fileFormat => "json",
                fileURL => undef,
            };
            push @data, {
                additionalInfo=>{},
                analysis =>$variant_sets{$id} {'analysis'},
                availableFormats => \@availableFormats,
                callSetCount => scalar @{$variant_sets{$id}{'genotypes'}},
                referenceSetDbId => keys %{ $variant_sets{$id} {'analysisIds'} },           
                studyDbId => qq|$variant_sets{$id}{'dataProject'}|,          
                variantCount => _sum($variant_sets{$id}{'markerCount'}),
                variantSetDbId => qq|$id|,
                variantSetName => $variant_sets{$id} {'name'},
            };
        }
        $counter++;
    }

    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
}

sub _sum {
    my $array = shift;
    my $sum=0;

    foreach my $num (@$array){
        $sum += $num;
    }
    return $sum;
}

sub _get_info {
    my $info = shift;
    my $item = shift;
    my @array = [];

    #match with CIPOS=-22,18;CIEND=-12,32"
    if ( $info =~ /$item=(-?(\d+),?)+/) {
        my $match = $&;
        $match =~ s/$item=//g;
        my @splited = split(/,/, $match);
        @array = map { $_ + 0 } @splited;
    }

    return @array ;
}

sub _quote {
    my $array = shift;
    my $protocol = shift;

    foreach (@$array) {
        $_ = "$_" . "p". $protocol;
    }

    return $array
}

1;