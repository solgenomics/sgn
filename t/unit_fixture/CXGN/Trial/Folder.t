
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use Data::Dumper;
use CXGN::Trial::Folder;

my $f = SGN::Test::Fixture->new();

#print STDERR Dumper($f->bcs_schema());

print STDERR "Creating folder 1...\n";
my $folder1_row = CXGN::Trial::Folder->create( { bcs_schema => $f->bcs_schema(), name=>"test_folder", description => "test_description" });

print STDERR "Folder 1 id = ".$folder1_row->project_id()."\n";

print STDERR "Creating folder 2...\n";
my $folder2_row = CXGN::Trial::Folder->create( { bcs_schema => $f->bcs_schema(), name=>"test_folder2", description => "test2_description" });

print STDERR "Folder 2 id = ".$folder2_row->project_id()."\n";

print STDERR "Instantiating folder 1...\n";
my $folder1 = CXGN::Trial::Folder->new( { bcs_schema => $f->bcs_schema(), folder_id => $folder1_row->project_id() } );

$folder1->associate_parent($folder2_row->project_id());

print STDERR "Instantiating folder 2...\n";
my $folder2 = CXGN::Trial::Folder->new( { bcs_schema => $f->bcs_schema(), folder_id => $folder2_row->project_id() } );

my $children = $folder2->children();

print STDERR Dumper($children);
is($children->[0]->[1], "test_folder", "child folder test");

my $parent = $folder1->get_parent();

is($parent->[1], "test_folder2", "parent folder test");

done_testing();



