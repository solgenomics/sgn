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
    my $marker_search = CXGN::Genotype::MarkersSearch->new({
        bcs_schema => $schema,
        protocol_id_list => $protocol_id
    });
    my ($search_result, $total_count) = $marker_search->search();
    print STDERR "PLUGIN RESULT SEARCH =".Dumper($search_result)."\n";
    print STDERR "MARKER INFO KEY =".Dumper($marker_info_keys)."\n";
    my @results;
    my @lines;
    my @headers = @$marker_info_keys;

    foreach (@$search_result) {
        if (defined $marker_info_keys) {
            my @each_row = ();
            foreach my $info_key (@$marker_info_keys) {
                push @each_row, $_->{$info_key};
            }
            push @results, [@each_row];
        } else {
            push @results, [
                $_->{marker_name},
                $_->{chrom},
                $_->{pos},
                $_->{alt},
                $_->{ref},
                $_->{qual},
                $_->{filter},
                $_->{info},
                $_->{format}
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
