package CXGN::BrAPI::v2::Variants;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Marker::SearchBrAPI;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use JSON;

use CXGN::DB::Connection;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $marker_ids = $inputs->{variantDbId}  || ($inputs->{variantDbIds} || []);
    my $variantset_ids = $inputs->{variantSetDbId}  || ($inputs->{variantSetDbIds} || []);
    my @callset_ids = $inputs->{callSetDbIds} ? @{$inputs->{callSetDbIds}} : ();
    my $start = $inputs->{start}->[0] || undef;
    my $end = $inputs->{end}->[0] || undef;
    my $pageToken = $inputs->{pageToken}->[0] || undef;
    my $schema = $self->bcs_schema;
    my @data_out;

    if (@callset_ids && scalar(@callset_ids)>0){
        push @$status, { 'error' => 'The following search parameters are not implemented: callSetDbIds' };
    }

    my @trial_ids =();
    my @protocol_ids = ();
    if ( $variantset_ids){
        foreach ( @{$variantset_ids} ){
            my @ids = split /p/, $_;
            push @trial_ids, $ids[0] ? $ids[0] : ();
            push @protocol_ids, $ids[1] ? $ids[1] : ();
        }
    }

    my $marker_search = CXGN::Marker::SearchBrAPI->new({
        bcs_schema => $schema,
        protocol_id_list => \@protocol_ids, 
        project_id_list => \@trial_ids,
        marker_name_list => $marker_ids,
        #protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'] Use default which is all marker info
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
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Variants result constructed');
}

sub detail {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @marker_ids;

    my $marker_ids = $inputs->{variantDbId};

    my $schema = $self->bcs_schema;
    my @data_out;


    my $marker_search = CXGN::Marker::SearchBrAPI->new({
        bcs_schema => $schema,
        protocol_id_list => [],
        marker_name_list => [$marker_ids],
    });

    my ($data, $total_count) = $marker_search->search();

    foreach (@$data){
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
            referenceName =>  $_->{chrom} ? 'chr_' . $_->{chrom} : undef,
            start => $_->{pos},
            svlen => @svlen, #length($_->{alt}),
            updated => undef,
            variantDbId => qq|$_->{marker_name}|,
            variantNames => $_->{marker_name},
            variantSetDbId => _quote($_->{project_id}, $_->{nd_protocol_id} ),
            variantType => $svtype,
        );
        push @data_out, \%data_obj;
    }

    my %result = (data=>\@data_out);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Variants result constructed');
}


sub calls {
    my $self = shift;
    my $inputs = shift;
    my $c = $self->context;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};
    my $marker_id = $inputs->{variantDbId};
    my @trial_ids;

    if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
        push @$status, { 'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased' };
    }

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$self->bcs_schema,
        trial_design_list=>['genotype_data_project']
    });
    my ($data, $total_count) = $trial_search->search(); 

    foreach (@$data){
        push @trial_ids, $_->{trial_id};
    }

    my @data_files;
    my %result;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        cache_root=>$c->config->{cache_file_path},
        people_schema => $self->people_schema(),
        trial_list=>\@trial_ids,
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

    my @data;

    while (my $gt_line = <$fh>) {
        my $gt = decode_json $gt_line;
        my $genotype = $gt->{selected_genotype_hash};
        my @ordered_refmarkers = sort keys(%$genotype);
        my $genotypeprop_id = $gt->{markerProfileDbId};

        foreach my $m (@ordered_refmarkers) {
            if ($m eq $marker_id){
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
    }

    %result = ( data=>\@data,
                expandHomozygotes=>undef, 
                sepPhased=>undef, 
                sepUnphased=>undef, 
                unknownString=>undef);



    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'VariantSets result constructed');
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
