package CXGN::Genotype::Download::KASPdata;

=head1 NAME

CXGN::Genotype::Download::KASPdata - an object to handle downloading KASP genotyping data in csv format

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
    is => 'ro',
);

has 'genotyping_plate_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'genotypeprop_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
);

has 'return_only_first_genotypeprop_for_stock' => (
    isa => 'Bool',
    is => 'ro',
    default => 1
);

has 'filename' => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);

has 'sample_unit_level' => (
    isa => 'Str',
    is => 'rw',
    default => 'accession',
);

sub download {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $people_schema = $self->people_schema;
    my $protocol_id_list = $self->protocol_id_list;
    my $genotyping_project_list = $self->genotype_data_project_list;
    my $genotyping_plate_list = $self->genotyping_plate_list;
    my $genotypeprop_hash_select = ['NT', 'XV', 'YV'];
    my $return_only_first_genotypeprop_for_stock = $self->return_only_first_genotypeprop_for_stock;
    my $sample_unit_level = $self->sample_unit_level;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        protocol_id_list=>$protocol_id_list,
        genotype_data_project_list=>$genotyping_project_list,
        genotyping_plate_list=>$genotyping_plate_list,
        genotypeprop_hash_select=>$genotypeprop_hash_select,
        sample_unit_level=>$sample_unit_level,
    });

    my ($total_count, $data) = $genotypes_search->get_genotype_info();
    my @all_data = @$data;
    my $number_of_samples = scalar @all_data;
    my %data_hash;
    foreach my $sample_data (@all_data) {
        my %genotype_hash = ();
        my $sample_name = $sample_data->{germplasmName};
        my $genotype_hash_ref = $sample_data->{selected_genotype_hash};
        %genotype_hash = %{$genotype_hash_ref};
        foreach my $marker_name (keys %genotype_hash) {
            my $each_marker_data = $genotype_hash{$marker_name};
            my $nt =  $each_marker_data->{NT};
            my $xv = $each_marker_data->{XV};
            my $yv = $each_marker_data->{YV};
            $data_hash{$marker_name}{$sample_name}{NT} = $nt;
            $data_hash{$marker_name}{$sample_name}{XV} = $xv;
            $data_hash{$marker_name}{$sample_name}{YV} = $yv;
        }
    }

    my @info_lines;
    foreach my $marker_name (sort keys %data_hash) {
        my $sample_data_ref = $data_hash{$marker_name};
        my %sample_data = %{$sample_data_ref};
        foreach my $sample_name (sort keys %sample_data ) {
            my @each_info_line = ();
            my $genotype_data_ref = $sample_data{$sample_name};
            my $sample_nt = $genotype_data_ref->{NT};
            my $sample_xv = $genotype_data_ref->{XV};
            my $sample_yv = $genotype_data_ref->{YV};
            push @each_info_line, ($marker_name, $sample_name, $sample_nt, $sample_xv, $sample_yv);
            push @info_lines, [@each_info_line];
        }
    }

    my $unit_header;
    if ($sample_unit_level eq 'genotyping_plate_sample_name') {
        $unit_header = 'SAMPLE NAME';
    } elsif ($sample_unit_level eq 'sample_name_and_accession') {
        $unit_header = 'SAMPLE NAME|ACCESSION NAME';
    } else {
        $unit_header = 'ACCESSION NAME';
    }

    my @headers = ('MARKER NAME', $unit_header, 'SNP CALL (X,Y)', 'X VALUE', 'Y VALUE');
    my @lines;
    push @lines, [@headers];
    push @lines, @info_lines;
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
