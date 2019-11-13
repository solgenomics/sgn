package CXGN::Marker::SearchBrAPI;

=head1 NAME

CXGN::Marker::SearchBrAPI - an object to handle searching for markers given criteria

=head1 USAGE

my $marker_search = CXGN::Marker::SearchBrAPI->new({
    bcs_schema=>$schema,
    marker_ids=>\@marker_ids,
    marker_names=>\@marker_names,
    get_synonyms=>$synonyms,
    match_method=>$method,
    types=>\@types, 
    offset=>$page_size*$page,
    limit=>$page_size
});
my ($result, $total_count) = $marker_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;

use CXGN::Marker;
use CXGN::Marker::LocMarker;
use CXGN::Marker::Tools qw(clean_marker_name);
use SGN::Model::Cvterm;
use CXGN::Trial;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'nd_protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'marker_ids' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'marker_names' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'get_synonyms' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'match_method' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'types' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);


sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $marker_ids = $self->marker_ids;
    my $marker_names = $self->marker_names;
    my $get_synonyms = $self->get_synonyms;
    my $match_method = $self->match_method;
    my $types = $self->types;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my @where_clause;
    my $comparison;

    if ($match_method eq 'exact'){ $comparison = 'in';} 
    elsif ($match_method eq 'case_insensitive'){ $comparison = 'ilike'; }
    else { $comparison = 'like'; }

    if ($marker_ids && scalar(@$marker_ids)>0) {
        my $sql = join ("," , @$marker_ids);
        push @where_clause, "marker.marker_id in ($sql)";
    }

    if ($marker_names && scalar(@$marker_names)>0) {
        my $sql = join ("," , @$marker_names);
        push @where_clause, "marker_names.name in ($sql)";
    }

    if ($types && scalar(@$types)>0) {
        my $sql = join ("," , @$types);
        push @where_clause, "protocol in ($sql)";
    }

    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

       
    my $subquery = "SELECT distinct m2m.marker_id,name,alias,protocol,organism_name,common_name.common_name FROM sgn.marker 
        LEFT JOIN sgn.marker_to_map as m2m using(marker_id) 
        INNER JOIN sgn.accession ON(parent_1 = accession.accession_id OR parent_2 = accession.accession_id) 
        INNER JOIN sgn.organism using(organism_id) 
        INNER JOIN sgn.common_name USING(common_name_id) 
        INNER JOIN marker_names ON(m2m.marker_id=marker_names.marker_id) 
        INNER JOIN marker_alias ON(m2m.marker_id=marker_alias.marker_id) $where_clause";

    my $h = $schema->storage->dbh()->prepare($subquery);
    $h->execute();

    my @result;
    my $total_count = 0;
    my $subtract_count = 0;

    while (my ($marker_id, $marker_name, $reference, $alias, $protocol, $full_count) = $h->fetchrow_array()) {
        push @result, {
            marker_id => $marker_id,
            marker_name => $marker_name,
            method => $protocol,
            references => $reference,
            synonyms => $alias,
            type => $protocol
        };
        $total_count = $full_count;
    }

    my @data_window;
    if (($limit && defined($limit) || ($offset && defined($offset)))){
        my $start = $offset;
        my $end = $offset + $limit - 1;
        for( my $i = $start; $i <= $end; $i++ ) {
            if ($result[$i]) {
                push @data_window, $result[$i];
            }
        }
    } else {
        @data_window = @result;
    }

    $total_count = $total_count-$subtract_count;
    return (\@data_window, $total_count);

}

1;