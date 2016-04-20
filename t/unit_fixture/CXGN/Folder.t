
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;

use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::Folder;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

#create folder with no parent folder
my $test_breeding_program = $schema->resultset("Project::Project")->find( { name => 'test' });
my $folder = CXGN::Trial::Folder->create({
  bcs_schema => $schema,
  parent_folder_id => 0,
  name => 'F1',
  breeding_program_id => $test_breeding_program->project_id(),
});

my $F1_id = $folder->folder_id;
ok($F1_id, "created folder has id");

my $F1_name = $folder->name;
ok($F1_name eq 'F1', "created folder name is right");

my $F1_type = $folder->folder_type;
ok($F1_type eq 'folder', "created folder type is right");

my $F1_is_folder = $folder->is_folder;
ok($F1_is_folder == 1, "created folder is_folder");

my $F1_children = $folder->children;
ok(scalar(@$F1_children) == 0, "created folder has no children");

my $F1_bp = $folder->breeding_program->name;
ok($F1_bp eq 'test', "created folder in right breeding program");

my $F1_pf = $folder->project_parent;
ok(!$F1_pf, "created folder has no parent folder");


#confirm build
my $folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $F1_id
});

my $F1_folder_id = $folder->folder_id;
ok($F1_id == $F1_folder_id, "built folder has id");

$F1_name = $folder->name;
ok($F1_name eq 'F1', "built folder name is right");

$F1_type = $folder->folder_type;
ok($F1_type eq 'folder', "built folder type is right");

$F1_is_folder = $folder->is_folder;
ok($F1_is_folder == 1, "built folder is_folder");

$F1_children = $folder->children;
ok(scalar(@$F1_children) == 0, "built folder has no children");

$F1_bp = $folder->breeding_program->name;
ok($F1_bp eq 'test', "built folder in right breeding program");

$F1_pf = $folder->project_parent->name;
ok($F1_pf eq 'test', "built folder has no parent folder, except for the breeding program");


#create another folder. this folder will be used as a parent folder to the previous folder
my $parent_folder = CXGN::Trial::Folder->create({
  bcs_schema => $schema,
  parent_folder_id => 0,
  name => 'F2',
  breeding_program_id => $test_breeding_program->project_id(),
});

$parent_folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $parent_folder->folder_id(),
});

$folder->associate_parent($parent_folder->folder_id());

$F1_bp = $folder->breeding_program->name;
ok($F1_bp eq 'test', "folder in right breeding program");

$F1_pf = $folder->project_parent->name;
ok($F1_pf eq 'F2', "folder has parent folder");


#confirm folder build for a trial
my $test_trial = $schema->resultset("Project::Project")->find( { name => 'test_trial' });
my $trial_folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $test_trial->project_id()
});

my $trial_folder_id = $trial_folder->folder_id;
ok($trial_folder_id == $test_trial->project_id(), "built trial folder has id");

my $trial_folder_name = $trial_folder->name;
ok($trial_folder_name eq 'test_trial', "built trial folder name is right");

my $trial_folder_type = $trial_folder->folder_type;
ok($trial_folder_type eq 'trial', "built trial folder type is right");

my $trial_folder_is_folder = $trial_folder->is_folder;
ok(!$trial_folder_is_folder, "built trial folder not is_folder");

my $trial_folder_children = $trial_folder->children;
ok(scalar(@$trial_folder_children) == 0, "built trial folder has no children");

my $trial_folder_bp = $trial_folder->breeding_program->name;
ok($trial_folder_bp eq 'test', "built trial folder in right breeding program");

my $trial_folder_pf = $trial_folder->project_parent->name;
ok($trial_folder_pf eq 'test', "built trial folder has parent folder");


#place test_trial into folder F2
$trial_folder->associate_parent($parent_folder->folder_id());

$trial_folder_bp = $trial_folder->breeding_program->name;
ok($trial_folder_bp eq 'test', "trial folder in right breeding program");

$trial_folder_pf = $trial_folder->project_parent->name;
ok($trial_folder_pf eq 'F2', "trial folder has parent folder");

$parent_folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $parent_folder->folder_id(),
});

my $folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $F1_id
});

my $parent_folder_children = $parent_folder->children();
ok(scalar(@$parent_folder_children) == 2, "folder has 2 children");
ok(@$parent_folder_children[0]->name eq 'F1', "folder has child named 'F1'");
ok(@$parent_folder_children[1]->name eq 'test_trial', "folder has child named 'test_trial'");

my $folder_children = $folder->children();
ok(scalar(@$folder_children) == 0, "folder still has no children");


#move test_trial from folder F2 to F1
$trial_folder->associate_parent($folder->folder_id());

my $trial_folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $test_trial->project_id()
});

$trial_folder_bp = $trial_folder->breeding_program->name;
ok($trial_folder_bp eq 'test', "trial folder in right breeding program");

$trial_folder_pf = $trial_folder->project_parent->name;
ok($trial_folder_pf eq 'F1', "trial folder has parent folder");

$parent_folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $parent_folder->folder_id(),
});

my $folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $F1_id
});

my $parent_folder_children = $parent_folder->children();
ok(scalar(@$parent_folder_children) == 1, "folder has 1 child");
ok(@$parent_folder_children[0]->name eq 'F1', "folder has child named 'F1'");

my $folder_children = $folder->children();
ok(scalar(@$folder_children) == 1, "folder has 1 child");
ok(@$folder_children[0]->name eq 'test_trial', "folder has child named 'test_trial'");


#move test_trial to no folder
$trial_folder->associate_parent(0);

my $trial_folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $test_trial->project_id()
});

$trial_folder_bp = $trial_folder->breeding_program->name;
ok($trial_folder_bp eq 'test', "trial folder in right breeding program");

$trial_folder_pf = $trial_folder->project_parent->name;
ok($trial_folder_pf eq 'test', "trial folder has no parent folder, except for the breeding program");

$parent_folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $parent_folder->folder_id(),
});

my $folder = CXGN::Trial::Folder->new({
  bcs_schema => $schema,
  folder_id => $F1_id
});

my $parent_folder_children = $parent_folder->children();
ok(scalar(@$parent_folder_children) == 1, "folder has 1 child");
ok(@$parent_folder_children[0]->name eq 'F1', "folder has child named 'F1'");

my $folder_children = $folder->children();
ok(scalar(@$folder_children) == 0, "folder has no child");




done_testing();
