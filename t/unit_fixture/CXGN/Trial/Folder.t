
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use Data::Dumper;
use CXGN::Trial::Folder;

my $f = SGN::Test::Fixture->new();

my $folder1 = CXGN::Trial::Folder->create( { bcs_schema => $f->bcs_schema(), name=>"test_folder", description => "test_description" });

my $folder2 = CXGN::Trial::Folder->create( { bcs_schema => $f->bcs_schema(), name=>"test_folder_parent", description => "test_parent_description" });

$folder1->associate_parent($folder2->folder_id());

my $children = $folder2->children();

is($children->[0]->name(), "test_folder", "child folder test");

foreach my $child (@$children) { 
    print STDERR "CHILD FOLDER: ".$child->name()."\n";
}

my $parent = $folder1->parent();

my $parent_name = "";
if ($parent) { 
    $parent_name = $parent->name();
}
is($parent_name, "test_folder_parent", "parent folder test");

done_testing();



