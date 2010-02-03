
=head1 NAME

CXGN::Page::Simple - a simple page object with fewer dependencies, useful for "standalone" projects

=head1 DESCRIPTION

This module is similar to CXGN::Page, but does not inherit from CXGN::Scrap, and has fewer dependencies. It is intended for use in "standalone" applications that use the SGN codebase but do not implement all the bells and whistles of the SGN system.

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS

This module implements the following functions (a subset of the CXGN::Page functions that are essential for simple web programming):

=cut


use strict;

package CXGN::Page::Simple;

use Apache2::Request;
use Carp;
use base qw/CXGN::Scrap/;

=head2 constructor new()

  Args: none
  Ret:  a CXGN::Page::Simple object

=cut

sub new { 
    my $class = shift;
    my $self = bless {}, $class;
    $self->{request} ||= Apache2::RequestUtil->request;
    $self->{apache_request} ||= Apache2::Request->instance($self->{request});
    return $self;
}

=head2 function get_encoded_arguments()

  Args: a list of parameter names
  Ret:  a list of corresponding values from Apache Request object,
        encoded in HTML encoding 

=cut

sub get_encoded_arguments {
  my($self,@items)=@_;
  return map {HTML::Entities::encode_entities($_,"<>&'\"")} $self->get_arguments(@items);
  #encoding does not appear to work for foreign characters with umlauts, etc. so we're using this restricted version of the command
}
    
=head2 get_arguments

Gets arguments which are being sent in via GET or POST (doesn\'t matter which). DOES NOT encode the HTML entities in those arguments, so be careful because it IS possible for clients to submit evil HTML, javascript, etc.

	#Example
	my($fasta_file)=$scrap->get_arguments("fasta_file");

=cut

# only use this method if you need unfiltered arguments with weird characters
# in them, like passwords and fasta file data. be aware that the user\'s agent
# (browser) could be capable of sending ALMOST ANYTHING to you as parameters.
# --john
sub get_arguments {
	my($self,@items)=@_;
	my $apr = $self->{apache_request};
	return map {
	  my @p = $apr->param($_);
	  if(@p > 1) {
	    carp "WARNING: multiple parameters returned for argument '$_'";
	    \@p
	  } elsif(@p == 1) {
	    $p[0]
	  } else {
	    ''
	  }
	} @items;
}


=head2 function header()

  Args: An optional header string
  Ret:  Nothing
  Side Effects: prints a header to STDOUT

=cut

sub header { 
    my $self = shift;
    my $header_string = shift;
    
        print <<END_HTML;

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<title>
$header_string
</title>
<link rel="stylesheet" href="/documents/inc/sgn.css" type="text/css" />
</head>
<body>
<center>
<a name=\"top\"></a>

<table summary="" width="800" cellpadding="0" cellspacing="0" border="0">
<tr>
<td width="35"><a href="/"><img src="/documents/img/sgn_logo_icon.png" border="0" width="30" height="30" /></a></td>
<td style="color: gray; font-size:12px; font-weight: bold; vertical-align: middle">$header_string</td></tr>
</table>
<table summary="" width="800" cellpadding="0" cellspacing="0" border="0">
<tr><td>
<hr>

END_HTML

}

=head2 function footer()

  Args: none
  Ret:  nothing
  Side Effects: prints a footer to STDOUT

=cut

sub footer { 
 print <<END_HEREDOC;
</td></tr>
<tr><td><hr></td></tr>
<tr><td><font color="gray" size="1">Copyright &copy; 2003-2007 <a href="http://sgn.cornell.edu/" class="footer" >Sol Genomics Network</a> and <a class="footer" href="http://www.cornell.edu/">Cornell University</a>.<br />Development of this software was supported by the <a class="footer" href="http://www.nsf.gov/">U.S. National Science Foundation</a>.</td></tr>
</table>
</center>
</body>
</html>
END_HEREDOC
}


return 1;
