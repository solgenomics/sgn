
package CXGN::Trial::Download::Plugin::TrialPhenotypeExcel;

use Moose::Role;

use Spreadsheet::WriteExcel;
use CXGN::BreederSearch;
use CXGN::Trial;
use CXGN::Phenotypes::Search;
use Data::Dumper;

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
    my @trial_list;
    push @trial_list, $trial_id;
    my $accession_list;
    my $plot_list;
    my $plant_list;
    my $phenotype_min_value = $self->phenotype_min_value();
    my $phenotype_max_value = $self->phenotype_max_value();

    $self->trial_download_log($trial_id, "trial phenotypes");

    my $phenotypes_search = CXGN::Phenotypes::Search->new({
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trial_list=>\@trial_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        include_timestamp=>$include_timestamp,
        trait_contains=>\@trait_contains,
        phenotype_min_value=>$phenotype_min_value,
        phenotype_max_value=>$phenotype_max_value
    });
    my @data = $phenotypes_search->get_extended_phenotype_info_matrix();
    #print STDERR Dumper \@data;



    ##my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, $trait_list_search, $include_timestamp, \@trait_contains, $data_level);
#------
    #my $rs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id })->search_related('nd_experiment_projects')->search_related('nd_experiment')->search_related('nd_geolocation');

    #my $location = $rs->first()->get_column('description');

    #my $bprs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id})->search_related_rs('project_relationship_subject_projects');

    #print STDERR "COUNT: ".$bprs->count()."  ". $bprs->get_column('project_relationship.object_project_id')."\n";

    #my $pbr = $schema->resultset("Project::Project")->search( { 'me.project_id'=> $bprs->get_column('project_relationship_subject_projects.object_project_id')->first() } );

    #my $program_name = $pbr->first()->name();
    #my $year = $trial->get_year();

    #print STDERR "YEAR: $year\n";

    #print STDERR "PHENOTYPE DATA MATRIX: ".Dumper(\@data);
#---
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    $ws->write(0, 0, "Date of Download:");
    $ws->write(0, 1, $timestamp);
    $ws->write(1, 0, "Search Parameters:");
    my $trait_list_text = $trait_list ? join ("," , @$trait_list) : '';
    my $trial_list_text = @trial_list ? join ("," , @trial_list) : '';
    my $accession_list_text = $accession_list ? join(",", @$accession_list) : '';
    my $plot_list_text = $plot_list ? join(",", @$plot_list) : '';
    my $plant_list_text = $plant_list ? join(",", @$plant_list) : '';
    my $trait_contains_text = @trait_contains ? join(",", @trait_contains) : '';
    my $min_value_text = $phenotype_min_value ? $phenotype_min_value : '';
    my $max_value_text = $phenotype_max_value ? $phenotype_max_value : '';
    $ws->write(1, 1, "Data Level:$data_level  Trait List:$trait_list_text  Trial List:$trial_list_text  Accession List:$accession_list_text  Plot List:$plot_list_text  Plant List:$plant_list_text  Include Timestamp: $include_timestamp  Trait Contains:$trait_contains_text  Minimum Phenotype: $min_value_text  Maximum Phenotype: $max_value_text");

    for (my $line=0; $line< scalar(@data); $line++) {
        my @columns = split /\t/, $data[$line];
        for(my $col = 0; $col<@columns; $col++) {
            $ws->write($line+3, $col, $columns[$col]);
        }
    }
    #$ws->write(0, 0, "$program_name, $location ($year)");
    $ss ->close();
}

1;
