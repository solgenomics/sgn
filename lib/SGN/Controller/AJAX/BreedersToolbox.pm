
package SGN::Controller::AJAX::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';
use Data::Dumper;
use File::Slurp "read_file";

use CXGN::List;
use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Delete;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Stock::StockLookup;
use CXGN::Location;
use Try::Tiny;
use CXGN::Tools::Run;
use CXGN::Dataset;
use CXGN::Dataset::File;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

sub get_breeding_programs : Path('/ajax/breeders/all_programs') Args(0) {
    my $self = shift;
    my $c = shift;

    my $po = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $breeding_programs = $po->get_breeding_programs();

    $c->stash->{rest} = $breeding_programs;
}

sub new_breeding_program :Path('/breeders/program/new') Args(0) {
    my $self = shift;
    my $c = shift;
    my $name = $c->req->param("name");
    my $desc = $c->req->param("desc");

    if (!($c->user() || $c->user()->check_roles('submitter'))) {
	$c->stash->{rest} = { error => 'You need to be logged in and have sufficient privileges to add a breeding program.' };
    }

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $new_program = $p->new_breeding_program($name, $desc);

    print STDERR "New program is ".Dumper($new_program)."\n";

    $c->stash->{rest} = $new_program;

    # if ($new_program->{'error'}) {
	# $c->stash->{rest} = { error => $error };
    # }
    # else {
	# $c->stash->{rest} =  { success => "The new breeding program $name was created.", id => };
    # }
}

sub delete_breeding_program :Path('/breeders/program/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $program_id = shift;

    if ($c->user && ($c->user->check_roles("curator"))) {
	my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });
	$p->delete_breeding_program($program_id);
	$c->stash->{rest} = [ 1 ];
    }
    else {
	$c->stash->{rest} = { error => "You don't have sufficient privileges to delete breeding programs." };
    }
}


sub get_breeding_programs_by_trial :Path('/breeders/programs_by_trial/') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );

    my $projects = $p->get_breeding_programs_by_trial($trial_id);

    $c->stash->{rest} =   { projects => $projects };

}

sub add_data_agreement :Path('/breeders/trial/add/data_agreement') Args(0) {
    my $self = shift;
    my $c = shift;

    my $project_id = $c->req->param('project_id');
    my $data_agreement = $c->req->param('text');

    if (!$c->user()) {
	$c->stash->{rest} = { error => 'You need to be logged in to add a data agreement' };
	return;
    }

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
	$c->stash->{rest} = { error => 'You do not have the required privileges to add a data agreement to this trial.' };
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $data_agreement_cvterm_id_rs = $schema->resultset('Cv::Cvterm')->search( { name => 'data_agreement' });

    my $type_id;
    if ($data_agreement_cvterm_id_rs->count>0) {
	$type_id = $data_agreement_cvterm_id_rs->first()->cvterm_id();
    }

    eval {
	my $project_rs = $schema->resultset('Project::Project')->search(
	    { project_id => $project_id }
	    );

	if ($project_rs->count() == 0) {
	    $c->stash->{rest} = { error => "No such project $project_id", };
	    return;
	}

	my $project = $project_rs->first();

	my $projectprop_rs = $schema->resultset("Project::Projectprop")->search( { 'project_id' => $project_id, 'type_id'=>$type_id });

	my $projectprop;
	if ($projectprop_rs->count() > 0) {
	    $projectprop = $projectprop_rs->first();
	    $projectprop->value($data_agreement);
	    $projectprop->update();
	    $c->stash->{rest} = { message => 'Updated data agreement.' };
	}
	else {
	    $projectprop = $project->create_projectprops( { 'data_agreement' => $data_agreement,}, {autocreate=>1});
	    $c->stash->{rest} = { message => 'Inserted new data agreement.'};
	}
    };
    if ($@) {
	$c->stash->{rest} = { error => $@ };
	return;
    }
}

sub get_data_agreement :Path('/breeders/trial/data_agreement/get') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $project_id = $c->req->param('project_id');

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $data_agreement_cvterm_id_rs = $schema->resultset('Cv::Cvterm')->search( { name => 'data_agreement' });

    if ($data_agreement_cvterm_id_rs->count() == 0) {
	$c->stash->{rest} = { error => "No data agreements have been added yet." };
	return;
    }

    my $type_id = $data_agreement_cvterm_id_rs->first()->cvterm_id();

    print STDERR "PROJECTID: $project_id TYPE_ID: $type_id\n";

    my $projectprop_rs = $schema->resultset('Project::Projectprop')->search(
	{ project_id => $project_id, type_id=>$type_id }
	);

    if ($projectprop_rs->count() == 0) {
	$c->stash->{rest} = { error => "No such project $project_id", };
	return;
    }
    my $projectprop = $projectprop_rs->first();
    $c->stash->{rest} = { prop_id => $projectprop->projectprop_id(), text => $projectprop->value() };

}

sub get_all_years : Path('/ajax/breeders/trial/all_years' ) Args(0) {
    my $self = shift;
    my $c = shift;

    my $bp = CXGN::BreedersToolbox::Projects->new({ schema => $c->dbic_schema("Bio::Chado::Schema") });
    my @years = $bp->get_all_years();

    $c->stash->{rest} = { years => \@years };
}

sub get_trial_location : Path('/ajax/breeders/trial/location') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $t = CXGN::Trial->new(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    trial_id => $trial_id
	});

    if ($t) {
	$c->stash->{rest} = { location => $t->get_location() };
    }
    else {
	$c->stash->{rest} = { error => "The trial with id $trial_id does not exist" };

    }
}

sub get_trial_type : Path('/ajax/breeders/trial/type') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $t = CXGN::Trial->new(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    trial_id => $trial_id
	});

    my $type = $t->get_project_type();
    $c->stash->{rest} = { type => $type };
}

sub get_all_trial_types : Path('/ajax/breeders/trial/alltypes') Args(0) {
    my $self = shift;
    my $c = shift;

    my @types = CXGN::Trial::get_all_project_types($c->dbic_schema("Bio::Chado::Schema"));

    $c->stash->{rest} = { types => \@types };
}


sub get_accession_plots :Path('/ajax/breeders/get_accession_plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $field_trial = $c->req->param("field_trial");
    my $parent_accession = $c->req->param("parent_accession");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $field_layout_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "field_layout", "experiment_type")->cvterm_id();
    my $dbh = $schema->storage->dbh();

    my $trial = $schema->resultset("Project::Project")->find ({name => $field_trial});
    my $trial_id = $trial->project_id();

    my $cross_accession = $schema->resultset("Stock::Stock")->find ({uniquename => $parent_accession});
    my $cross_accession_id = $cross_accession->stock_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
            FROM nd_experiment_project join nd_experiment on (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id) AND nd_experiment.type_id= ?
            JOIN nd_experiment_stock ON (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
            JOIN stock_relationship on (nd_experiment_stock.stock_id = stock_relationship.subject_id) AND stock_relationship.object_id = ?
            JOIN stock on (stock_relationship.subject_id = stock.stock_id)
            WHERE nd_experiment_project.project_id= ? ";

    my $h = $dbh->prepare($q);
    $h->execute($field_layout_typeid, $cross_accession_id, $trial_id, );

    my @plots=();
    while(my ($plot_id, $plot_name) = $h->fetchrow_array()){

      push @plots, [$plot_id, $plot_name];
    }
    #print STDERR Dumper \@plots;
    $c->stash->{rest} = {data=>\@plots};

}

sub delete_uploaded_phenotype_files : Path('/ajax/breeders/phenotyping/delete/') Args(1) {
    my $self = shift;
    my $c = shift;
    my $file_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    print STDERR "Deleting phenotypes from File ID: $file_id and making file obsolete\n";
    my $dbh = $c->dbc->dbh();
    my $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

    my $q_search = "
        SELECT phenotype_id, nd_experiment_id, file_id
        FROM phenotype
        JOIN nd_experiment_phenotype using(phenotype_id)
        JOIN nd_experiment_stock using(nd_experiment_id)
        JOIN nd_experiment using(nd_experiment_id)
        LEFT JOIN phenome.nd_experiment_md_files using(nd_experiment_id)
        JOIN stock using(stock_id)
        WHERE file_id = ?
        AND nd_experiment.type_id = $nd_experiment_type_id";

    my $h = $dbh->prepare($q_search);
    $h->execute($file_id);

    my %phenotype_ids_and_nd_experiment_ids_to_delete;
    my $count = 0;
    while (my ($phenotype_id, $nd_experiment_id, $file_id) = $h->fetchrow_array()) {
        push @{$phenotype_ids_and_nd_experiment_ids_to_delete{phenotype_ids}}, $phenotype_id;
        push @{$phenotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}}, $nd_experiment_id;
        $count++;
    }

    if ( $count > 0 ) {
        my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');
        my $delete_phenotype_values_error = CXGN::Project::delete_phenotype_values_and_nd_experiment_md_values($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, $temp_file_nd_experiment_id, $c->config->{basepath}, $schema, \%phenotype_ids_and_nd_experiment_ids_to_delete);
        if ($delete_phenotype_values_error) {
            die "Error deleting phenotype values ".$delete_phenotype_values_error."\n";
        }
    }

    my $h4 = $dbh->prepare("UPDATE metadata.md_metadata SET obsolete = 1 where metadata_id IN (SELECT metadata_id from metadata.md_files where file_id=?);");
    $h4->execute($file_id);
    print STDERR "Phenotype file successfully made obsolete (AKA deleted).\n";

    my $async_refresh = CXGN::Tools::Run->new();
    $async_refresh->run_async("perl " . $c->config->{basepath} . "/bin/refresh_matviews.pl -H " . $c->config->{dbhost} . " -D " . $c->config->{dbname} . " -U " . $c->config->{dbuser} . " -P " . $c->config->{dbpass} . " -m fullview -c");

    $c->stash->{rest} = {success => 1};
}

sub progress : Path('/ajax/progress') Args(0) {
    my $self = shift;
    my $c = shift;

    my $trait_id = $c->req->param("trait_id");

    print STDERR "Trait id = $trait_id\n";
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    my $q = "select projectprop.value, avg(phenotype.value::REAL), stddev(phenotype.value::REAL),count(*) from phenotype join cvterm on(cvalue_id=cvterm_id) join nd_experiment_phenotype using(phenotype_id) join nd_experiment_project using(nd_experiment_id) join projectprop using(project_id)  where cvterm.cvterm_id=? and phenotype.value not in ('-', 'miss','#VALUE!','..') and projectprop.type_id=(SELECT cvterm_id FROM cvterm where name='project year') group by projectprop.type_id, projectprop.value order by projectprop.value";

    my $h = $dbh->prepare($q);

    $h->execute($trait_id);
    
    my $data = [];

    while (my ($year, $mean, $stddev, $count) = $h->fetchrow_array()) {
	push @$data, [ $year, sprintf("%.2f", $mean), sprintf("%.2f", $stddev), $count ];
    }

    print STDERR "Data = ".Dumper($data);
    
    $c->stash->{rest} = { data => $data };
}


sub radarGraph : Path('/ajax/radargraph') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $dbh = $schema->storage->dbh();

=pod
    my $stock_id = $c->req->param("stock_id");
    my $cvterm_id = $c->req->param("cvterm_id");

    my $q = 'select accessions.uniquename, cvterm.name, cvterm.cvterm_id, accessions.stock_id, avg(phenotype.value::REAL), stddev(phenotype.value::REAL), count(*) 
            from cvterm 
            join phenotype on(cvalue_id=cvterm_id) 
            join nd_experiment_phenotype using(phenotype_id) 
            join nd_experiment_stock using(nd_experiment_id) 
            join stock using(stock_id) 
            join stock_relationship on(subject_id=stock.stock_id) 
            join stock as accessions on(stock_relationship.object_id=accessions.stock_id) 
            where stock.type_id=76393 and accessions.stock_id=? and cvterm.cvterm_id=? and phenotype.value ~ \'^[0-9]+\.?[0-9]*$\' 
            group by accessions.uniquename, cvterm.name, cvterm.cvterm_id, accessions.stock_id;';
    my $h = $dbh->prepare($q);
=cut

    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $trait_list = $ds->retrieve_phenotypes();
    my $ds_name = $ds->name();

    #print STDERR "Dataset Id = $dataset_id\n";
    #print STDERR "Trait List = ".Dumper($trait_list);

    $c->stash->{rest} = {
        data => \@$trait_list, 
        name => $ds_name,
    };


    #print STDERR "Dataset Id = $dataset_id\n";
    #print STDERR "Trait List = ".Dumper($trait_list);


}

1;



