package CXGN::BrAPI::v2::Calls;

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
    my $sep_phased = $inputs->{sep_phased};
    my $sep_unphased = $inputs->{sep_unphased};
    my $unknown_string = $inputs->{unknown_string};
    my $expand_homozygotes = $inputs->{expand_homozygotes};
    my $marker_id = $inputs->{variantDbId} || ($inputs->{variantDbIds} || ());
    my $callset_id = $inputs->{callSetDbId} || ($inputs->{callSetDbIds} || ());
    my $variantset_id = $inputs->{variantSetDbId} || ($inputs->{variantSetDbIds} || ());
    my @variantset_id;

    if ($sep_phased || $sep_unphased || $expand_homozygotes || $unknown_string){
        push @$status, { 'error' => 'The following parameters are not implemented: expandHomozygotes, unknownString, sepPhased, sepUnphased' };
    }

    my @trial_ids;
    my @protocol_ids;

    if ( $variantset_id){
        foreach ( @{$variantset_id} ){
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

    my @data_files;
    my %result;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema => $self->people_schema(),
        cache_root=>$c->config->{cache_file_path},
        trial_list=>\@trial_ids,
        genotypeprop_hash_select=>['DS', 'GT', 'NT'],
        accession_list=>$callset_id,
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[],
        protocol_id_list=>\@protocol_ids,
    });
    my $file_handle = $genotypes_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 0);
    
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

            if ( !$marker_id || grep{/^$m$/}@{$marker_id} ) {
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
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Calls result constructed');
}

1;
