
use strict;
use Data::Dumper;
use File::Temp;
use Test::More qw | no_plan |;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Image;
use JSON;


my $f = SGN::Test::Fixture->new();

my $dbh = $f->dbh();

my $tempdir = File::Temp->newdir();
my $imagedir = $tempdir."/".$f->get_conf('image_dir');

#EXIF data function tests
my $i = CXGN::Image->new(dbh => $dbh, image_dir => $imagedir);

my $image_id = $i->process_image('t/data/images/fieldbook/test_image_for_exif.jpg');


my $n = CXGN::Image->new(dbh => $dbh, image_dir => $imagedir, image_id => $image_id);

my $exif_info = $n->extract_exif_info();
ok(ref($exif_info) eq 'HASH', 'extract_exif_info returns a hashref');

my $user_comment = $n->extract_exif_info_user_comment();
ok(defined $user_comment, 'extract_exif_user_comment returns defined UserComment');

my $original_file = $n->get_filename("original");

my $class_comment = CXGN::Image->extract_exif_info_class($original_file);
ok(defined $class_comment, 'extract_exif_info_class returns UserComment');

my $decoded_comment = decode_json($class_comment);
ok(!$@, 'extract_exif_info_class returns valid JSON');

my $expected_comment = {
    study => {
        study_db_id              => "742",
        study_name               => "TestCitrus",
        study_alias              => "TestCitrus",
        study_unique_id_name     => "ObservationUnitDbId",
        study_primary_id_name    => "",
        study_secondary_id_name  => "",
        common_crop_name         => "Cassava",
        study_sort_name          => "",
        date_import              => "2025-05-14 10:45:29.387-04:00",
        study_source             => "inventory-test.breedbase.org",
        observation_levels       => "plot",
        trial_name               => "Test-App",
        count                    => 82,
        import_format            => "brapi"
    },
    observation_unit => {
        observation_unit_db_id => "49195",
        geo_coordinates        => ""
    },
    observation_variable => {
        observation_variable_name              => "Test Image|Timepoint 1|image|COMP:0000034",
        observation_variable_field_book_format => "photo",
        default_value                          => "",
        external_db_id                         => "80894",
        trait_data_source                      => "inventory-test.breedbase.org"
    },
    rotation => {
        pitch => 271.0342,
        roll  => 164.2001,
        yaw   => 70.71951
    },
    collector => " ",
    timestamp => "2025-05-14 10_45_44.104-04_00"
};

is_deeply($decoded_comment, $expected_comment, 'EXIF UserComment JSON matches expected structure');

$f->clean_up_db();
done_testing();





