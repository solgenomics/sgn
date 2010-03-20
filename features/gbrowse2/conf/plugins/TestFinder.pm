package Bio::Graphics::Browser2::Plugin::TestFinder;

use strict;
use warnings;
use base 'Bio::Graphics::Browser2::Plugin';

sub name { 'Features by type'}

sub type { 'finder' }

# return all objects of type given in the search field
sub find {
  my $self     = shift;
  my $query    = $self->page_settings->{name} or return;
  return $self->auto_find($query);
}

sub auto_find {
    my $self  = shift;
    my $query = shift;
    my $search = $self->db_search;
    my $features = $search->search_features({-type=>$query});
    return @$features ? $features : undef;
}

1;
