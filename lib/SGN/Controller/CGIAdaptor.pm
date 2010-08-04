=head1 NAME

SGN::Controller::CGI - run SGN CGI scripts

=cut

package SGN::Controller::CGIAdaptor;

use Moose;
use namespace::autoclean;

extends 'Catalyst::Controller::CGIBin';

# NOTE: 90% of the code below will go away, with new features I am
# adding to the Catalyst::Controller::CGIBin base class.

use Carp;
use File::Basename;
use File::Slurp 'slurp';
use HTTP::Request::Common;

open my $REAL_STDIN, "<&=".fileno(*STDIN);
open my $REAL_STDOUT, ">>&=".fileno(*STDOUT);

sub wrap_perl_cgi {
    my ($self, $cgi, $action_name) = @_;

    my $code = slurp $cgi;

    $code =~ s/^__DATA__(?:\r?\n|\r\n?)(.*)//ms;
    my $data = $1;

    my $coderef = do {
        no warnings;
        # catch exit() and turn it into (effectively) a return
        # we *must* eval STRING because the code needs to be compiled with the
        # overridden CORE::GLOBAL::exit in view
        #
        # set $0 to the name of the cgi file in case it's used there
        eval join "\n", (
            '
            my $cgi_exited = "EXIT\n";
            BEGIN { *CORE::GLOBAL::exit = sub (;$) {
                die [ $cgi_exited, $_[0] || 0 ];
            } }
            package Catalyst::Controller::CGIBin::_CGIs_::'.$action_name.';
            sub {'
                , 'our $c = shift;'
                , 'local *DATA;'
                , q{open DATA, '<', \$data;}
                , qq{local \$0 = "\Q$cgi\E";}
                , q/my $rv = eval {/
                , "#line 1 $cgi"
                , $code
                , q/};/
                , q{
                    return $rv unless $@;
                    die $@ if $@ and not (
                      ref($@) eq 'ARRAY' and
                      $@->[0] eq $cgi_exited
                    );
                    die "exited nonzero: $@->[1]" if $@->[1] != 0;
                    return $rv;
                }
         , '}'
        );
    };

    croak __PACKAGE__ . ": Could not compile $cgi to coderef: $@" if $@;

    $coderef
}



sub wrap_cgi {
  my ($self, $c, $call) = @_;
  my $req = HTTP::Request->new(
    map { $c->req->$_ } qw/method uri headers/
  );
  my $body = $c->req->body;
  my $body_content = '';

  $req->content_type($c->req->content_type); # set this now so we can override

  if ($body) { # Slurp from body filehandle
    local $/; $body_content = <$body>;
  } else {
    my $body_params = $c->req->body_parameters;

    if (my %uploads = %{ $c->req->uploads }) {
      my $post = POST 'http://localhost/',
        Content_Type => 'form-data',
        Content => [
          %$body_params,
          map {
            my $upl = $uploads{$_};
            $_ => [
              undef,
              $upl->filename,
              Content => $upl->slurp,
              map {
                my $header = $_;
                map { $header => $_ } $upl->headers->header($header)
              } $upl->headers->header_field_names
            ]
          } keys %uploads
        ];
      $body_content = $post->content;
      $req->content_type($post->header('Content-Type'));
    } elsif (%$body_params) {
      my $encoder = URI->new;
      $encoder->query_form(%$body_params);
      $body_content = $encoder->query;
      $req->content_type('application/x-www-form-urlencoded');
    }
  }

  my $filtered_env = $self->_filtered_env(\%ENV);

  $req->content($body_content);
  $req->content_length(length($body_content));

  my $username_field = $self->{CGI}{username_field} || 'username';

  my $username = (($c->can('user_exists') && $c->user_exists)
               ? eval { $c->user->obj->$username_field }
                : '');

  $username ||= $c->req->remote_user if $c->req->can('remote_user');

  my $path_info = '/'.join '/' => map {
    utf8::is_utf8($_) ? uri_escape_utf8($_) : uri_escape($_)
  } @{ $c->req->args };

  my $env = HTTP::Request::AsCGI->new(
              $req,
              ($username ? (REMOTE_USER => $username) : ()),
              %$filtered_env,
              PATH_INFO => $path_info,
# eww, this is likely broken:
              FILEPATH_INFO => '/'.$c->action.$path_info,
              SCRIPT_NAME => $c->uri_for($c->action, $c->req->captures)->path
            );

  {
    local *STDIN = $REAL_STDIN;   # restore the real ones so the filenos
    local *STDOUT = $REAL_STDOUT; # are 0 and 1 for the env setup

    my $old = select($REAL_STDOUT); # in case somebody just calls 'print'

    my $saved_error;

    $env->setup;
    eval { $call->($c) };
    $saved_error = $@;
    $env->restore;

    select($old);

    if( $saved_error ) {
        die $saved_error if ref $saved_error;
        Catalyst::Exception->throw( message => $saved_error );
    }
  }

  return $env->response;
}

my %skip = map { $_ => 1 } qw(
  another_page_that_doesnt_compile.pl
  page_with_syntax_error.pl
);

sub is_perl_cgi {
    my ($self,$path) = @_;
    return 0 if $skip{ basename($path) };
    return $path =~ /\.pl$/;
} #< all our cgis are perl


1;

