
=head1 NAME

CXGN::Apache::Request

=head1 DESCRIPTION

This module is used mainly by CXGN::Apache::Error to provide detailed information about who caused a page error and how they caused it.

=head1 NON-OBJECT METHODS

=head2 as_verbose_string

A more detailed version of Apache::Request::as_string. It returns a big string full of information about who is requesting a page, how they are requesting it, etc.

=head2 client_name

Get the name of the client and also note if the client is from SGN by returning a second parameter.

=head2 page_name

Returns the page_name by extracting it from the current page request. Note: /tools/does_not_exist.pl needs it to be done this way, rather than asking for this information from perl environment variables, because "does_not_exist.pl" (the page the client was sent to) would be returned by the environment variables, rather than the page the client originally requested.

=head2 time

Returns a string indicating the time in Ithaca NY. Used to associate a time with an error report.

=head1 AUTHOR

john binns - John Binns <zombieite@gmail.com>

=cut

package CXGN::Apache::Request;
use strict;

use Apache2::RequestUtil ();
use Apache2::Connection ();

#use CXGN::Login;
use URI::Escape;
use Socket;    #used to get hostname from IP
our $CORNELL_IP_MATCH = '132.236.157.';
our $OTHER_KNOWN_IPS  = {
    '127.0.0.1'    => 'localhost',
    '24.22.41.189' => 'Rob'
};

sub as_verbose_string {
    my $verbose_string = "";
    my $request        = Apache2::RequestUtil->request();
    my $time           = &time();
    my ( $client_name, $cornell_client_name ) = &client_name();
    my ( $page_name,   $parameters )          = &page_name();
    if ($parameters) {
        $parameters =~ s/&amp;/\n/g;
        $parameters =~ s/&/\n/g;
        $parameters =~ s/;/\n/g;
    }

    #    my $login=CXGN::Login->new();
    #    my $id=$login->has_session();
    $verbose_string .= "\nApache request\n--------------\n";
    $verbose_string .=
      "$page_name on SGN requested by $client_name at $time\n\n";
    if ($parameters) { $verbose_string .= "with parameters:\n$parameters\n\n"; }

    #    if($id){$verbose_string.="with login ID: $id\n\n";}
    $verbose_string .= $request->as_string();
    return ($verbose_string);
}

sub time {
    my ( $sec, $min, $hour, $day, $month, $year ) = localtime();
    $sec = sprintf( "%02d", $sec );
    $min = sprintf( "%02d", $min );
    $month += 1;
    $year = sprintf( "%02d", $year % 100 );
    return "$month/$day-$hour:$min:$sec";
}

sub client_name {
    my $request     = Apache2::RequestUtil->request();
    my $remote_host = $request->connection->get_remote_host();
    my $client_name =
      gethostbyaddr( inet_aton($remote_host), AF_INET )
      ;    #see perldoc -f gethostbyaddr
    if ($client_name) {
        $client_name .= ' (' . $remote_host . ')';
    }
    else {
        $client_name = $remote_host;
    }
    my $known_client_name;
    if ( $remote_host =~ /$CORNELL_IP_MATCH/ ) {
        if ( $client_name =~ /(\w+)\.sgn\.cornell\.edu/ ) {
            $known_client_name = $1;
        }
        else {
            $known_client_name = $client_name;
        }
    }
    else {
        $known_client_name = $OTHER_KNOWN_IPS->{$remote_host};
    }
    return ( $client_name, $known_client_name );
}

sub full_page_name {
    my ($request_string) = @_
      ; #you can send in a string if you want (does_not_exist.pl does this for reasons of its own)
    my $parameter_string = '';
    $request_string ||=
      Apache2::RequestUtil->request()->the_request();    #or we can get it ourselves
    if ( $request_string =~ / (.+) /i
      ) #if the request says "GET /cgi-bin/mypage.pl?arg=1 HTTP/1.1" we want the "/cgi-bin/mypage.pl?arg=1" between the space characters
    {
        $request_string = $1;
    }
    $request_string = URI::Escape::uri_unescape($request_string)
      ;    #usually unnecessary, but occasionally we get wacky encoded requests
    if ( $request_string =~
        /(.+)\?(.*)/ )    #if the request string has parameters, remove them
    {
        $request_string   = $1;
        $parameter_string = $2;
    }
    return ( $request_string, $parameter_string );
}

sub page_name {
    my ($request_string) = @_
      ; #you can send in a string if you want (does_not_exist.pl does this for reasons of its own)
    my $parameter_string = '';
    ( $request_string, $parameter_string ) = full_page_name($request_string);
    unless ($parameter_string) { $parameter_string = ''; }
    if ( $request_string =~
        /\/((\w|-)+\.(pl|html|htm|js|gif|jpg|css|png|ppt|xls|pdf|cgi))/i
      )    #if we can recognize the script name in the request string, get it
    {
        if ( $1 ne 'index.pl'
          ) #index.pl is not descriptive enough, so don't use it if that's all we have
        {
            $request_string = $1;
        }
    }
    return ( $request_string, $parameter_string );
}

1;
