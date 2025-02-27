
package SGN::Controller::AJAX::Trials;

use Moose;

use CXGN::BreedersToolbox::Projects;
use CXGN::Trial::Folder;
use Data::Dumper;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw | read_file |;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub get_trials : Path('/ajax/breeders/get_trials') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id) } );

    my $projects = $p->get_breeding_programs();

    my %data = ();
    foreach my $project (@$projects) {
        my $trials = $p->get_trials_by_breeding_program($project->[0]);
        $data{$project->[1]} = $trials;

    }

    $c->stash->{rest} = \%data;
}

sub get_trials_with_folders : Path('/ajax/breeders/get_trials_with_folders') Args(0) {
    my $self = shift;
    my $c = shift;
    my $tree_type = $c->req->param('type') || 'trial'; #can be 'trial' or 'genotyping_trial', 'cross'
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $dir = catdir($c->config->{static_content_path}, "folder");
    eval { make_path($dir) };
    if ($@) {
        print STDERR "Couldn't create $dir: $@";
    }
    my $filename = $dir."/entire_jstree_html_$tree_type.txt";

    _write_cached_folder_tree($schema, $tree_type, $filename);

    $c->stash->{rest} = { status => 1 };
}

sub get_trials_with_folders_cached : Path('/ajax/breeders/get_trials_with_folders_cached') Args(0) {
    my $self = shift;
    my $c = shift;
    my $tree_type = $c->req->param('type') || 'trial'; #can be 'trial','genotyping_trial', 'cross', 'genotyping_project', 'activity'
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $dir = catdir($c->config->{static_content_path}, "folder");
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }
    my $filename = $dir."/entire_jstree_html_$tree_type.txt";
    my $html = '';
    open(my $fh, '< :encoding(UTF-8)', $filename) or warn "cannot open file $filename $!";
    {
        local $/;
        $html = <$fh>;
    }
    close($fh);

    if (!$html) {
        $html = _write_cached_folder_tree($schema, $tree_type, $filename);
    }

    #print STDERR $html;
    $c->stash->{rest} = { html => $html };
}

sub _write_cached_folder_tree {
    my $schema = shift;
    my $tree_type = shift;
    my $filename = shift;
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema  } );

    my $projects = $p->get_breeding_programs();

    my $html = "";
    my $folder_obj = CXGN::Trial::Folder->new( { bcs_schema => $schema, folder_id => @$projects[0]->[0] });

    print STDERR "Starting trial tree refresh for $tree_type at time ".localtime()."\n";
    foreach my $project (@$projects) {
        my %project = ( "id" => $project->[0], "name" => $project->[1]);
        $html .= $folder_obj->get_jstree_html(\%project, $schema, 'breeding_program', $tree_type);
    }
    print STDERR "Finished trial tree refresh for $tree_type at time ".localtime()."\n";

    my $OUTFILE;
    open $OUTFILE, '> :encoding(UTF-8)', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } $html or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    return $html;
}

sub trial_autocomplete : Local : ActionClass('REST') { }

sub trial_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    print STDERR "Term: $term\n";
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $trial_design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id), "design", "project_property")->cvterm_id();
    my @response_list;
    my $q = "select distinct(name) from project join projectprop using(project_id) where project.name ilike ? and projectprop.type_id = ? and projectprop.value not in ('genotyping_plate', 'genotype_data_project', 'pcr_genotype_data_project') ORDER BY name";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%', $trial_design_cvterm_id);
    while (my ($project_name) = $sth->fetchrow_array) {
        push @response_list, $project_name;
    }

    $c->stash->{rest} = \@response_list;
}


sub trial_lookup : Path('/ajax/breeders/trial_lookup') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_name = $c->req->param('name');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if ( !$trial_name || $trial_name eq '' ) {
        $c->stash->{rest} = {error => "Trial name required"};
        $c->detach();
    }

    # Get trial id by name
    my $trial_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "phenotyping_trial", "project_type")->cvterm_id();
    my $rs = $schema->resultset("Project::Project")->find(
        { 'name' => $trial_name, 'projectprops.type_id' => $trial_type_id },
        { join => 'projectprops' }
    );
    my $trial_id;
    $trial_id = $rs->project_id() if $rs;

    # Trial not found
    if ( !$trial_id || $trial_id eq '' ) {
        $c->stash->{rest} = {error => "Trial not found"};
        $c->detach();
    }

    $c->stash->{rest} = { trial_id => $trial_id };
}


=head2 function get_recent_trials()

  Params: a string indicating the interval - one of 'day', 'week', 'month' or 'year'
  Returns: a list of of recently created trials
     The list contains lists with the following info: link for the trial, 
     the trial type, the breeding program and the creation date.

=cut  

sub get_recent_trials : Path('/ajax/breeders/recent_trials') Args(1) {
    my $self = shift;
    my $c = shift;
    my $interval = shift; # 1 day, week, month, or year
    
    my $trial_table = CXGN::Project::get_recently_added_trials($c->dbic_schema('Bio::Chado::Schema'),  $c->dbic_schema("CXGN::Phenome::Schema"),  $c->dbic_schema("CXGN::People::Schema"), $c->dbic_schema("CXGN::Metadata::Schema"), $interval);

    $c->stash->{rest} =  { data => $trial_table }


}

=head2 function get_recently_modified_trials()

  Params: a string indicating the interval - one of 'day', 'week', 'month' or 'year'
  Returns: a list of of recently modified trials, defined here narrowly as new
     phenotypes that have been uploaded.
     The list contains lists with the following info: link for the trial, 
     the trial type, the breeding program and the last modified date date
     (the create_date of the phenotypes falling in the interval).

=cut  

sub get_recently_modified_trials : Path('/ajax/breeders/recently_modified_trials') Args(1) {
    my $self = shift;
    my $c = shift;
    my $interval = shift;

    my $trial_table = CXGN::Project::get_recently_modified_trials($c->dbic_schema('Bio::Chado::Schema'), $c->dbic_schema("CXGN::Phenome::Schema"), $c->dbic_schema("CXGN::People::Schema"), $c->dbic_schema("CXGN::Metadata::Schema"), $interval);

    $c->stash->{rest} =  { data => $trial_table };
}

=head2 function get_recently_created_accessions()

  Params: interval - one of 'day', 'week', 'month', or 'year'
  Returns: a list of accessions that have been added in that interval.
     
=cut

sub get_recently_created_accessions : Path('/ajax/breeders/recently_added_accessions') Args(1) {
    my $self = shift;
    my $c = shift;
    my $interval = shift;
    
    my $s = CXGN::Stock->new( { schema => $c->dbic_schema('Bio::Chado::Schema') } );

    my $accession_table = CXGN::Project::get_recently_added_accessions($c->dbic_schema('Bio::Chado::Schema'), $interval);

    $c->stash->{rest} =  { data => $accession_table };
}
