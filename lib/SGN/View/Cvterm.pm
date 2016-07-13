package SGN::View::Cvterm;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    cvterm_link
    sort_onto_tree
/;
our @EXPORT = ();

sub cvterm_link {
    my ($cvterm) = @_;
    my $name = $cvterm->name;
    my $id   = $cvterm->cvterm_id;
    return qq{<a href="/cvterm/$id/view">$name</a>};
}


sub sort_onto_tree {
  my $cvterm = shift;
  my $sorted_tree = shift;
  my @direct_children = $cvterm->children->all;
 
  my %children_hash = map { $_->subject->name , $_->subject } @direct_children;
  foreach my $term_name (sort keys %children_hash ) {
      push @$sorted_tree , $term_name if !grep (/^$term_name$/ , @$sorted_tree);
      sort_onto_tree( $children_hash{$term_name} , $sorted_tree)
  }
  return $sorted_tree;
}


######
1;
######
