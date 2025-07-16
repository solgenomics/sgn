package CXGN::Genotype::Download::SSR;

=head1 NAME

CXGN::Genotype::Download::SSR - an object to handle downloading SSR genotypes in CSV format

=head1 USAGE


=head1 DESCRIPTION


=head1 AUTHORS

 Titima Tantikanjana <tt15@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use Text::CSV;
use CXGN::Genotype::Search;
use CXGN::Stock::StockLookup;
use DateTime;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1,
);

has 'protocol_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'genotype_data_project_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'markerprofile_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'filename' => (
    isa => 'Str',
    is => 'ro',
    predicate => 'has_filename',
    required => 1,
);


sub download {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $people_schema = $self->people_schema;
    my $protocol_id_list = $self->protocol_id_list;
    my $genotype_project_list = $self->genotype_data_project_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        protocol_id_list=>$protocol_id_list,
        genotype_data_project_list=>$genotype_project_list
    });
    my $result = $genotypes_search->get_pcr_genotype_info();
#    print STDERR "PCR DOWNLOAD RESULTS =".Dumper($result)."\n";

    my $ssr_genotype_data = $result->{'ssr_genotype_data'};
    my @ssr_genotype_data_array = @$ssr_genotype_data;
    my @results;
    my @lines;
    my @headers;
    push @headers, 'sample_names';

    my $marker_info = $ssr_genotype_data->[0];
    my $marker_genotype_json = $marker_info->[6];
    my $marker_genotype_ref = decode_json $marker_genotype_json;
    my %marker_genotype_hash = %{$marker_genotype_ref};
    foreach my $marker_name ( sort keys %marker_genotype_hash) {
        my $pcr_size_hash_ref = $marker_genotype_hash{$marker_name};
        my %pcr_size_hash = %{$pcr_size_hash_ref};
        foreach my $pcr_size (sort keys %pcr_size_hash) {
            my $pcr_result = $pcr_size_hash{$pcr_size};
            my $marker_header = $marker_name.'_'.$pcr_size;
            push @headers, $marker_header;
        }
    }

    foreach my $genotype_data (@ssr_genotype_data_array) {
        my @each_result = ();
        my $stock_name = $genotype_data->[1];
        push @each_result, $stock_name;
        my $marker_genotype_json = $genotype_data->[6];
        my $marker_genotype_ref = decode_json $marker_genotype_json;
        my %marker_genotype_hash = %{$marker_genotype_ref};
        foreach my $marker_name ( sort keys %marker_genotype_hash) {
            my $pcr_size_hash_ref = $marker_genotype_hash{$marker_name};
            my %pcr_size_hash = %{$pcr_size_hash_ref};
            foreach my $pcr_size (sort keys %pcr_size_hash) {
                my $pcr_result = $pcr_size_hash{$pcr_size};
                push @each_result, $pcr_result;
            }
        }

        push @results, [@each_result];
    }
#    print STDERR "HEADERS =".Dumper(\@headers);
#    print STDERR "RESULTS =".Dumper(\@results)."\n";
    push @lines, [@headers];
    push @lines, @results;
#    print STDERR "LINES =".Dumper(@lines)."\n";

    no warnings 'uninitialized';
    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();

        my $header =  $lines[0];
        my $num_col = scalar(@$header);
        for (my $line =0; $line< @lines; $line++) {
            my $columns = $lines[$line];
            print $F join ',', map { qq!"$_"! } @$columns;
            print $F "\n";
        }
    close($F);


}

1;
