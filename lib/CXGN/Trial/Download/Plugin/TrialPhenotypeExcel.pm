
package CXGN::Trial::Download::Plugin::TrialPhenotypeExcel;

use Moose::Role;

use Spreadsheet::WriteExcel;
use CXGN::BreederSearch;
use CXGN::Trial;

sub verify {
    1;
}

sub download {
    my $self = shift;

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my $trait_list = $self->trait_list();
    my @trait_contains = split /,/, $self->trait_contains();
    my $data_level = $self->data_level();
    my $include_timestamp = $self->include_timestamp();
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    my $trait_list_search;
    my $counter = 0;
    foreach (@$trait_list) {
        $trait_list_search .= $_;
        $counter++;
        if ($counter ne scalar(@$trait_list)) {
            $trait_list_search .= ',';
        }
    }
    $self->trial_download_log($trial_id, "trial phenotypes");

    my $trial_sql = "\'$trial_id\'";
    my $bs = CXGN::BreederSearch->new( { dbh => $schema->storage->dbh(), bcs_schema=>$schema });
    my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, $trait_list_search, $include_timestamp, \@trait_contains, $data_level);

    #my $rs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id })->search_related('nd_experiment_projects')->search_related('nd_experiment')->search_related('nd_geolocation');

    #my $location = $rs->first()->get_column('description');

    #my $bprs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id})->search_related_rs('project_relationship_subject_projects');

    #print STDERR "COUNT: ".$bprs->count()."  ". $bprs->get_column('project_relationship.object_project_id')."\n";

    #my $pbr = $schema->resultset("Project::Project")->search( { 'me.project_id'=> $bprs->get_column('project_relationship_subject_projects.object_project_id')->first() } );

    #my $program_name = $pbr->first()->name();
    #my $year = $trial->get_year();

    #print STDERR "YEAR: $year\n";

    #print STDERR "PHENOTYPE DATA MATRIX: ".Dumper(\@data);

    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    for (my $line =0; $line< @data; $line++) {
	my @columns = split /\t/, $data[$line];
	for(my $col = 0; $col<@columns; $col++) {
	    $ws->write($line, $col, $columns[$col]);
	}
    }
    #$ws->write(0, 0, "$program_name, $location ($year)");
    $ss ->close();
}

1;
