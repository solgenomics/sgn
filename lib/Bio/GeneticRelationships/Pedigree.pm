package Bio::GeneticRelationships::Pedigree;
use strict;
use warnings;
use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Bio::GeneticRelationships::Individual;

=head1 NAME

Bio::GeneticRelationships::Pedigree - Pedigree of an individual

=head1 SYNOPSIS

my $variable = Bio::GeneticRelationships::Pedigree->new();

=head1 DESCRIPTION

This class stores an individual's pedigree.

=head2 Methods

=over

=cut

subtype 'CrossType',
  as 'Str',
    where {
      $_ eq 'biparental' ||
      $_ eq 'self' ||
      $_ eq 'open' ||
      $_ eq 'sib' ||
      $_ eq 'polycross' ||
      $_ eq 'bulk' ||
      $_ eq 'bulk_self' ||
      $_ eq 'bulk_open' ||
      $_ eq 'doubled_haploid' ||
      $_ eq 'backcross' ||
      $_ eq 'genetic_transformation' ||
      $_ eq 'reselected' ||
      $_ eq 'unknown' };

has 'name' => (isa => 'Str',is => 'rw', predicate => 'has_name', required => 1,);
has 'cross_type' => (isa =>'CrossType', is => 'rw', predicate => 'has_cross_type', required => 1,);
has 'cross_combination' => (isa =>'Str|Undef', is => 'rw', predicate => 'has_cross_combination');
has 'female_parent' => (isa =>'Bio::GeneticRelationships::Individual', is => 'rw', predicate => 'has_female_parent');
has 'male_parent' => (isa =>'Bio::GeneticRelationships::Individual', is => 'rw', predicate => 'has_male_parent');
has 'selection_name' => (isa => 'Str',is => 'rw', predicate => 'has_selection_name');
has 'female_plot' => (isa =>'Bio::GeneticRelationships::Individual', is => 'rw', predicate => 'has_female_plot');
has 'male_plot' => (isa =>'Bio::GeneticRelationships::Individual', is => 'rw', predicate => 'has_male_plot');
has 'female_plant' => (isa =>'Bio::GeneticRelationships::Individual', is => 'rw', predicate => 'has_female_plant');
has 'male_plant' => (isa =>'Bio::GeneticRelationships::Individual', is => 'rw', predicate => 'has_male_plant');


###
1;                              #do not remove
###

=pod

=back

=head1 LICENSE

  Same as Perl.

=head1 AUTHORS

  Jeremy D. Edwards <jde22@cornell.edu>

=cut
