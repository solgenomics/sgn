
use strict;
use Data::Dumper;
use File::Temp;
use Test::More qw | no_plan |;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Image;


my $f = SGN::Test::Fixture->new();

my $dbh = $f->dbh();

my $tempdir = File::Temp->newdir();
my $imagedir = $tempdir."/".$f->get_conf('image_dir');

my $i = CXGN::Image->new(dbh => $dbh, image_dir => $imagedir);

my $image_id = $i->process_image('t/data/images/fieldbook/test_image_for_exif.jpg');


my $n = CXGN::Image->new(dbh => $dbh, image_dir => $imagedir, image_id => $image_id);

print STDERR "EXIF INFO: ". Dumper($n->extract_exif_info());

print STDERR "USER COMMENT: ".Dumper($n->extract_exif_info_user_comment());

$f->clean_up_db();
done_testing();





