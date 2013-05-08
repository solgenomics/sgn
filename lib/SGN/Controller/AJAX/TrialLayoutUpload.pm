
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
  my @contents;
  my $upload = $c->req->upload('trial_upload_file');
  my $header_line;
  my @header_contents;

  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to upload a file." };
    return;
  }

  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a file." };
    return;
  }

  if (!$upload) {
    $c->stash->{rest} = {error => "File upload failed: no file name received"};
    return;
  }

  try {
    @contents = split /\n/, $upload->slurp;
  } catch {
    $c->stash->{rest} = {error => "File upload failed: $_"};
    return;
  };

  #verify header
  try {
  $header_line = shift(@contents);
  @header_contents = split /\t/, $header_line;
  _verify_trial_layout_header(\@header_contents);
  } catch {
    $c->stash->{rest} = {error => "File upload failed: Wrong column names in header"};
    print STDERR "header error $_\n";
    return;
  };





  print STDERR  "First line is:\n" . $contents[0] . "\n";

  #$c->stash->{rest} = {error => "Can you really see this?" };
}



sub _verify_trial_layout_header {
  my $header_content_ref = shift;
  my @header_contents = @{$header_content_ref};
  #my $header_error;
  if ($header_contents[0] ne 'plot_name' ||
      $header_contents[1] ne 'block_number' ||
      $header_contents[2] ne 'rep_number' ||
      $header_contents[3] ne 'stock_name') {
      #$header_error = "Wrong column names in header";
    die ("Wrong column names in header\n");
    return;
  }
  if (@header_contents != 4) {
    #$header_error = "Wrong number of columns in header";
    die ("Wrong number of columns in header\n");
    return;
  }
  return;
}

sub _verify_trial_layout_file {
  my $self = shift;
  #my $first_line = shift(@contents);
  #my @first_row;



  #    if ($first_row[0] ne 'cross_name' ||
  # 	 $first_row[1] ne 'cross_type' ||
  # 	 $first_row[2] ne 'maternal_parent' ||
  # 	 $first_row[3] ne 'paternal_parent' ||
  # 	 $first_row[4] ne 'trial' ||
  # 	 $first_row[5] ne 'location' ||
  # 	 $first_row[6] ne 'number_of_progeny' ||
  # 	 $first_row[7] ne 'prefix' ||
  # 	 $first_row[8] ne 'suffix' ||
  # 	 $first_row[9] ne 'number_of_flowers' ||
  # 	 $first_row[10] ne 'number_of_seeds') {
  #      $header_error = "<b>Error in header:</b><br>Header should contain the following tab-delimited fields:<br>cross_name<br>cross_type<br>maternal_parent<br>paternal_parent<br>trial<br>location<br>number_of_progeny<br>prefix<br>suffix<br>number_of_flowers<br>number_of_seeds<br>";
  #      print STDERR "$header_error\n";
  #    }
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
