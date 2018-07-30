package CXGN::Genotype::Protocol;

=head1 NAME

CXGN::Genotype::Protocol - an object to handle genotyping protocols (breeding data)

=head1 USAGE

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
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

has 'protocol_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'markers' => (
    isa => 'HashRef',
    is => 'rw',
);

has 'marker_names' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has 'header_information_lines' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has 'reference_genome_name' => (
    isa => 'Str',
    is => 'rw'
);

has 'species_name' => (
    isa => 'Str',
    is => "rw"
);

has 'sample_observation_unit_type_name' => (
    isa => 'Str',
    is => 'rw'
);

sub BUILD {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $protocol_vcf_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    my $protocol_rs = $schema->resultset('NaturalDiversity::NdProtocol')->search({
        'me.nd_protocol_id'=>$self->nd_protocol_id,
        'me.type_id'=>$geno_cvterm_id,
        'nd_protocolprops.type_id'=>$protocol_vcf_details_cvterm_id
    }, {
        join => 'nd_protocolprops',
        '+select' => ['nd_protocolprops.value'],
        '+as' => ['value']
    });
    if ($protocol_rs->count != 1){
        print STDERR "Not a valide nd_protocol_id\n";
        return;
    }
    my $protocol = $protocol_rs->first;
    my $map_details = decode_json $protocol->get_column('value');
    $self->markers($map_details->{markers});
    $self->marker_names($map_details->{marker_names});
    $self->protocol_name($protocol->name);
    $self->header_information_lines($map_details->{header_information_lines});
    $self->reference_genome_name($map_details->{reference_genome_name});
    $self->species_name($map_details->{species_name});
    $self->sample_observation_unit_type_name($map_details->{sample_observation_unit_type_name});
    return;
}

#class method
sub list {
    my $schema = shift;
    my $protocol_list = shift;
    my $accession_list = shift;
    my $tissue_sample_list = shift;
    my $limit = shift;
    my $offset = shift;
    my @where_clause;

    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();

    push @where_clause, "nd_protocolprop.type_id = $vcf_map_details_cvterm_id";

    if ($protocol_list && scalar(@$protocol_list)>0) {
        my $protocol_sql = join ("," , @$protocol_list);
        push @where_clause, "nd_protocol.nd_protocol_id in ($protocol_sql)";
    }
    if ($accession_list && scalar(@$accession_list)>0) {
        my $accession_sql = join ("," , @$accession_list);
        push @where_clause, "stock.stock_id in ($accession_sql)";
        push @where_clause, "stock.type_id = $accession_cvterm_id";
    }
    if ($tissue_sample_list && scalar(@$tissue_sample_list)>0) {
        my $stock_sql = join ("," , @$tissue_sample_list);
        push @where_clause, "stock.stock_id in ($stock_sql)";
        push @where_clause, "stock.type_id = $tissue_sample_cvterm_id";
    }
    
    my $offset_clause = '';
    my $limit_clause = '';
    if ($limit){
        $limit_clause = " LIMIT $limit ";
    }
    if ($offset){
        $offset_clause = " OFFSET $offset ";
    }
    my $where_clause = " WHERE " . (join (" AND " , @where_clause));

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocolprop.value, project.project_id, project.name, count(nd_protocol.nd_protocol_id) OVER() AS full_count
        FROM stock
        JOIN cvterm AS stock_cvterm ON(stock.type_id = stock_cvterm.cvterm_id)
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_protocol USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN nd_protocol USING(nd_protocol_id)
        LEFT JOIN nd_protocolprop ON(nd_protocolprop.nd_protocol_id = nd_protocol.nd_protocol_id)
        JOIN project USING(project_id)
        $where_clause
        GROUP BY (nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocolprop.value, project.project_id, project.name)
        ORDER BY nd_protocol.nd_protocol_id ASC
        $limit_clause
        $offset_clause;";

    print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    
    my @results;
    while (my ($protocol_id, $protocol_name, $protocolprop_json, $stock_id, $stock_name, $stock_type_id, $stock_type_name, $project_id, $project_name, $full_count) = $h->fetchrow_array()) {
        my $protocol = $protocolprop_json ? decode_json $protocolprop_json : undef;
        my $all_protocol_marker_names = $protocol ? $protocol->{'marker_names'} : undef;
        my $marker_set = $protocol ? $protocol->{markers} : undef;
        my $marker_names = $protocol ? $protocol->{marker_names} : undef;
        my $header_information_lines = $protocol ? $protocol->{header_information_lines} : undef;
        my $reference_genome_name = $protocol ? $protocol->{reference_genome_name} : undef;
        my $species_name = $protocol ? $protocol->{species_name} : undef;
        my $sample_observation_unit_type_name = $protocol ? $protocol->{sample_observation_unit_type_name} : undef;
        push @results, {
            protocol_id => $protocol_id,
            protocol_name => $protocol_name,
            markers => $marker_set,
            marker_names => $marker_names,
            header_information_lines => $header_information_lines,
            reference_genome_name => $reference_genome_name,
            species_name => $species_name,
            sample_observation_unit_type_name => $sample_observation_unit_type_name
        };
    }
    #print STDERR Dumper \@results;
    return \@results;
}

1;

