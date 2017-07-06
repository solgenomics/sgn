package Bio::GeneticRelationships::Individual;
use strict;
use warnings;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Data::Dumper;

use Bio::GeneticRelationships::Pedigree;

=head1 NAME

Indvidual - An individual organism with genetic relationships to other individuals

=head1 SYNOPSIS

my $variable = Bio::GeneticRelationships::Individual->new();

=head1 DESCRIPTION

This class stores information about an individual organism and its genetic relationships to other individuals.

=head2 Methods

=over

=cut

has 'name' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_name',
    required => 1,
    );

has 'id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_id',
    );

has 'pedigree' => (
    isa =>'Bio::GeneticRelationships::Pedigree',
    is => 'rw',
    predicate => 'has_pedigree',
    );

sub recursive_parent_levels {
    my $self = shift;
    my $individual = shift;
    my $max_level = shift;
    my $current_level = shift;

    my @levels;
    if ($current_level > $max_level) {
	print STDERR "Exceeded max_level $max_level, returning.\n";
	return;
    }

    if (!defined($individual)) {
	print STDERR "no more individuals defined...\n";
	return;
    }

    my $p = $individual->get_pedigree();

    if (!defined($p->get_female_parent())) { return; }

    my $cross_type = $p->get_cross_type() || 'unknown';

    if ($cross_type eq "open") {
	print STDERR "Open cross type not supported. Skipping.\n";
	return;
    }

    if (defined($p->get_female_parent()) && defined($p->get_male_parent())) {
	if ($p->get_female_parent()->get_name() eq $p->get_male_parent->get_name()) {
	    $cross_type = "self";
	}
    }

    my $male_parent_name = '';
    if (defined($p->get_male_parent())) {
	$male_parent_name = $p->get_male_parent()->get_name();
    }

    $levels[0] = { female_parent => $p->get_female_parent()->get_name(),
		   male_parent => $male_parent_name ,
		   level => $current_level,
		   cross_type => $cross_type,
		   parent_string => $p->get_female_parent()->get_name().
		       "/".$male_parent_name,
    };

    if ($p->get_female_parent()) {
	my @maternal_levels =  $self->recursive_parent_levels($p->get_female_parent(), $max_level, $current_level+1);
	push @levels, $maternal_levels[0];
    }

    if ($p->get_male_parent()) {
	my @paternal_levels = $self->recursive_parent_levels($p->get_male_parent(), $max_level, $current_level+1);
	push @levels, $paternal_levels[0];
    }

    return @levels;
}


###
1;#do not remove
###

=pod

=back

=head1 LICENSE

Same as Perl.

=head1 AUTHORS

Jeremy D. Edwards <jde22@cornell.edu>

=cut
