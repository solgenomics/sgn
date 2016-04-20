
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

#check if folder is in breeding program 'test'
my $F1_bp = $folder->breeding_program->name;
ok($F1_bp eq 'test', "folder in right breeding program");

#check if folder has no parent, except for the breeding program
my $F1_pf = $folder->project_parent;
ok(!$F1_pf, "folder has no parent folder");

done_testing();
