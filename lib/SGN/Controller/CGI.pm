=head1 NAME

SGN::Controller::CGI - run SGN CGI scripts

=cut

package SGN::Controller::CGI;

use Moose;
use namespace::autoclean;

BEGIN{ extends 'Catalyst::Controller::CGIBin'; }

use Carp;
use File::Basename;

my %skip = map { $_ => 1 } qw(
  another_page_that_doesnt_compile.pl
  page_with_syntax_error.pl
);

# all our .pl cgis are perl
sub is_perl_cgi {
    my ($self,$path) = @_;
    return 0 if $skip{ basename($path) };
    return $path =~ /\.pl$/;
}

around 'wrap_cgi' => sub {
    my $orig = shift;
    my $self = shift;
    my ($c) = @_;
    local $SIG{__DIE__} = $c->debug ? \&Carp::confess : $SIG{__DIE__};
    $self->$orig( @_ );
};


1;
