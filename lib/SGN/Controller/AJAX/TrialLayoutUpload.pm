
=head1 NAME

SGN::Controller::AJAX::TrialLayoutUpload - a REST controller class to provide the
backend for uploading trial layouts

=head1 DESCRIPTION

Uploading trial layouts

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>


=cut

package SGN::Controller::AJAX::TrialLayoutUpload;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Phenome::Schema;
#use CXGN::Phenome::Allele;
use CXGN::Chado::Stock;
#use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use Scalar::Util qw(looks_like_number);
use File::Slurp;

#BEGIN { extends 'Catalyst::Controller'; }
BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);
sub _build_schema {
  shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

#sub upload_trial_layout :  Local :ActionClass('REST') {}
#sub upload_trial_layout :  PATH('/trial/upload_trial_layout') :ActionClass('REST') {}

#sub upload_trial_layout_GET :Args(0) {
#sub upload_cross :  Path('/cross/upload_cross')  Args(0) {




#sub add_cross_GET :Args(0) {






sub upload_trial_layout :  Path('/trial/upload_trial_layout') : ActionClass('REST') { }

###sub upload_trial_layout :  Path('/trial/upload_trial_layout')  Args(0) {
sub upload_trial_layout_POST : Args(0) {
  my ($self, $c) = @_;
  print STDERR "\n\n\n Running submit controller\n";

  my $upload = $c->req->upload('trial_upload_file');
  my $file_name = $c->req->param('trial_upload_file');
  print STDERR "form submit: $file_name\n";
  
  my @contents = split /\n/, $upload->slurp;
  print STDERR $contents[0] . " is the first line\n";
  #my ($self, $c, $stock_id) = @_;
  # my $stock = CXGN::Chado::Stock->new($self->schema, $stock_id);
  # $c->stash->{stock} = $stock;
  # my $stock_row = $self->schema->resultset('Stock::Stock')
  #   ->find({ stock_id => $stock_id });
  # my $stock_pedigree = $self->_get_pedigree($stock_row);
  # print STDERR "STOCK PEDIGREE: ". Data::Dumper::Dumper($stock_pedigree);
  # my $stock_pedigree_svg = $self->_view_pedigree($stock_pedigree);
  # print STDERR "SVG: $stock_pedigree_svg\n\n";
  # my $is_owner = $self->_check_role($c);
  # $c->response->content_type('image/svg+xml');
  # if ($stock_pedigree_svg) {
  #   $c->response->body($stock_pedigree_svg);
  # } else {
     my $blank_svg = SVG->new(width=>1,height=>1);
     my $blank_svg_xml = $blank_svg->xmlify();
   my $the_result = "{ error => 'here is a result', }";
   $c->stash->{rest} = {error => "Can you really see this?" };
   #$c->response->body($the_result);
     #$c->response->body($blank_svg_xml);
  # }
}








# sub upload_trial_layout : PATH('/trial/upload_trial_layout') : Args(0) {
#    my ($self, $c) = @_;
#    #my @response_list;
#    my $the_result = { error => 'here is a result', };
#    #push @response_list, $the_result;
#    #$c->stash->{rest} = \@response_list;
#    $c->stash->{rest} = {error => "Testing the error" };
#    $c->response->body($the_result);
#    return;

# }

1;
