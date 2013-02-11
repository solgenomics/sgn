
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
use File::Slurp;

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
   my $upload = $c->req->upload('upload_file');
   my $visible_to_role = $c->req->param('visible_to_role');
   my $format_type = $c->req->param('format_type');
   my $basename = $upload->basename;
   my $tempfile = $upload->tempname;
   my $error;
   my %errors;
   my %upload_data;
   my @contents = split /\n/, $upload->slurp;
   print STDERR "loading cross file: $tempfile Basename: $basename $format_type $visible_to_role\n";
   $c->stash->{tempfile} = $tempfile;
   if ($format_type eq "spreadsheet") {
     print STDERR "is spreadsheet \n";

     my $first_line = shift(@contents);
     my @first_row = split /\t/, $first_line;
     if ($first_row[0] ne 'cross_name' ||
	 $first_row[1] ne 'maternal_parent' ||
	 $first_row[2] ne 'paternal_parent' ||
	 $first_row[3] ne 'cross_trial' ||
	 $first_row[4] ne 'cross_location' ||
	 $first_row[5] ne 'number_of_progeny' ||
	 $first_row[6] ne 'prefix' ||
	 $first_row[7] ne 'suffix' ||
	 $first_row[8] ne 'number_of_flowers') {
       $error = "Header line is incorrect";
       print STDERR "header is incorrect\n";
     }
     else {
       my $line_number = 0;
       foreach my $line (@contents) {
	 $line_number++;
	 my @row = split /\t/, $line;
	 if (scalar(@row) < 5) {
	   $errors{$line_number} = "Line $line_number has too few columns";
	 }
	 elsif (!$row[0] || !$row[1] || !$row[2] || !$row[3] || !$row[4]) {
	   $errors{$line_number} = "Line $line_number is missing a required field";
	 }
	 else {
	   my %cross;
	   $cross{'cross_name'} = $row[0];
	   $cross{'maternal_parent'} = $row[1];
	   $cross{'paternal_parent'} = $row[2];
	   $cross{'cross_trial'} = $row[3];
	   $cross{'cross_location'} = $row[4];
	   if ($row[5]) {$cross{'number_of_progeny'} = $row[5];}
	   if ($row[6]) {$cross{'prefix'} = $row[6];}
	   if ($row[7]) {$cross{'suffix'} = $row[7];}
	   if ($row[8]) {$cross{'number_of_flowers'} = $row[8];}
	   _verify_cross(%cross, \%errors);
	   #if ($verification
	 }
       }
     }



     $c->stash(
	       tempfile => $tempfile,
	       template => '/breeders_toolbox/upload_crosses_confirm_spreadsheet.mas',
	      );
   } elsif ($format_type eq "barcode") {
     $c->stash(
	       tempfile => $tempfile,
	       template => '/breeders_toolbox/upload_crosses_confirm_barcode.mas',
	      );
   }
   else {
     print STDERR "Upload file format type $format_type not recognized\n";
   }
}

sub _verify_cross {
  #my $self = shift;
  my %cross = shift;
  my $error_ref = shift;
  my %verify_errors = %$error_ref;
  print STDERR "name: ".$cross{'cross_name'}."\n";
}

1;
