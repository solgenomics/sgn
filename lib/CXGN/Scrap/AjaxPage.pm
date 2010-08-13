
=head1 NAME

CXGN::Scrap::AjaxPage

=head1 DESCRIPTION

A subclass of CXGN::Scrap, which is the superclass of CXGN::Page, this module performs a few actions in the constructor appropriate for Ajax Pages.  
Use this as a Page module replacement for scripts that don't produce much output and are called asynchronously.

=head1 OBJECT METHODS

=head2 new

Creates a new AjaxPage object.  Receives a content type as an optional argument, which defaults to "text/xml"

	#Example
	my $AjaxPage = CXGN::Scrap::AjaxPage->new();
	$AjaxPage->send_http_header() default "text/xml"
	print $AjaxPage->header();
	print "<option name="candy">cookie</option>"
	print $AjaxPage->footer();

=head1 AUTHORS

Christopher Carpita  <csc32@cornell.edu> 

=cut

package CXGN::Scrap::AjaxPage;
use base qw/CXGN::Scrap/;
use strict;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();
    $self->{content_type} = shift || 'text/html';
    return $self;
}

sub send_http_header {
    my $self = shift;
    $self->send_content_type_header();
}

sub header {
    my $self = shift;
    $self->{doc_header_called} = 1;
    my $extra_head = shift;
    my $caller     = $self->caller();
    if ($caller) {
        $extra_head = "<caller>$caller</caller>\n" . $extra_head;
    }
    chomp $extra_head;
    my $header = <<XML;
<?xml version="1.0" encoding="UTF-8"?>
<scrap>
$extra_head
XML
    return $header;
}

sub footer {
    my $self = shift;
    $self->{doc_footer_called} = 1;
    my $extra_foot = shift;
    chomp $extra_foot;
    return "$extra_foot\n</scrap>";
}

sub caller {
    my $self   = shift;
    my $caller = shift;
    $self->{caller} = $caller if $caller;
    return $self->{caller};
}

sub throw {
    my ( $self, $message ) = @_;
    print $self->header() unless $self->{doc_header_called};
    print "<error>$message</error>";
    print $self->footer();
    exit -1;
}

####
1;    # do not remove
####
