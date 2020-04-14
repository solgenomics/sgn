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

    my $marker_search = CXGN::Marker::SearchBrAPI->new({
        bcs_schema => $schema,
        protocol_id_list => [],
        project_id_list => $variantset_ids,
        #protocol_name_list => \@protocol_name_list,
        marker_name_list => $marker_ids,
        #protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'] Use default which is all marker info
        # limit => $limit,
        # offset => $offset
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
                referenceName =>  $_->{chrom} ? 'chr_' . $_->{chrom} : undef,
                start => $_->{pos},
                svlen => @svlen, #length($_->{alt}),
                updated => undef,
                variantDbId => qq|$_->{marker_name}|,
                variantNames => $_->{marker_name},
                variantSetDbId => _quote($_->{project_id}),
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

sub detail {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @marker_ids;

    my $marker_ids = $inputs->{variantDbId} ;

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
            variantSetDbId => _quote($_->{project_id}),
            variantType => $svtype,
        );
        push @data_out, \%data_obj;
    }

    my %result = (data=>\@data_out);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Variants result constructed');
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

    foreach (@$array) {
        $_ = "$_";
    }

    return $array
}

1;
