=head1 NAME

CXGN::People::Forum - classes to handle the SOL forum on the SGN website.

=head1 DESCRIPTION

The Forum comprises three main classes:

=over 5

=item o

CXGN::People::Forum

=item o

CXGN::People::Forum::Topic

=item o

CXGN::People::Forum::Post

=back

These are described in more detail below.

=head1 AUTHOR 

Lukas Mueller (lam87@cornell.edu)

=cut

use strict;
require CXGN::Contact;
use CXGN::People::Forum::Topic;
use CXGN::People::Forum::Post;

=head1 PACKAGE CXGN::People::Forum

Parent class of CXGN::People::* classes that essentially handles database access and provides utility functions used by all subclasses.

=cut

package CXGN::People::Forum;

#use base qw( CXGN::Class::DBI );
use base qw | CXGN::DB::Object |;


=head2 function new()

  Synopsis:	constructor
  Arguments:	none
  Returns:	a CXGN::People::Forum object
  Side effects:	establishes a connection to the database
  Description:	should not be called explicitly, but rather
                by subclasses of this class.

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    
    my $self = $class->SUPER::new($dbh);

    return $self;
}

=head2 function format_post_text()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	formats a post or topic text for display. 
                Note that it converts certain embedded tags to 
                html links. This function does not assure security
                - use the get_encoded_arguments in the CXGN::Page 
                object for that purpose.

=cut

sub format_post_text { 
    my $self = shift;
    my $post_text = shift;
    
    # support vB script url tag
    while ($post_text =~ /\[url\](.*?)\[\/url\]/g ) { 
	my $link = $1;
	my $replace_link = $link;
	if ($link !~ /^http/i) { 
	    $replace_link = "http:\/\/$link"; 
	}
	$post_text =~ s/\[url\]$link\[\/url\]/\<a href=\"$replace_link\"\>$replace_link\<\/a\>/g;
    }
    # convert newlines to <br /> tags
    #
    $post_text =~ s/\n/\<br \/\>/g;
    return $post_text;
}

1;

