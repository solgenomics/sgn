package CXGN::Genotype::DownloadFactory;

=head1 NAME

CXGN::Genotype::DownloadFactory - an object factory to handle downloading genotypes across database. factory delegates between download types e.g. VCF, GenotypeMatrix

=head1 USAGE

my $geno = CXGN::Genotype::DownloadFactory->instantiate(
    'VCF',    #can be either 'VCF' or 'DosageMatrix'
    {
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        cache_root_dir=>$cache_root,
        accession_list=>$accession_list,
        tissue_sample_list=>$tissue_sample_list,
        trial_list=>$trial_list,
        protocol_id_list=>$protocol_id_list,
        markerprofile_id_list=>$markerprofile_id_list,
        genotype_data_project_list=>$genotype_data_project_list,
        chromosome_list=>\@chromosome_numbers,
        start_position=>$start_position,
        end_position=>$end_position,
        marker_name_list=>['S80_265728', 'S80_265723'],
        genotypeprop_hash_select=>['DS', 'GT', 'DP'], #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
        protocolprop_top_key_select=>['reference_genome_name', 'header_information_lines', 'marker_names', 'markers'], #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
        protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'], #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
        limit=>$limit,
        offset=>$offset,
        compute_from_parents=>0, #If you want to compute the genotype for accessions given from parents in the pedigree. Useful for hybrids where parents are genotyped.
        forbid_cache=>0, #If you want to get a guaranteed fresh result not from the file cache
        prevent_transpose=>0, #Prevent transpose of DosageMatrix
        return_only_first_genotypeprop_for_stock=>1
    }
);
my $status = $geno->download();

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>

=cut

use strict;
use warnings;

sub instantiate {
    my $class = shift;
    my $type = shift;
    my $location = "CXGN/Genotype/Download/$type.pm";
    my $obj_class = "CXGN::Genotype::Download::$type";
    require $location;
    return $obj_class->new(@_);
}

1;
