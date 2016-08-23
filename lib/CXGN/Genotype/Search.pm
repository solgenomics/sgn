package CXGN::Genotype::Search;

=head1 NAME

CXGN::Genotype::Search - an object to handle searching genotypes for stocks

=head1 USAGE

my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    accession_list=>$accession_list,
    trial_list=>$trial_list,
    protocol_id=>$protocol_id
});
my $resultset = $genotypes_search->get_genotype_info();
my $genotypes = $resultset->{genotypes};

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>
 With code moved from CXGN::BreederSearch
 Lukas Mueller <lam87@cornell.edu>
 Aimin Yan <ay247@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'accession_list' => (
    isa => 'ArrayRef|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef|Undef',
    is => 'ro',
);

has 'protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

=head2 get_genotype_info

returns: an array with genotype information

=cut

sub get_genotype_info {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $accession_idref = $self->accession_list;
    my $trial_idref = $self->trial_list;
    my $protocol_id = $self->protocol_id;
    my $snp_genotype_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my @accession_ids = @$accession_idref;
    my ($q, @result, $protocol_name);

    my @where_clause;
    if ($accession_idref && scalar(@$accession_idref)>0) {
        my $accession_sql = _sql_from_arrayref($accession_idref);
        push @where_clause, "stock.stock_id in ($accession_sql)";
    }
    if ($trial_idref && scalar(@$trial_idref)>0) {
        my $trial_sql = _sql_from_arrayref($trial_idref);
        push @where_clause, "project.project_id in ($trial_sql)";
    }

    my $where_clause = "WHERE genotypeprop.type_id = $snp_genotype_id AND nd_experiment_protocol.nd_protocol_id=$protocol_id";

    if (@where_clause>0) {
        $where_clause .= " AND " . (join (" AND " , @where_clause));
    }

    $q = "SELECT name, uniquename, value FROM (SELECT nd_protocol.name, stock.uniquename, genotypeprop.value, row_number() over (partition by stock.uniquename order by genotypeprop.genotype_id) as rownum from genotypeprop join nd_experiment_genotype USING (genotype_id) JOIN nd_experiment_protocol USING(nd_experiment_id) JOIN nd_protocol USING(nd_protocol_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN project USING(project_id) $where_clause ) tmp WHERE rownum <2";
    print STDERR "QUERY: $q\n\n";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    while (my($name,$uniquename,$genotype_string) = $h->fetchrow_array()) {
        push @result, [ $uniquename, $genotype_string ];
        $protocol_name = $name;
    }

    return {
        protocol_name => $protocol_name,
        genotypes => \@result
    };
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}


1;
