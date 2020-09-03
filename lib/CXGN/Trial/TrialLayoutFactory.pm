
package CXGN::Trial::TrialLayoutFactory;

use Moose;
use namespace::autoclean;
use CXGN::Trial::TrialLayout::Analysis;
use CXGN::Trial::TrialLayout::Phenotyping;
use CXGN::Trial::TrialLayout::Genotyping;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    #required => 1,
);

has 'trial_id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_trial_id',
    trigger => \&_lookup_trial_id,
    #required => 1
);

has 'experiment_type' => (
    is       => 'rw',
    isa     => 'Str', #field_layout or genotyping_layout
    #required => 1,
);


sub create {
    my $self = shift;
    my $args = shift;
    
    if ($args->{experiment_type} eq "analysis_experiment") {
	return CXGN::Trial::TrialLayout::Analysis->new($args);
    }

    if ($args->{experiment_type} eq "field_layout"  || ! $args->{experiment_type}) {
	return CXGN::Trial::TrialLayout::Phenotyping->new($args);
    }

    if ($args->{experiment_type} eq "genotyping_layout") {
	return CXGN::Trial::TrialLayout::Genotyping->new($args);
    }

    print STDERR "unknown experiment_type ".$args->{experiment_type}."\n";
    return undef;
}


__PACKAGE__->meta->make_immutable;

1;
