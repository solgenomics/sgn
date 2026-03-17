package SGN::Controller::AJAX::GenotypingProject;

use Moose;
use JSON;
use Data::Dumper;
use CXGN::Login;
use CXGN::Job;
use List::MoreUtils qw /any /;

use CXGN::Genotype::StoreGenotypingProject;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub genotyping_project_delete : Path('/ajax/genotyping_project/delete') : ActionClass('REST') { }

sub genotyping_project_delete_POST : Args(1) {
    my ($self, $c, $project_id) = @_;

    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_role;
    my $user_name;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]) {
	    print STDERR "error - no user_info\n";
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
            return;
        }

        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
	print STDERR "found user name $user_name\n";
    } else {
	print STDERR "error - no session_id\n";
        if (!$c->user()) {
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
            return;
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to delete genotypes! Please contact us.' };
        $c->detach();
    }

    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $basepath = $c->config->{basepath};
    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};

    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

    my $q = "SELECT nd_experiment_id, genotype_id
        FROM genotype
        JOIN nd_experiment_genotype USING(genotype_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        WHERE project_id = ? AND nd_experiment.type_id = ?;";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($project_id, $geno_cvterm_id);

    my $count = 0;
    my %genotype_ids_and_nd_experiment_ids_to_delete;
    while (my ($nd_experiment_id, $genotype_id) = $h->fetchrow_array()) {
        push @{$genotype_ids_and_nd_experiment_ids_to_delete{genotype_ids}}, $genotype_id;
        push @{$genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}}, $nd_experiment_id;
	$count++;
    }
    print STDERR "$count genotypes to be deleted for project $project_id\n";

    # Cascade will delete from genotypeprop
    if ($genotype_ids_and_nd_experiment_ids_to_delete{genotype_ids}->[0]) {
        my $genotype_id_sql = join (",", @{$genotype_ids_and_nd_experiment_ids_to_delete{genotype_ids}});

	#my $del_geno_q = "DELETE from genotype WHERE genotype_id IN ($genotype_id_sql);";
	my $dbh = $bcs_schema->storage->dbh;
	my $del_geno_q = "DELETE from genotype USING nd_experiment_genotype, nd_experiment, nd_experiment_project
	                  WHERE genotype.genotype_id = nd_experiment_genotype.genotype_id
			  AND nd_experiment_genotype.nd_experiment_id = nd_experiment.nd_experiment_id
			  AND nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id
			  AND nd_experiment.type_id = ?
			  AND nd_experiment_project.project_id = ?";
	my $deleted_rows = $dbh->do($del_geno_q, undef, $geno_cvterm_id, $project_id);
	print STDERR "deleted $deleted_rows genotypes for project $project_id\n";
    }

    # delete project
    #my $del_geno_proj_q = "DELETE from project WHERE project_id=?";
    #my $h_del_geno_prot = $bcs_schema->storage->dbh()->prepare($del_geno_proj_q);
    #$h_del_geno_proj->execute($project_id);
    
    # Delete nd_experiment_md_files entries linking genotypes to archived genotyping upload file
    # e.g. original VCF

    if ($genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}->[0]) {
        # Delete from nd_experiment asynchronously because it takes long
        my $dir = $c->tempfiles_subdir('/genotype_data_delete_nd_experiment_ids');
        my $temp_file_nd_experiment_id = "$basepath/".$c->tempfile( TEMPLATE => 'genotype_data_delete_nd_experiment_ids/fileXXXX');
        open (my $fh, "> :encoding(UTF-8)", $temp_file_nd_experiment_id ) or do {
	    $c->stash->{rest} = { error => "Could not open temp file $temp_file_nd_experiment_id: $!" };
	    return;
	};
        foreach (@{$genotype_ids_and_nd_experiment_ids_to_delete{nd_experiment_ids}}) {
            print $fh "$_\n";
        }
        close($fh);
        # my $async_delete = CXGN::Tools::Run->new();
	    # $async_delete->run_async("perl $basepath/bin/delete_nd_experiment_entries.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -i $temp_file_nd_experiment_id");
        my $cmd = "perl $basepath/bin/delete_nd_experiment_entries.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -i $temp_file_nd_experiment_id";
        my $async_delete = CXGN::Job->new({
            people_schema => $c->dbic_schema('CXGN::People::Schema', undef, $user_id),
            schema => $bcs_schema,
            sp_person_id => $user_id,
            cmd => $cmd,
            finish_logfile => $c->config->{job_finish_log},
            name => "genotyping project deletion",
            job_type => 'deletion',
            submit_page => ($c->req->referer ? $c->req->referer->as_string : undef)
        });
        eval {
            $async_delete->submit();
        };
        if ($@) {
            $c->stash->{rest} = {error => "Failed to submit background job: $@"};
            return;
        }
    }
    # Rebuild and refresh the materialized_markerview table
    my $async_refresh = CXGN::Tools::Run->new();
    $async_refresh->run_async("perl $basepath/bin/refresh_materialized_markerview.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass");

    $c->stash->{rest} = { success => 1 };
}

sub add_genotyping_project : Path('/ajax/breeders/add_genotyping_project') : ActionClass('REST') {}

sub add_genotyping_project_POST :Args(0){
    my ($self, $c) = @_;

    my $dbh = $c->dbc->dbh;
    my $project_name = $c->req->param('project_name');
    my $project_breeding_program = $c->req->param('project_breeding_program');
    my $project_facility = $c->req->param('project_facility');
    my $project_year = $c->req->param('project_year');
    my $project_description = $c->req->param('project_description');
    my $project_location = $c->req->param('project_location');
    my $data_type = $c->req->param('data_type');

    if (!$c->user()){
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        print STDERR "User does not have sufficient privileges.\n";
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a genotyping project." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);

    my $error;
    eval{
        my $add_genotyping_project = CXGN::Genotype::StoreGenotypingProject->new({
            chado_schema => $schema,
            dbh => $dbh,
            project_name => $project_name,
            breeding_program_id => $project_breeding_program,
            project_facility => $project_facility,
            data_type => $data_type,
            year => $project_year,
            project_description => $project_description,
            nd_geolocation_id => $project_location,
            owner_id => $user_id
        });
        my $store_return = $add_genotyping_project->store_genotyping_project();
        if ($store_return->{error}){
            $error = $store_return->{error};
        }
    };

    if ($@) {
        $c->stash->{rest} = {error => $@};
        return;
    };

    if ($error){
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {success => 1};
    }

}


1;
