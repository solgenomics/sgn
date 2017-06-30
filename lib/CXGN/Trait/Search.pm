package CXGN::Trait::Search;

=head1 NAME

CXGN::Trait::Search - an object to handle searching for trait variables given criteria

=head1 USAGE

my $trait_search = CXGN::Trait::Search->new({
    bcs_schema=>$schema,
    is_variable=>$is_variable,
    trait_cv_name=>$cv_name,
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

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'is_variable' => (
    isa => 'Str|Undef',
    is => 'rw',
    default => 1
);

has 'trait_cv_name' => (
    isa => 'Str|Undef',
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
    my $trait_cv_name = $self->trait_cv_name() ;
      

    my $trait_cv = $schema->resultset("Cv::Cv")->search(
	{ name => $trait_cv_name } )->single;
    my $trait_cv_id = $trait_cv->cv_id;
   
    my %trait_id_list;
    if ($self->trait_id_list){
        %trait_id_list = map { $_ => 1} @{$self->trait_id_list};
    }

    my %trait_definition_list;
    if ($self->trait_definition_list){
        %trait_definition_list = map { $_ => 1} @{$self->trait_definition_list};
    }

    my %trait_name_list;
    my $trait_name_string;
    if ($self->trait_name_list){
        %trait_name_list = map { $_ => 1} @{$self->trait_name_list};
        foreach (@{$self->trait_name_list}){
            $trait_name_string .= $_;
        }
    }
    my $trait_name_is_exact = $self->trait_name_is_exact;
    my $sort_by = $self->sort_by;
    my $order_by = $self->order_by || 'me.name';

    my $trait_rs;
    
    if ($is_variable) { 
	# pre-fetch some information; more efficient
	my $variable_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'VARIABLE_OF', $trait_cv_name)->cvterm_id();
    
 

	$trait_rs = $schema->resultset("Cv::Cvterm")->search(
	    { cv_id => $trait_cv_id },
	    {
		join   =>  'cvterm_relationship_subjects' ,
		where  => { 
		    'type_id'    => $variable_of_cvterm_id,
		    'is_obsolete' => 0,
		    'is_relationshiptype' => 0,
		} ,
        order_by => { '-asc' => $order_by }
	    }
	    );
    } else { 
	$trait_rs = $schema->resultset("Cv::Cv")->search(
	    { 'me.name' => $trait_cv_name },
	    {
		join   => { 'cvterms' },
		where  => { 
		    'is_obsolete' => 0,
		    'is_relationshiptype' => 0,
		},
        order_by => { '-asc' => $order_by }
	    }
	    );
    }
    my @result;
    my %traits = ();

    my $limit = $self->limit;
    my $offset = $self->offset;
    my $records_total = $trait_rs->count();
    if (defined($limit) && defined($offset)){
        $trait_rs = $trait_rs->slice($offset, $limit);
    }

    while ( my $t = $trait_rs->next() ) {
        my $trait_id = $t->cvterm_id();
       
        my $trait_name = $t->name();

        $traits{$trait_name}->{trait_id} = $trait_id;
        $traits{$trait_name}->{trait_definition} = $t->definition();
	$traits{$trait_name}->{db_name} = $t->dbxref->db->name();
	$traits{$trait_name}->{accession} = $t->dbxref->accession();
    }
    
    foreach my $t ( sort( keys(%traits) ) ) {
	no warnings 'uninitialized';
	
	if (scalar(keys %trait_id_list)>0){
	    next
		unless ( exists( $trait_id_list{$traits{$t}->{trial_id}} ) );
	}
	if (scalar(keys %trait_name_list)>0){
	    if ($self->trait_name_is_exact){
                next
                    unless ( exists( $trait_name_list{$t} ) );
            } else {
                next
		    unless ( index($trait_name_string, $t) != -1 );
            }
        }

        push @result, {
            trait_id => $traits{$t}->{trait_id},
            trait_name => $t,
	    trait_definition => $traits{$t}->{trait_definition},
	    db_name => $traits{$t}->{db_name},
	    accession=> $traits{$t}->{accession},
	};
    }

    return \@result;
}

1;
