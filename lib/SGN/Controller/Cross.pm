
=head1 NAME

SGN::Controller::AJAX::Cross - a REST controller class to provide the
backend for objects linked with new cross

=head1 DESCRIPTION

Add submit new cross, etc...

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Lukas Mueller <lam87@cornell.edu>


=cut

package SGN::Controller::Cross;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Phenome::Allele;
use CXGN::Chado::Stock;
use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use Scalar::Util qw(looks_like_number);

BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);
sub _build_schema {
  shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub upload_cross :  Path('/cross/upload_cross')  Args(0) {
   my ($self, $c) = @_;
   my $file_name = $c->req->upload('upload_file');
   my $basename = $file_name->basename;
   my $tempfile = $file_name->tempname;
    print STDERR "loading cross file: $tempfile Basename: $basename\n";
  $c->stash->{rest} = { error => '', };
  $c->stash->{tempfile} = $tempfile;
  $c->stash(
        tempfile => $tempfile,
        template => '/breeders_toolbox/upload_crosses_confirm_spreadsheet.mas',
        );
   $c->stash->{rest} = { error => '', };
}



1;
