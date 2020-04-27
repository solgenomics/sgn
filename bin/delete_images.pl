
=head1 NAME

delete_images.pl - a script to hard delete images from a CXGN database.

=head1 DESCRIPTION

perl delete_images.pl -h <dbhost> -d <dbname> -i <image_dir> file_with_image_ids

=head1 NOTES

Be careful with this script! Ids have to match the given database etc etc

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use File::Slurp qw | slurp |;
use Getopt::Std;

use CXGN::Image;
use CXGN::DB::InsertDBH;

our ($opt_h, $opt_d, $opt_i, $opt_t);

getopts('h:d:i:t');

my $dbh = CXGN::DB::InsertDBH->new( { 
    dbhost => $opt_h,
    dbname => $opt_d,
    });



my $image_id_file = shift;

my @image_ids = slurp($image_id_file);

if ($opt_t) { 
    print STDERR "Note: -t. Test mode. Will rollback after operations are done.\n";
}

my $deleted_image_count = 0;

eval { 
    
    foreach my $id (@image_ids) { 
	my $image = CXGN::Image->new(dbh=>$dbh, image_id=>$id, image_dir=> $opt_i);
	
	print STDERR "Deleting image with id $id... (".$image->get_description().") ";
	
	$image->hard_delete($opt_t);
	print STDERR "Done.\n";
    }

    $deleted_image_count++;
};

if ($opt_t) { 
    print STDERR " -t option (test mode): rolling back...";
    $dbh->rollback();
    print STDERR "Done.\n";
    exit();
}
if ($@) { 
    print STDERR "An unfortunate error occurred... ($@)";
    $dbh->rollback();
}
else { 
    print STDERR "Committing...\n"; 
    $dbh->commit();
}

print STDERR "Deleted $deleted_image_count images. Done.\n";
