package CXGN::Genotype::DownloadFactory;

=head1 NAME

CXGN::Genotype::DownloadFactory - an object factory to handle downloading genotypes across database. factory delegates between download types e.g. VCF, GenotypeMatrix

=head1 USAGE

my $geno = CXGN::Genotype::DownloadFactory->instantiate(
    'VCF',    #can be either 'VCF' or 'DosageMatrix'
    {
        bcs_schema=>$schema,
        filename=>$filename,  #file path to write to
        accession_list=>$accession_list,
        tissue_sample_list=>$tissue_sample_list,
        trial_list=>$trial_list,
        protocol_id_list=>$protocol_id_list,
        markerprofile_id_list=>$markerprofile_id_list,
        genotype_data_project_list=>$genotype_data_project_list,
        marker_name_list=>['S80_265728', 'S80_265723'],
        genotypeprop_hash_select=>['DS', 'GT', 'DP'], #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
        protocolprop_top_key_select=>['reference_genome_name', 'header_information_lines', 'marker_names', 'markers'], #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
        protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'], #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
        limit=>$limit,
        offset=>$offset
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
