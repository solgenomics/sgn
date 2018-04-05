
package SGN::Controller::AJAX::Trials;

use Moose;

use CXGN::BreedersToolbox::Projects;
use CXGN::Trial::Folder;
use CXGN::Trial;
use Data::Dumper;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub get_trials : Path('/ajax/breeders/get_trials') Args(0) {
    my $self = shift;
    my $c = shift;

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );

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

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema  } );

    my $projects = $p->get_breeding_programs();

    my $html = "";
    my $folder_obj = CXGN::Trial::Folder->new( { bcs_schema => $schema, folder_id => @$projects[0]->[0] });

    print STDERR "Starting get trials $tree_type at time ".localtime()."\n";
    foreach my $project (@$projects) {
        my %project = ( "id" => $project->[0], "name" => $project->[1]);
        $html .= $folder_obj->get_jstree_html(\%project, $schema, 'breeding_program', $tree_type);
    }
    print STDERR "Finished get trials $tree_type at time ".localtime()."\n";

    my $dir = catdir($c->site_cluster_shared_dir, "folder");
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }
    my $filename = $dir."/entire_jstree_html_$tree_type.txt";

    my $OUTFILE;
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } $html or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    $c->stash->{rest} = { status => 1 };
}

sub get_trials_with_folders_cached : Path('/ajax/breeders/get_trials_with_folders_cached') Args(0) {
    my $self = shift;
    my $c = shift;
    my $tree_type = $c->req->param('type') || 'trial'; #can be 'trial' or 'genotyping_trial', 'cross'

    my $dir = catdir($c->site_cluster_shared_dir, "folder");
    my $filename = $dir."/entire_jstree_html_$tree_type.txt";
    my $html = '';
    open(my $fh, '<', $filename) or die "cannot open file $filename";
    {
        local $/;
        $html = <$fh>;
    }
    close($fh);

    #print STDERR $html;
    $c->stash->{rest} = { html => $html };
}

sub get_shared_traits : Path('/ajax/breeders/get_shared_traits') Args(0) {
    my $self = shift;
    my $c = shift;
    my @trial_ids = $c->req->param('trial_ids[]');
    my @placeholders;

    print STDERR "Trial ids sfsadff are @trial_ids\n";

    foreach my $trial_id (@trial_ids) {
        push @placeholders, $trial_id;
        push @placeholders, '^[0-9]+([,.][0-9]+)?$';
    }

    print STDERR "Trial ids after adding  are @placeholders\n";

    my @parts;
    foreach my $trial_id (@trial_ids) {
	      push @parts, "SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait, cvterm.cvterm_id, count(phenotype.value) FROM cvterm JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? and phenotype.value~? GROUP BY trait, cvterm.cvterm_id";
    }
    my $query = join (" INTERSECT ", @parts);
    $query = $query . ' ORDER BY trait';

    print STDERR "Query is: $query\n";

    my $dbh = $c->dbic_schema("Bio::Chado::Schema")->storage()->dbh();
    my $traits_assayed_q = $dbh->prepare($query);
    $traits_assayed_q->execute(@placeholders);

    my @traits_assayed;
    while (my ($trait_name, $trait_id, $count) = $traits_assayed_q->fetchrow_array()) {
        push @traits_assayed, [$trait_id, $trait_name];
    }

    print STDERR "traits assayed are: @traits_assayed\n";

    # my @shared_traits;
    #
    # foreach my $trial_id (@trial_ids) {
    #     my %seen;
    #     my $new_traits = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema") , trial_id => $trial_id } )->get_traits_assayed();
    #     @shared_traits = grep( !$seen{$_}++, @shared_traits, @$new_traits)
    # }

    $c->stash->{rest} = { traits => \@traits_assayed };
}

sub trial_autocomplete : Local : ActionClass('REST') { }

sub trial_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    print STDERR "Term: $term\n";
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my $trial_design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), "design", "project_property")->cvterm_id();
    my @response_list;
    my $q = "select distinct(name) from project join projectprop using(project_id) where project.name ilike ? and projectprop.type_id = ? ORDER BY name";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%', $trial_design_cvterm_id);
    while (my ($project_name) = $sth->fetchrow_array) {
        push @response_list, $project_name;
    }
    #print STDERR Dumper \@response_list;

    print STDERR "Returning...\n";
    $c->stash->{rest} = \@response_list;
}
