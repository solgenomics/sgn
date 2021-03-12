package CXGN::Trait::Search;

=head1 NAME

CXGN::Trait::Search - an object to handle searching for trait variables given criteria

=head1 USAGE

my $trait_search = CXGN::Trait::Search->new({
    bcs_schema=>$schema,
    is_variable=>$is_variable,
    onto_root_namespaces=>\@ontology_db_ids,
    trait_definition_list=>\@trait_definitions,
    trait_id_list=>\@trait_ids,
    trait_name_list=>\@trait_names,
    trait_name_is_exact=>1
});
my $result = $trait_search->search();

=head1 DESCRIPTION


=head1 AUTHORS

 With code adapted from SGN::Controller::AJAX::Search::Trial

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Calendar;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'is_variable' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => 0
);

has 'ontology_db_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'ontology_db_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trait_definition_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trait_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'accession_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trait_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trait_name_is_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'sort_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'order_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw',
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();

    my $is_variable = $self->is_variable();
    my $ontology_db_ids = $self->ontology_db_id_list();

    my %and_conditions;
    if ($ontology_db_ids && scalar(@$ontology_db_ids) > 0){
        $and_conditions{'db.db_id'} = {'-in' => $ontology_db_ids};
    }

    if ($self->trait_id_list && scalar(@{$self->trait_id_list}) > 0){
        $and_conditions{cvterm_id} = { -in => $self->trait_id_list };
    }

    if ($self->ontology_db_name_list && scalar(@{$self->ontology_db_name_list}) > 0){
        $and_conditions{'db.name'} = { -in => $self->ontology_db_name_list };
    }

    if ($self->accession_list && scalar(@{$self->accession_list}) > 0){
        $and_conditions{'dbxref.accession'} = { -in => $self->accession_list };
    }

    if ($self->trait_definition_list && scalar(@{$self->trait_definition_list}) > 0){
        foreach (@{$self->trait_definition_list}){
            my @words = split '\s', $_;
            my $match_string = join '%', @words;
            push @{$and_conditions{'me.definition'}}, {'ilike' => '%'.$match_string.'%'};
        }
    }

    if ($self->trait_name_list && scalar(@{$self->trait_name_list}) > 0){
        my $trait_name_is_exact = $self->trait_name_is_exact;
        if ($trait_name_is_exact){
            $and_conditions{'me.name'} = { -in => $self->trait_name_list };
        } else {
            foreach (@{$self->trait_name_list}){
                push @{$and_conditions{'me.name'}}, {'ilike' => '%'.$_.'%'};
            }
        }
    }

    my $sort_by = $self->sort_by;
    my $order_by = $self->order_by || 'me.name';

    my %where_join = (
        'me.is_obsolete' => 0,
        'me.is_relationshiptype' => 0
    );

    if ($is_variable) {
        $where_join{'type.name'} = 'VARIABLE_OF';
    }

    # $schema->storage->debug(1);
    my $trait_rs = $schema->resultset("Cv::Cvterm")->search(
        \%and_conditions,
        {
            join => [{'cvterm_relationship_subjects' => 'type'}, {'dbxref' => 'db'} ],
            where => \%where_join,
            order_by => { '-asc' => $order_by },
            '+select' => ['db.name', 'dbxref.accession', 'type.name'],
            '+as' => ['db_name', 'db_accession', 'cvterm_relationship_name'],
            distinct => 1
        }
    );

    my @result;
    my %traits = ();

    my $limit = $self->limit;
    my $offset = $self->offset;
    my $records_total = $trait_rs->count();
    if (defined($limit) && defined($offset)){
        $trait_rs = $trait_rs->slice($offset, $limit);
    }

    while ( my $t = $trait_rs->next() ) {
        push @result, {
            trait_id => $t->cvterm_id,
            trait_name => $t->name,
            trait_definition => $t->definition,
            db_name => $t->get_column('db_name'),
            accession=> $t->get_column('db_accession'),
            cvterm_relationship_name=> $t->get_column('cvterm_relationship_name')
        };
    }

    return (\@result, $records_total);
}

1;
