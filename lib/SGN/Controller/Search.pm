package SGN::Controller::Search;

use Moose;
use namespace::autoclean;
use CXGN::Genomic::Search::Clone;
use HTML::FormFu;
use YAML::Any qw/LoadFile/;
use CXGN::Search::CannedForms;
use CXGN::Page::Toolbar::SGN;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::DirectSearch - Catalyst Controller

=head1 DESCRIPTION

Direct search catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub search :Path('/search') :Args(1) {
    my ( $self, $c, $term ) = @_;
    if ($term) {
        $c->response->body( "stuff" );
    } else {
        my $tb = CXGN::Page::Toolbar::SGN->new();
        $c->response->body( $tb->index_page('search') );
    }
}


=head1 AUTHOR

Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
