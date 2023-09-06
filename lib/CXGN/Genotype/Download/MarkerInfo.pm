package CXGN::Genotype::Download::MarkerInfo;

=head1 NAME

CXGN::Genotype::Download::MarkerInfo - an object to handle downloading all protocol marker information in CSV format

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
use CXGN::Genotype::Protocol;
use CXGN::Genotype::MarkersSearch;
use DateTime;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'protocol_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
    required => 1,
);

has 'filename' => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);

sub download {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $protocol_id = $self->protocol_id_list;

    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id->[0],
    });
    my $marker_info_keys = $protocol->marker_info_keys;
    my $assay_type = $protocol->assay_type;
    my $marker_search = CXGN::Genotype::MarkersSearch->new({
        bcs_schema => $schema,
        protocol_id_list => $protocol_id
    });
    my ($search_result, $total_count) = $marker_search->search();
    my @results;
    my @lines;
    my @headers;

    if (defined $marker_info_keys) {
        foreach my $header_key (@$marker_info_keys) {
            if ($header_key eq 'name') {
                push @headers, 'MARKER NAME';
            } elsif (($header_key eq 'intertek_name') || ($header_key eq 'facility_name')) {
                push @headers, 'FACILITY MARKER NAME';
            } elsif ($header_key eq 'chrom') {
                push @headers, 'CHROMOSOME';
            } elsif ($header_key eq 'pos') {
                push @headers, 'POSITION';
            } elsif ($header_key eq 'ref') {
                if ($assay_type eq 'KASP') {
                    push @headers, 'X-ALLELE';
                } else {
                    push @headers, 'REFERENCE';
                }
            } elsif ($header_key eq 'alt') {
                if ($assay_type eq 'KASP') {
                    push @headers, 'Y-ALLELE';
                } else {
                    push @headers, 'ALTERNATE';
                }
            } elsif ($header_key eq 'qual') {
                push @headers, 'QUALITY';
            } elsif ($header_key eq 'filter') {
                push @headers, 'FILTER';
            } elsif ($header_key eq 'info') {
                push @headers, 'INFO';
            } elsif ($header_key eq 'format') {
                push @headers, 'FORMAT';
            } elsif ($header_key eq 'sequence') {
                push @headers, 'SEQUENCE';
            }
        }
    } else {
        @headers = ('NAME', 'CHROMOSOME', 'POSITION', 'ALTERNATE', 'REFERENCE', 'QUALITY', 'FILTER', 'INFO', 'FORMAT');
    }

    foreach my $result (@$search_result) {
        if (defined $marker_info_keys) {
            my @each_row = ();
            foreach my $info_key (@$marker_info_keys) {
                push @each_row, $result->{$info_key};
            }
            push @results, [@each_row];
        } else {
            push @results, [
                $result->{marker_name},
                $result->{chrom},
                $result->{pos},
                $result->{alt},
                $result->{ref},
                $result->{qual},
                $result->{filter},
                $result->{info},
                $result->{format}
            ];
        }
    }

    push @lines, [@headers];
    push @lines, @results;
    print STDERR "LINES =".Dumper(@lines)."\n";

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
