=head1 NAME

SGN::Controller::CGI - run SGN CGI scripts

=cut

package SGN::Controller::CGI;

use Moose;
use namespace::autoclean;

BEGIN{ extends 'Catalyst::Controller::CGIBin'; }

__PACKAGE__->config(
    cgi_root_path => '/',
    CGI => {
        pass_env => [qw[ PERL5LIB  PATH  PROJECT_NAME  R_LIBS HOME ]],
    },
    cgi_file_pattern => '*.pl',
);


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

if( $ENV{SGN_SKIP_CGI} ) {
    override 'cgi_dir' => sub { File::Spec->devnull },
}

# force CGI backtrace only if app is starting, and is in debug mode
if( eval{ SGN->debug } ) {
    around 'wrap_cgi' => sub {
        my $orig = shift;
        my $self = shift;
        my ($c) = @_;
        local $SIG{__DIE__} =
            $c->debug
                ? sub {
                    die map {
                        s/\sCatalyst::Controller::CGIBin.+//s;
                        $_
                    } Carp::longmess(@_);
                  }
                : $SIG{__DIE__};
        $self->$orig( @_ );
    };
}

sub cgi_action_for {
    my ( $self, $path ) = @_;

    my $action_name = $self->cgi_action($path)
        or return;

    return $self->action_for( $action_name )
}

1;
