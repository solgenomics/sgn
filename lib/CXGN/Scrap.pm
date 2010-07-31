package CXGN::Scrap;

=head1 NAME

 CXGN::Scrap

=head1 DESCRIPTION

 Simplified page object, now a superclass of CXGN::Page.  Also changed
 to be a singleton class.  Provides the apache_request bindings for
 argument retrieval, but doesn't do much else.  The motivation for this
 module was to create a subclass of a simple page object for AJAX
 requests.

=cut


use strict;
use warnings;
use Clone;
use HTML::Entities;
use Carp;
use CGI;

use File::Path ();

use JSAN::ServerSide;
use SGN::Context;

=head1 OBJECT METHODS

=head2 new

Creates returns the singleton page-scrap object.

#Example
my $scrap=CXGN::Scrap->new();

=cut

sub new {
  my $class=shift;
  my $self = bless {},$class;
  $self->{content_type} = 'text/html';
  $self->{vhost} = SGN::Context->instance;
  $self->{cgi} = CGI->new;
  return $self;
}

=head2 get_encoded_arguments

Gets arguments which are being sent in via GET or POST (doesn't matter which). Encodes the HTML entities in those arguments to keep clients from being able to submit evil HTML, javascript, etc. to be printed on our pages.

	#Example
	my($id,$name)=$scrap->get_encoded_arguments("id","name");

=cut

# use this one for all alphanumeric arguments, unless for some reason you don't
# want to filter out possibly evil characters (see below)
sub get_encoded_arguments {
  my($self,@items)=@_;

  return map {HTML::Entities::encode_entities($_,"<>&'\"")} $self->get_arguments(@items);
  # encoding does not appear to work for foreign characters with
  # umlauts, etc. so we're using this restricted version of the command
}


=head2 get_all_encoded_arguments

Args: none
Ret : hash of ( argument name => HTML-encoded value of that argument )

WARNING: this method does not work for POSTs of type multipart/form-data, particularly with file uploads.  This method only works with GET and other POST requests.

=cut

sub get_all_encoded_arguments {
  my ($self) = @_;
  my $r = $self->{apache_request};
  my %vars = %{$self->{cgi}->Vars};
  $_ = HTML::Entities::encode_entities($_,"<>&'\";") for values %vars;
  return %vars;
}


=head2 get_upload

Get the L<Apache2::Upload> object for the currently uploaded file, if any.

=cut

sub get_upload {
  my $self = shift;
  my @upload_names = $self->{apache_request}->upload();
  if( wantarray ) {
      return map $self->{apache_request}->upload($_), @upload_names;
  } else {
      return $self->{apache_request}->upload( $upload_names[0] );
  }
}

=head2 get_arguments

Gets arguments which are being sent in via GET or POST (doesn't matter which). DOES NOT encode the HTML entities in those arguments, so be careful because it IS possible for clients to submit evil HTML, javascript, etc.

	#Example
	my($fasta_file)=$scrap->get_arguments("fasta_file");

=cut

# only use this method if you need unfiltered arguments with weird characters
# in them, like passwords and fasta file data. be aware that the user's agent
# (browser) could be capable of sending ALMOST ANYTHING to you as parameters.
# --john
sub get_arguments {
	my($self,@items)=@_;
	my @args = map {
	  my @p = $self->{cgi}->param($_);
	  if(@p > 1) {
	    carp "WARNING: multiple parameters returned for argument '$_'";
	    \@p
	  }
	  else {
	    no warnings 'uninitialized';
	    length $p[0] ? $p[0] : undef
	  }
	} @items;
	return @args if wantarray;
	return $args[0];
}

=head2 jsan_use

  Usage: $scrap->jsan_use('MyModule.Name');
  Desc : add a javascript module (and its dependent javascript
         modules) to the list of js modules needed by this page scrap
  Args : list of module names in My.Module.Name form
  Ret  : nothing meaningful

=cut

sub jsan_use {
  my ($self,@uses) = @_;
  $self->_jsan->add(my $a = $_) foreach @uses;
}

=head2 jsan_render_includes

  Usage: my $str = $scrap->jsan_render_includes
  Desc : render HTML script-tag includes for javascript
         modules required with jsan_use(), plus the globally-used
         javascript modules defined herein, currently:

           CXGN.Effects
           CXGN.Page.FormattingHelpers
           CXGN.Page.Toolbar
           CXGN.UserPrefs

  Args : none
  Ret  : a string containing zero or more newline-separated
         include statements
  Side Effects: none

=cut

my @global_js = qw(
		   CXGN.Effects
		   CXGN.Page.FormattingHelpers
		   CXGN.UserPrefs
		  );

sub jsan_render_includes {
	my ($self) = @_;

	# add in our global JS, which is used for every page
	# JSAN::ServerSide is pretty badly written.  cannot use $_ to
	# pass the name to add()
	foreach my $js (@global_js) {
	    $self->_jsan->add($js);
	}

	return join "\n",
	       map qq|<script language="JavaScript" src="$_" type="text/javascript"></script>|,
	       $self->_jsan->uris;
}

sub _jsan {
	my ($self) = @_;

	return $self->{jsan_serverside} ||= JSAN::ServerSide->new( %{ $self->{context}->_jsan_params } );
}

=head2 cgi_params

Wrapper for CGI->new()->Vars(). Used when you have many arguments with the same name.

	#Example
	my %params=$scrap->params();

=cut

# if you have lists of same-named parameters you will probably want to
# handle that yourself using this function which returns a hash (not
# hash reference)
sub cgi_params {
	return shift->{cgi}->Vars();
}

=head2 get_hostname

  Usage: my $hostname = $page->hostname();
  Desc : get the hostname in the current page request (from
         CGI::server_name())
  Args : none
  Ret  : hostname string
  Side Effects: none

=cut

sub get_hostname {
  shift->{cgi}->server_name();
}

=head2 get_request

  Usage: my $req = $page->get_request();
  Desc : get the CGI object for the current page
         request
  Args : none
  Ret  : an Apache object
  Side Effects: none

=cut

sub get_request {
  shift->{cgi};
}


=head2 get_apache_request

  Usage: my $areq = $page->apache_request();
  Desc : get the Apache::Request for this request, equivalent to
         Apache::Request->instance( $page->request() )
  Args : none
  Ret  : an L<Apache::Request> object
  Side Effects: none

=cut

sub get_apache_request {
  shift->{apache_request}
}


=head2 is_bot_request

  Usage: print "it's a bot" if $page->is_bot_request;
  Desc : return true if this page request is probably coming from a
         web-crawling robot
  Args : none
  Ret  : boolean
  Side Effects: none

=cut

sub is_bot_request {
  my $user_agent = shift->get_request->headers_in->{'User-Agent'};

  return 1 if
    ( $user_agent =~ m|bot/\d|i #< will get google, msn
      || $user_agent =~ /Yahoo!?\s+Slurp/i #< will get yahoo
    );

  return;
}


=head2 send_content_type_header

  Usage: $page->send_content_type_header()
  Desc : set an http content-type header
  Args : optional string content type to send,
         defaults to 'text/html'
  Ret  : nothing meaningful
  Side Effects: dies on error

=cut


sub send_content_type_header {
    my ( $self, $type ) = @_;
    print "Content-type: ".($type || $self->{content_type} || 'text/html')."\n\n";
}


=head2 path_to

  Usage: $page->path_to('/something/somewhere.txt');
  Desc : get the full path to a file relative to the
         base path of the web server
  Args : file path relative to the site root
  Ret  : absolute file path
  Side Effects: dies on error

=cut

sub path_to {
    shift->{vhost}->path_to(@_)
}


=head2 tempfiles_subdir

  Usage: my $dir = $page->tempfiles_subdir('some','dir');
  Desc : get the path to this site's web-server-accessible tempfiles directory.
  Args : (optional) one or more directory names to append onto the tempdir root
  Ret  : full filesystem pathname to the relevant dir
  Side Effects: dies on error

=cut

sub tempfiles_subdir {
    shift->{vhost}->tempfiles_subdir(@_);
}


=head2 get_conf

  convenience method, forwards to to CXGN::VHost::get_conf();

  equivalent to doing CXGN::VHost->new->get_conf(@_);

=cut

sub get_conf {
  my $self = shift;
  return $self->{vhost}->get_conf(@_);
}


=head1 AUTHORS

John Binns - John Binns <zombieite@gmail.com>  (methods)

Christopher Carpita  <csc32@cornell.edu> (constructor/org)

=cut

####
1; # do not remove
####
