use strict;
use warnings;
use CGI ();
use Try::Tiny;
use List::Util qw/max/;

my ($error_code) = CGI->new->param('code');

if( $error_code == 404 ) {


    if(    $ENV{HTTP_REFERER} =~ m|http://[^/]*$ENV{HTTP_HOST}|
        && $c->get_conf('production_server')
       ) {

        # this 404 is our mistake (i.e. the referrer is one of ours),
        # try to send the dev team an email before displaying the 404
        # page
        try {
            require Mail::Sendmail;
            Mail::Sendmail::sendmail(
                To      => $c->get_conf('bugs_email'),
                From    => 'www@'.$ENV{HTTP_HOST},
                Subject => "Broken link on $ENV{HTTP_REFERER}: $ENV{REQUEST_URI}",
                Body    => format_env( %ENV ),
               ) or die $Mail::Sendmail::error;
        } catch {
            warn "$0: could not send 404 broken link email: $_";
        };

        $c->forward_to_mason_view( '/site/error/404.mas', message => 'We apologize for the inconvenience. An error report has been sent to the development team.' );
    } else {
        $c->forward_to_mason_view( '/site/error/404.mas', message => 'You may want to contact the referring site and inform them of this error.');
    }


} else {

    $c->forward_to_mason_view( '/site/error/'.($error_code+0).'.mas' );
}

# format the ENV hash into name => value, one per line,
# with names padded to make the output columnar
sub format_env {
    my %env = @_;
    my $key_width = 3 + max map length, keys %env;
    return join '', map {
        $_                            # key
      . ' ' x ( $key_width - length ) # padding
      . '=> '                         # =>
      . $env{$_}                      # value
      . "\n"                          # newline
    } sort keys %env;
}

