
=head1 SGN::Controller::AJAX::HTMLSelect - a resource to dynamically obtain html selects for a number of widely used data types

=head1 SYNOPSYS

get_location_select()

get_breeding_program_select()

get_year_select()



=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

package SGN::Controller::AJAX::HTMLSelect;

use Moose;

use Data::Dumper;
use CXGN::BreedersToolbox::Projects;
use CXGN::Page::FormattingHelpers qw | simple_selectbox_html simple_checkbox_html |;
use Scalar::Util qw | looks_like_number |;
use CXGN::Trial;
use CXGN::Onto;
use CXGN::List;
use CXGN::Trial::Folder;
use SGN::Model::Cvterm;
use CXGN::Chado::Stock;
use CXGN::Stock::Search;
use CXGN::Stock::Seedlot;
use CXGN::Dataset;
use JSON;
use Image::Size;
use Math::Round;
use URI::Encode qw(uri_encode uri_decode);
use Array::Utils qw(:all);

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub get_location_select : Path('/ajax/html/select/locations') Args(0) {
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "location_select";
    my $name = $c->req->param("name") || "location_select";
    my $empty = $c->req->param("empty") || "";

    my $locations = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_all_locations();

    if ($empty) { unshift @$locations, [ "", "Select Location" ] }

    my $default = $c->req->param("default") || @$locations[0]->[0];

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => $locations,
      selected => $default
	  );
    $c->stash->{rest} = { select => $html };
}

sub get_breeding_program_select : Path('/ajax/html/select/breeding_programs') Args(0) {
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "breeding_program_select";
    my $name = $c->req->param("name") || "breeding_program_select";
    my $empty = $c->req->param("empty") || "";

    my $breeding_programs = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_breeding_programs();

    my $default = $c->req->param("default") || @$breeding_programs[0]->[0];
    if ($empty) { unshift @$breeding_programs, [ "", "please select" ]; }

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => $breeding_programs,
      selected => $default
    );
    $c->stash->{rest} = { select => $html };
}

sub get_year_select : Path('/ajax/html/select/years') Args(0) {
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "year_select";
    my $name = $c->req->param("name") || "year_select";
    my $empty = $c->req->param("empty") || "";
    my $auto_generate = $c->req->param("auto_generate") || "";

    my @years;
    if ($auto_generate) {
      my $next_year = 1901 + (localtime)[5];
      my $oldest_year = $next_year - 50;
      @years = sort { $b <=> $a } ($oldest_year..$next_year);
    }
    else {
      @years = sort { $b <=> $a } CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_all_years();
    }

    my $default = $c->req->param("default") || $years[1];

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => \@years,
      selected => $default
    );
    $c->stash->{rest} = { select => $html };
}

sub get_trial_folder_select : Path('/ajax/html/select/folders') Args(0) {
    my $self = shift;
    my $c = shift;

    my $breeding_program_id = $c->req->param("breeding_program_id");
    my $folder_for_trials = 1 ? $c->req->param("folder_for_trials") eq 'true' : 0;
    my $folder_for_crosses = 1 ? $c->req->param("folder_for_crosses") eq 'true' : 0;
    my $folder_for_genotyping_trials = 1 ? $c->req->param("folder_for_genotyping_trials") eq 'true' : 0;

    my $id = $c->req->param("id") || "folder_select";
    my $name = $c->req->param("name") || "folder_select";
    my $empty = $c->req->param("empty") || ""; # set if an empty selection should be present


    my @folders = CXGN::Trial::Folder->list({
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    breeding_program_id => $breeding_program_id,
        folder_for_trials => $folder_for_trials,
        folder_for_crosses => $folder_for_crosses,
        folder_for_genotyping_trials => $folder_for_genotyping_trials
    });

    if ($empty) {
      unshift @folders, [ 0, "None" ];
    }

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => \@folders,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_trial_type_select : Path('/ajax/html/select/trial_types') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $id = $c->req->param("id") || "trial_type_select";
    my $name = $c->req->param("name") || "trial_type_select";
    my $empty = $c->req->param("empty") || ""; # set if an empty selection should be present

    my @all_types = CXGN::Trial::get_all_project_types($c->dbic_schema("Bio::Chado::Schema"));

    my $crossing_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial', 'project_type')->cvterm_id();
    my $pollinating_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'pollinating_trial', 'project_type')->cvterm_id();
    my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_trial', 'project_type')->cvterm_id();

    my @types;

    foreach my $type(@all_types){
        if (($type->[0] != $crossing_trial_cvterm_id) && ($type->[0] != $pollinating_trial_cvterm_id) && ($type->[0] != $genotyping_trial_cvterm_id)){
            push @types, $type;
        }
    }

    if ($empty) {
        unshift @types, [ '', "None" ];
    }

    my $default = $c->req->param("default") || $types[0]->[0];

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@types,
        selected => $default
    );
    $c->stash->{rest} = { select => $html };
}

sub get_treatments_select : Path('/ajax/html/select/treatments') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $trial_id = $c->req->param("trial_id");

    my $id = $c->req->param("id") || "treatment_select";
    my $name = $c->req->param("name") || "treatment_select";
    my $empty = $c->req->param("empty") || ""; # set if an empty selection should be present

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
    my $data = $trial->get_treatments();

    if ($empty) {
        unshift @$data, [ 0, "None" ];
    }
    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => $data,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_projects_select : Path('/ajax/html/select/projects') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema } );
    my $breeding_program_id = $c->req->param("breeding_program_id");
    my $breeding_program_name = $c->req->param("breeding_program_name");
    my $get_field_trials = $c->req->param("get_field_trials");
    my $get_crossing_trials = $c->req->param("get_crossing_trials");
    my $get_genotyping_trials = $c->req->param("get_genotyping_trials");
    my $include_analyses = $c->req->param("include_analyses");

    my $projects;
    if (!$breeding_program_id && !$breeding_program_name) {
        $projects = $p->get_breeding_programs();
    } elsif ($breeding_program_id){
        push @$projects, [$breeding_program_id];
    } else {
        push @$projects, [$schema->resultset('Project::Project')->find({name => $breeding_program_name})->project_id()];
    }

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my $size = $c->req->param("size");
    my $empty = $c->req->param("empty") || "";
    my $multiple = $c->req->param("multiple") || 0;
    my $live_search = $c->req->param("live_search") || 0;

    my @projects;
    foreach my $project (@$projects) {
        my ($field_trials, $cross_trials, $genotyping_trials, $genotyping_data_projects, $field_management_factor_projects, $drone_run_projects, $drone_run_band_projects, $analyses_projects) = $p->get_trials_by_breeding_program($project->[0]);
        if ($get_field_trials){
            if ($field_trials && scalar(@$field_trials)>0){
                my @trials = sort { $a->[1] cmp $b->[1] } @$field_trials;
                push @projects, @trials;
            }
        }
        if ($get_crossing_trials){
            if ($cross_trials && scalar(@$cross_trials)>0){
                my @trials = sort { $a->[1] cmp $b->[1] } @$cross_trials;
                push @projects, @trials;
            }
        }
        if ($get_genotyping_trials){
            if ($genotyping_trials && scalar(@$genotyping_trials)>0){
                my @trials = sort { $a->[1] cmp $b->[1] } @$genotyping_trials;
                push @projects, @trials;
            }
        }
        if ($include_analyses) {
            if ($analyses_projects && scalar(@$analyses_projects)>0){
                my @analyses = sort { $a->[1] cmp $b->[1] } @$analyses_projects;
                push @projects, @analyses;
            }
        }
    }

    if ($empty) { unshift @projects, [ "", "Please select a trial" ]; }

    my $html = simple_selectbox_html(
      multiple => $multiple,
      live_search => $live_search,
      name => $name,
      id => $id,
      size => $size,
      choices => \@projects,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_trials_select : Path('/ajax/html/select/trials') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema } );
    my $breeding_program_id = $c->req->param("breeding_program_id");
    my $breeding_program_name = $c->req->param("breeding_program_name");
    my $trial_name_values = $c->req->param("trial_name_values") || 0;

    my $projects;
    if (!$breeding_program_id && !$breeding_program_name) {
        $projects = $p->get_breeding_programs();
    } elsif ($breeding_program_id){
        push @$projects, [$breeding_program_id];
    } else {
        push @$projects, [$schema->resultset('Project::Project')->find({name => $breeding_program_name})->project_id()];
    }

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my $size = $c->req->param("size");
    my $empty = $c->req->param("empty") || "";
    my $multiple = $c->req->param("multiple") || 0;
    my $live_search = $c->req->param("live_search") || 0;
    my $include_location_year = $c->req->param("include_location_year");
    my $include_lists = $c->req->param("include_lists") || 0;

    my @trials;
    if ($include_lists) { push @trials, [ "", "----INDIVIDUAL TRIALS----" ]; }
    foreach my $project (@$projects) {
      my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$field_trials) {
          my $trial_id = $_->[0];
          my $trial_name = $_->[1];
          if ($include_location_year) {
              my $trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id });
              my $location_array = $trial->get_location();
              my $year = $trial->get_year();
              $trial_name .= " (".$location_array->[1]." $year)";
          }
          push @trials, [$trial_id, $trial_name];
      }
    }
    if ($trial_name_values) {
        my @trials_redef;
        foreach (@trials) {
            push @trials_redef, [$_->[1], $_->[1]];
        }
        @trials = @trials_redef;
    }
    @trials = sort { $a->[1] cmp $b->[1] } @trials;

    if ($include_lists) {
        my $lists = CXGN::List::available_lists($c->dbc->dbh(), $c->user()->get_sp_person_id());
        my $public_lists = CXGN::List::available_public_lists($c->dbc->dbh());
        my $lt = CXGN::List::Transform->new();

        push @trials, ["", "----YOUR LISTS OF TRIALS----"];
        foreach my $item (@$lists) {
            if ( @$item[5] eq "trials" ) {
                my $list = CXGN::List->new({ dbh=>$c->dbc->dbh(), list_id => @$item[0] });
                my $list_elements = $list->retrieve_elements_with_ids(@$item[0]);
                my @list_element_names = map { $_->[1] } @$list_elements;
                my $transform = $lt->transform($schema, 'projects_2_project_ids', \@list_element_names);
                my @trial_ids = @{$transform->{transform}};
                push @trials, [join(',', @trial_ids), @$item[1] . ' (' . @$item[3] . ' trials)'];
            }
        }

        push @trials, ["", "----PUBLIC LISTS OF TRIALS----"];
        foreach my $item (@$public_lists) {
            if ( @$item[5] eq "trials" ) {
                my $list = CXGN::List->new({ dbh=>$c->dbc->dbh(), list_id => @$item[0] });
                my $list_elements = $list->retrieve_elements_with_ids(@$item[0]);
                my @list_element_names = map { $_->[1] } @$list_elements;
                my $transform = $lt->transform($schema, 'projects_2_project_ids', \@list_element_names);
                my @trial_ids = @{$transform->{transform}};
                push @trials, [join(',', @trial_ids), @$item[1] . ' (' . @$item[3] . ' trials)'];
            }
        }
    }

    if ($empty) { unshift @trials, [ "", "Please select a trial" ]; }

    my $html = simple_selectbox_html(
      multiple => $multiple,
      live_search => $live_search,
      name => $name,
      id => $id,
      size => $size,
      choices => \@trials,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_genotyping_trials_select : Path('/ajax/html/select/genotyping_trials') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema } );
    my $breeding_program_id = $c->req->param("breeding_program_id");
    my $breeding_program_name = $c->req->param("breeding_program_name");

    my $projects;
    if (!$breeding_program_id && !$breeding_program_name) {
        $projects = $p->get_breeding_programs();
    } elsif ($breeding_program_id){
        push @$projects, [$breeding_program_id];
    } else {
        push @$projects, [$schema->resultset('Project::Project')->find({name => $breeding_program_name})->project_id()];
    }

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my $size = $c->req->param("size");
    my $empty = $c->req->param("empty") || "";
    my $multiple = $c->req->param("multiple") || 0;
    my $live_search = $c->req->param("live_search") || 0;

    my @trials;
    foreach my $project (@$projects) {
      my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$genotyping_trials) {
          push @trials, $_;
      }
    }
    @trials = sort { $a->[1] cmp $b->[1] } @trials;

    if ($empty) { unshift @trials, [ "", "Please select a trial" ]; }

    my $html = simple_selectbox_html(
      multiple => $multiple,
      live_search => $live_search,
      name => $name,
      id => $id,
      size => $size,
      choices => \@trials,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_label_data_source_select : Path('/ajax/html/select/label_data_sources') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR "Retrieving list items . . .\n";

    my $id = $c->req->param("id") || "label_data_sources_select";
    my $name = $c->req->param("name") || "label_data_sources_select";
    my $empty = $c->req->param("empty") || "";
    my $live_search = $c->req->param("live_search") ? 'data-live-search="true"' : '';
    my $default = $c->req->param("default") || 0;

    my $user_id = $c->user()->get_sp_person_id();

    # my $all_lists = CXGN::List::all_types($c->dbc->dbh());

    my $lists = CXGN::List::available_lists($c->dbc->dbh(), $user_id );
    my $public_lists = CXGN::List::available_public_lists($c->dbc->dbh() );

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );
    my $projects = $p->get_breeding_programs();

    my (@field_trials, @crossing_experiments, @genotyping_trials) = [];
    foreach my $project (@$projects) {
      my ($field_trials, $crossing_experiments, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$field_trials) {
          push @field_trials, $_;
      }
      foreach (@$crossing_experiments) {
          push @crossing_experiments, $_;
      }
      foreach (@$genotyping_trials) {
          push @genotyping_trials, $_;
      }
    }

    my @choices = [];
    push @choices, '__Field Trials';
    @field_trials = sort { $a->[1] cmp $b->[1] } @field_trials;
    foreach my $trial (@field_trials) {
        push @choices, $trial;
    }
    push @choices, '__Genotyping Plates';
    @genotyping_trials = sort { $a->[1] cmp $b->[1] } @genotyping_trials;
    foreach my $trial (@genotyping_trials) {
        push @choices, $trial;
    }
    push @choices, '__Crossing Experiments';
    @crossing_experiments = sort { $a->[1] cmp $b->[1] } @crossing_experiments;
    foreach my $crossing_experiment (@crossing_experiments) {
         push @choices, $crossing_experiment;
    }
    push @choices, '__Lists';
    foreach my $item (@$lists) {
        push @choices, [@$item[0], @$item[1]];
    }
    push @choices, '__Public Lists';
    foreach my $item (@$public_lists) {
        push @choices, [@$item[0], @$item[1]];
    }

    print STDERR "Choices are:\n".Dumper(@choices);

    if ($default) { unshift @choices, [ '', $default ]; }

    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => \@choices,
      params => $live_search,
      selected_params => 'hidden'
    );

    $c->stash->{rest} = { select => $html };
}
# sub get_trials_select : Path('/ajax/html/select/trials') Args(0) {
#     my $self = shift;
#     my $c = shift;
#
    # my $id = $c->req->param("id") || "label_data_sources_select";
    # my $name = $c->req->param("name") || "label_data_sources_select";
    # my $empty = $c->req->param("empty") || "";
    # my $live_search = $c->req->param("live_search") ? 'data-live-search="true"' : '';
    # my $default = $c->req->param("default") || 0;
    #
    # my $lists = CXGN::List::available_lists($c->dbc->dbh(), $c->user(), 'plots');
    # my $public_lists = CXGN::List::available_public_lists($c->dbc->dbh(), 'plots');
    #
    # my $projects = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_breeding_programs();
    # my @trials = [];
    # foreach my $project (@$projects) {
    #   my ($field_trials, $cross_trials, $genotyping_trials) = $projects->get_trials_by_breeding_program($project->[0]);
    #   foreach (@$field_trials) {
    #       push @trials, $_;
    #   }
    # }
    # @trials = sort { $a->[1] cmp $b->[1] } @trials;
    #
    # my @choices = [];
    # push @choices, '__Your Plot Lists';
    # foreach my $item (@$lists) {
    #     push @choices, $item;
    # }
    # push @choices, '__Public Plot Lists';
    # foreach my $item (@$public_lists) {
    #     push @choices, $item;
    # }
    # push @choices, '__Trials';
    # foreach my $trial (@trials) {
    #     push @choices, $trial;
    # }
    #
    # print STDERR "Choices are:\n".Dumper(@choices);
    #
    # if ($default) { unshift @trials, [ '', $default ]; }
    #
    # my $html = simple_selectbox_html(
    #   name => $name,
    #   id => $id,
    #   choices => \@choices,
    #   params => $live_search
    # );
#
#     $c->stash->{rest} = { select => $html };
# }

sub get_stocks_select : Path('/ajax/html/select/stocks') Args(0) {
	my $self = shift;
	my $c = shift;
	my $params = _clean_inputs($c->req->params);
    my $names_as_select = $params->{names_as_select}->[0] || 0;

    my %stockprops_values;
    if ($params->{organization_list} && scalar(@{$params->{organization_list}})>0){
        $stockprops_values{'organization'} = $params->{organization_list};
    }
    if ($params->{pui_list} && scalar(@{$params->{pui_list}})>0){
        $stockprops_values{'PUI'} = $params->{pui_list};
    }
    if ($params->{accession_number_list} && scalar(@{$params->{accession_number_list}})>0){
        $stockprops_values{'accession number'} = $params->{accession_number_list};
    }

	my $stock_search = CXGN::Stock::Search->new({
		bcs_schema=>$c->dbic_schema("Bio::Chado::Schema", "sgn_chado"),
		people_schema=>$c->dbic_schema("CXGN::People::Schema"),
		phenome_schema=>$c->dbic_schema("CXGN::Phenome::Schema"),
		match_type=>$params->{match_type}->[0],
		match_name=>$params->{match_type}->[0],
		uniquename_list=>$params->{uniquename_list},
		genus_list=>$params->{genus_list},
		species_list=>$params->{species_list},
		stock_id_list=>$params->{stock_id_list},
		organism_id=>$params->{organism_id}->[0],
		stock_type_name=>$params->{stock_type_name}->[0],
		stock_type_id=>$params->{stock_type_id}->[0],
		owner_first_name=>$params->{owner_first_name}->[0],
		owner_last_name=>$params->{owner_last_name}->[0],
		trait_cvterm_name_list=>$params->{trait_cvterm_name_list},
		minimum_phenotype_value=>$params->{minimum_phenotype_value}->[0],
		maximum_phenotype_value=>$params->{maximum_phenotype_value}->[0],
		trial_name_list=>$params->{trial_name_list},
		trial_id_list=>$params->{trial_id_list},
		breeding_program_id_list=>$params->{breeding_program_id_list},
		location_name_list=>$params->{location_name_list},
		year_list=>$params->{year_list},
        stockprops_values=>\%stockprops_values,
		limit=>$params->{limit}->[0],
		offset=>$params->{offset}->[0],
		minimal_info=>1,
        display_pedigree=>0
	});
	my ($result, $records_total) = $stock_search->search();
	#print STDERR Dumper $result;
	my $id = $c->req->param("id") || "html_trial_select";
	my $name = $c->req->param("name") || "html_trial_select";
	my $multiple = defined($c->req->param("multiple")) ? $c->req->param("multiple") : 1;
	my $size = $c->req->param("size");
	my $empty = $c->req->param("empty") || "";
	my $data_related = $c->req->param("data-related") || "";
	my @stocks;
	foreach my $r (@$result) {
        if ($names_as_select) {
	        push @stocks, [ $r->{uniquename}, $r->{uniquename} ];
        } else {
            push @stocks, [ $r->{stock_id}, $r->{uniquename} ];
        }
	}
	@stocks = sort { $a->[1] cmp $b->[1] } @stocks;

	if ($empty) { unshift @stocks, [ "", "Please select a stock" ]; }

	my $html = simple_selectbox_html(
		multiple => $multiple,
		name => $name,
		id => $id,
		size => $size,
		choices => \@stocks,
        data_related => $data_related
	);
	$c->stash->{rest} = { select => $html };
}

sub get_seedlots_select : Path('/ajax/html/select/seedlots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $accessions = $c->req->param('seedlot_content_accession_name') ? [$c->req->param('seedlot_content_accession_name')] : [];
    my $crosses = $c->req->param('seedlot_content_cross_name') ? [$c->req->param('seedlot_content_cross_name')] : [];
#    my $offset = $c->req->param('seedlot_offset') ? $c->req->param('seedlot_offset') : '';
#    my $limit = $c->req->param('seedlot_limit') ? $c->req->param('seedlot_limit') : '';
#    my $search_seedlot_name = $c->req->param('seedlot_name') ? $c->req->param('seedlot_name') : '';
    my $search_breeding_program_name = $c->req->param('seedlot_breeding_program_name') ? $c->req->param('seedlot_breeding_program_name') : '';
#    my $search_location = $c->req->param('seedlot_location') ? $c->req->param('seedlot_location') : '';
#    my $search_amount = $c->req->param('seedlot_amount') ? $c->req->param('seedlot_amount') : '';
#    my $search_weight = $c->req->param('seedlot_weight') ? $c->req->param('seedlot_weight') : '';
    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $c->dbic_schema("Bio::Chado::Schema", "sgn_chado"),
        $c->dbic_schema("CXGN::People::Schema"),
        $c->dbic_schema("CXGN::Phenome::Schema"),
        undef,
        undef,
        undef,
        $search_breeding_program_name,
        undef,
        undef,
        $accessions,
        $crosses,
        1,
        undef
    );
    my @seedlots;
    foreach my $sl (@$list) {
        push @seedlots, {
            breeding_program_id => $sl->{breeding_program_id},
            breeding_program_name => $sl->{breeding_program_name},
            seedlot_stock_id => $sl->{seedlot_stock_id},
            seedlot_stock_uniquename => $sl->{seedlot_stock_uniquename},
            location => $sl->{location},
            location_id => $sl->{location_id},
            count => $sl->{current_count}
        };
    }
    #print STDERR Dumper \@seedlots;
    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my $multiple = defined($c->req->param("multiple")) ? $c->req->param("multiple") : 1;
    my $size = $c->req->param("size");
    my $empty = $c->req->param("empty") || "";
    my $data_related = $c->req->param("data-related") || "";
    my @stocks;
    foreach my $r (@seedlots) {
        push @stocks, [ $r->{seedlot_stock_id}, $r->{seedlot_stock_uniquename} ];
    }
    @stocks = sort { $a->[1] cmp $b->[1] } @stocks;

    if ($empty) { unshift @stocks, [ "", "Please select a stock" ]; }

    my $html = simple_selectbox_html(
        multiple => $multiple,
        name => $name,
        id => $id,
        size => $size,
        choices => \@stocks,
        data_related => $data_related
    );
    $c->stash->{rest} = { select => $html };
}

sub get_ontologies : Path('/ajax/html/select/trait_variable_ontologies') Args(0) {
    my $self = shift;
    my $c = shift;
    my $cvprop_type_names = $c->req->param("cvprop_type_name") ? decode_json $c->req->param("cvprop_type_name") : ['trait_ontology', 'method_ontology', 'unit_ontology'];
    my $use_full_trait_name = $c->req->param("use_full_trait_name") || 0;

    my $observation_variables = CXGN::BrAPI::v1::ObservationVariables->new({
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
        metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
        phenome_schema=>$c->dbic_schema("CXGN::Phenome::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        page_size => 1000000,
        page => 0,
        status => []
    });

    my $result = $observation_variables->observation_variable_ontologies({cvprop_type_names => $cvprop_type_names});
    #print STDERR Dumper $result;

    my @ontos;
    foreach my $o (@{$result->{result}->{data}}) {
        if ($use_full_trait_name) {
            push @ontos, [$o->{description}."|".$o->{ontologyName}.":".$o->{ontologyDbxrefAccession}, $o->{description}."|".$o->{ontologyName}.":".$o->{ontologyDbxrefAccession} ];
        } else {
            push @ontos, [$o->{ontologyDbId}, $o->{ontologyName}." (".$o->{description}.")" ];
        }
    }

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my $data_related = $c->req->param("data-related") || "";

    @ontos = sort { $a->[1] cmp $b->[1] } @ontos;

    my $html = simple_checkbox_html(
        name => $name,
        id => $id,
        choices => \@ontos,
        data_related => $data_related
    );
    $c->stash->{rest} = { select => $html };
}

sub get_high_dimensional_phenotypes_protocols : Path('/ajax/html/select/high_dimensional_phenotypes_protocols') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $checkbox_name = $c->req->param('checkbox_name');
    my $protocol_type = $c->req->param('high_dimensional_phenotype_protocol_type');

    my $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $protocol_type, 'protocol_type')->cvterm_id();
    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value
        FROM nd_protocol
        JOIN nd_protocolprop USING(nd_protocol_id)
        WHERE nd_protocol.type_id=$protocol_type_cvterm_id AND nd_protocolprop.type_id=$protocolprop_type_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my $html = '<table class="table table-bordered table-hover" id="html-select-highdimprotocol-table"><thead><tr><th>Select</th><th>Protocol Name</th><th>Description</th><th>Create Date</th><th>Properties</th></tr></thead><tbody>';

    while (my ($nd_protocol_id, $name, $description, $create_date, $props_json) = $h->fetchrow_array()) {
        my $props = decode_json $props_json;
        $html .= '<tr><td><input type="checkbox" name="'.$checkbox_name.'" value="'.$nd_protocol_id.'"></td><td>'.$name.'</td><td>'.$description.'</td><td>'.$create_date.'</td><td>';
        while (my($k,$v) = each %$props) {
            if ($k ne 'header_column_details' && $k ne 'header_column_names') {
                $html .= "$k: $v<br/>";
            }
        }
        $html .= '</td></tr>';
    }
    $html .= "</tbody></table>";

    $html .= "<script>jQuery(document).ready(function() { jQuery('#html-select-highdimprotocol-table').DataTable({ }); } );</script>";

    $c->stash->{rest} = { select => $html };
}

sub get_analytics_protocols : Path('/ajax/html/select/analytics_protocols') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $checkbox_name = $c->req->param('checkbox_name');
    my $protocol_type = $c->req->param('analytics_protocol_type');

    my $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $protocol_type, 'protocol_type')->cvterm_id();
    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_properties', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value
        FROM nd_protocol
        JOIN nd_protocolprop USING(nd_protocol_id)
        WHERE nd_protocol.type_id=$protocol_type_cvterm_id AND nd_protocolprop.type_id=$protocolprop_type_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my $html = '<table class="table table-bordered table-hover" id="html-select-analyticsprotocol-table"><thead><tr><th>Select</th><th>Analytics Name</th><th>Description</th><th>Create Date</th><th>Properties</th></tr></thead><tbody>';

    while (my ($nd_protocol_id, $name, $description, $create_date, $props_json) = $h->fetchrow_array()) {
        my $props = decode_json $props_json;
        $html .= '<tr><td><input type="checkbox" name="'.$checkbox_name.'" value="'.$nd_protocol_id.'"></td><td>'.$name.'</td><td>'.$description.'</td><td>'.$create_date.'</td><td>';
        while (my($k,$v) = each %$props) {
            $html .= "$k: $v<br/>";
        }
        $html .= '</td></tr>';
    }
    $html .= "</tbody></table>";

    $html .= "<script>jQuery(document).ready(function() { jQuery('#html-select-analyticsprotocol-table').DataTable({ }); } );</script>";

    $c->stash->{rest} = { select => $html };
}

sub get_sequence_metadata_protocols : Path('/ajax/html/select/sequence_metadata_protocols') Args(0) {
    my $self = shift;
    my $c = shift;
    my $checkbox_name = $c->req->param('checkbox_name');
    my $data_type_cvterm_id = $c->req->param('sequence_metadata_data_type_id');
    my $include_query_link = $c->req->param('include_query_link');
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sequence_metadata_protocol', 'protocol_type')->cvterm_id();
    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sequence_metadata_protocol_properties', 'protocol_property')->cvterm_id();

    # Only select protocols that have a type of 'sequence_metadata_protocol' and its protocolprop of 'sequence_metadata_type' is the same as the provided $data_type
    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, nd_protocolprop.value
        FROM nd_protocol
        JOIN nd_protocolprop USING(nd_protocol_id)
        WHERE nd_protocol.type_id=$protocol_type_cvterm_id AND nd_protocolprop.type_id=$protocolprop_type_cvterm_id
        AND (nd_protocolprop.value->>'sequence_metadata_type_id')::integer = $data_type_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my $html = '<table class="table table-bordered table-hover" id="html-select-sdmprotocol-table-' . $data_type_cvterm_id . '">';
    my $select_th = defined $checkbox_name ? "<th>Select</th>" : "";
    $html .= '<thead><tr>' . $select_th . '<th>Protocol&nbsp;Name</th><th>Description</th><th>Properties</th></tr></thead>';
    $html .= '<tbody>';

    while (my ($nd_protocol_id, $name, $description, $props_json) = $h->fetchrow_array()) {

        # Decode the json props
        my $props = decode_json $props_json;

        # Add link to protocol name, if requested
        if ( $include_query_link ) {
            $name = "<a href='/search/sequence_metadata?nd_protocol_id=$nd_protocol_id&reference_genome=" . $props->{'reference_genome'} . "'>$name</a>";
        }

        # Build the row of the table
        my $select_td = defined $checkbox_name ? '<td><input type="checkbox" name="'.$checkbox_name.'" value="'.$nd_protocol_id.'"></td>' : '';
        $html .= '<tr>' . $select_td . '<td>'.$name.'</td><td>'.$description.'</td><td>';

        my $type = $props->{'sequence_metadata_type'};
        $type =~ s/ /&nbsp;/;
        $html .= "<strong>Data&nbsp;Type:</strong>&nbsp;" . $type . "<br />";
        $html .= "<strong>Reference&nbsp;Genome:</strong>&nbsp;" . $props->{'reference_genome'} . "<br />";
        $html .= "<strong>Score:</strong>&nbsp;" . $props->{'score_description'} . "<br />";
        $html .= "<strong>Attributes:</strong><br />";

        my $attributes = $props->{'attribute_descriptions'};
        $html .= "<table class='table table-striped' style='min-width: 300px'>";
        $html .= "<thead><tr><th>Key</th><th>Description</th></tr></thead>";
        while (my($k,$v) = each %$attributes) {
            $html .= "<tr><td>$k</td><td>$v</td></tr>";
        }
        $html .= "</table>";

        my $links = $props->{'links'};
        if ( defined $links ) {
            $html .= "<strong>Links:</strong><br />";
            $html .= "<table class='table table-striped' style='min-width: 300px'>";
            $html .= "<thead><tr><th>Title</th><th>URL&nbsp;Template</th></tr></thead>";
            while (my($k,$v) = each %$links) {
                $html .= "<tr><td>$k</td><td>$v</td></tr>";
            }
        }
        $html .= "</table>";

        $html .= '</td></tr>';

    }
    $html .= "</tbody></table>";

    $html .= "<script>jQuery(document).ready(function() { jQuery('#html-select-sdmprotocol-table-" . $data_type_cvterm_id . "').DataTable({ }); } );</script>";

    $c->stash->{rest} = { select => $html };
}

sub get_trained_nirs_models : Path('/ajax/html/select/trained_nirs_models') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $checkbox_name = $c->req->param('checkbox_name');

    my $nirs_model_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'waves_nirs_spectral_predictions', 'protocol_type')->cvterm_id();
    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, model_type.value
        FROM nd_protocol
        JOIN nd_protocolprop AS model_type ON(nd_protocol.nd_protocol_id=model_type.nd_protocol_id AND model_type.type_id=$model_properties_cvterm_id)
        WHERE nd_protocol.type_id=$nirs_model_cvterm_id;";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute();

    my $html = '<table class="table table-bordered table-hover" id="html-select-nirsmodel-table"><thead><tr><th>Select</th><th>Model Name</th><th>Description</th><th>Format</th><th>Trait</th><th>Algorithm</th></tr></thead><tbody>';

    while (my ($nd_protocol_id, $name, $description, $model_type) = $model_h->fetchrow_array()) {
        my $model_type_hash = decode_json $model_type;
        my $selected_trait_name = $model_type_hash->{trait_name};
        my $preprocessing_boolean = $model_type_hash->{preprocessing_boolean};
        my $niter = $model_type_hash->{niter};
        my $algorithm = $model_type_hash->{algorithm};
        my $tune = $model_type_hash->{tune};
        my $random_forest_importance = $model_type_hash->{random_forest_importance};
        my $cross_validation = $model_type_hash->{cross_validation};
        my $format = $model_type_hash->{format};

        $html .= '<tr><td><input type="checkbox" name="'.$checkbox_name.'" value="'.$nd_protocol_id.'"></td><td>'.$name.'</td><td>'.$description.'</td><td>'.$format.'</td><td>'.$selected_trait_name.'</td><td>'.$algorithm.'</td></tr>';
    }
    $html .= "</tbody></table>";

    $html .= "<script>jQuery(document).ready(function() { jQuery('#html-select-nirsmodel-table').DataTable({ }); } );</script>";

    $c->stash->{rest} = { select => $html };
}

sub get_trained_keras_cnn_models : Path('/ajax/html/select/trained_keras_cnn_models') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $keras_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_cnn_model', 'protocol_type')->cvterm_id();
    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, model_type.value
        FROM nd_protocol
        JOIN nd_protocolprop AS model_type ON(nd_protocol.nd_protocol_id=model_type.nd_protocol_id AND model_type.type_id=$model_properties_cvterm_id)
        WHERE nd_protocol.type_id=$keras_cnn_cvterm_id;";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute();
    my @keras_cnn_models;
    while (my ($nd_protocol_id, $name, $description, $model_type) = $model_h->fetchrow_array()) {
        my $model_type_hash = decode_json $model_type;
        my $trait_id = $model_type_hash->{variable_id};
        my $trained_trait_name = $model_type_hash->{variable_name};
        my $aux_trait_ids = $model_type_hash->{aux_trait_ids} ? $model_type_hash->{aux_trait_ids} : [];
        $model_type = $model_type_hash->{model_type};
        my $trained_image_type = $model_type_hash->{image_type};

        my @aux_trait_names;
        if (scalar(@$aux_trait_ids)>0) {
            foreach (@$aux_trait_ids) {
                my $aux_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $_, 'extended');
                push @aux_trait_names, $aux_trait_name;
            }
            $name .= " Aux Traits:".join(",", @aux_trait_names);
        }
        push @keras_cnn_models, [$nd_protocol_id, $name];
    }

    my $id = $c->req->param("id") || "html_keras_cnn_select";
    my $name = $c->req->param("name") || "html_keras_cnn_select";

    @keras_cnn_models = sort { $a->[1] cmp $b->[1] } @keras_cnn_models;

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@keras_cnn_models
    );
    $c->stash->{rest} = { select => $html };
}

sub get_trained_keras_mask_r_cnn_models : Path('/ajax/html/select/trained_keras_mask_r_cnn_models') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $keras_mask_r_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_mask_r_cnn_model', 'protocol_type')->cvterm_id();
    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, model_type.value
        FROM nd_protocol
        JOIN nd_protocolprop AS model_type ON(nd_protocol.nd_protocol_id=model_type.nd_protocol_id AND model_type.type_id=$model_properties_cvterm_id)
        WHERE nd_protocol.type_id=$keras_mask_r_cnn_cvterm_id;";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute();
    my @keras_cnn_models;
    while (my ($nd_protocol_id, $name, $description, $model_type) = $model_h->fetchrow_array()) {
        my $model_type_hash = decode_json $model_type;

        push @keras_cnn_models, [$nd_protocol_id, $name];
    }

    my $id = $c->req->param("id") || "html_keras_mask_r_cnn_select";
    my $name = $c->req->param("name") || "html_keras_mask_r_cnn_select";

    @keras_cnn_models = sort { $a->[1] cmp $b->[1] } @keras_cnn_models;

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@keras_cnn_models
    );
    $c->stash->{rest} = { select => $html };
}

sub get_analysis_models : Path('/ajax/html/select/models') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $model_properties_cvterm_id = $c->req->param('nd_protocol_type') ? SGN::Model::Cvterm->get_cvterm_row($schema, $c->req->param('nd_protocol_type'), 'protocol_property')->cvterm_id() : SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();

    my $model_q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, model_type.value
        FROM nd_protocol
        JOIN nd_protocolprop AS model_type ON(nd_protocol.nd_protocol_id=model_type.nd_protocol_id AND model_type.type_id=$model_properties_cvterm_id);";
    my $model_h = $schema->storage->dbh()->prepare($model_q);
    $model_h->execute();
    my @models;
    while (my ($nd_protocol_id, $name, $description, $model_type) = $model_h->fetchrow_array()) {
        my $model_type_hash = decode_json $model_type;

        push @models, [$nd_protocol_id, $name];
    }

    my $id = $c->req->param("id") || "html_model_select";
    my $name = $c->req->param("name") || "html_model_select";
    my $empty = $c->req->param("empty");

    @models = sort { $a->[1] cmp $b->[1] } @models;
    if ($empty) { unshift @models, [ "", "Please select a model" ]; }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@models
    );
    $c->stash->{rest} = { select => $html };
}

sub get_imaging_event_vehicles : Path('/ajax/html/select/imaging_event_vehicles') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stock.description, stockprop.value
        FROM stock
        JOIN stockprop ON(stock.stock_id=stockprop.stock_id AND stockprop.type_id=$imaging_vehicle_properties_cvterm_id)
        WHERE stock.type_id=$imaging_vehicle_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @imaging_vehicles;
    while (my ($stock_id, $name, $description, $prop) = $h->fetchrow_array()) {
        my $prop_hash = decode_json $prop;

        push @imaging_vehicles, [$stock_id, $name];
    }

    my $id = $c->req->param("id") || "html_imaging_vehicle_select";
    my $name = $c->req->param("name") || "html_imaging_vehicle_select";

    @imaging_vehicles = sort { $a->[1] cmp $b->[1] } @imaging_vehicles;

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@imaging_vehicles
    );
    $c->stash->{rest} = { select => $html };
}

sub get_traits_select : Path('/ajax/html/select/traits') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_ids = $c->req->param('trial_ids') || 'all';
    my $stock_id = $c->req->param('stock_id') || 'all';
    my $stock_type = $c->req->param('stock_type') ? $c->req->param('stock_type') . 's' : 'none';
    my $data_level = $c->req->param('data_level') || 'all';
    my $trait_format = $c->req->param('trait_format');
    my $contains_composable_cv_type = $c->req->param('contains_composable_cv_type');
    my $select_format = $c->req->param('select_format') || 'html_select'; #html_select or component_table_select
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $multiple = $c->req->param('multiple');
    my $empty = $c->req->param('empty');
    my $select_all = $c->req->param('select_all');

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my $size = $c->req->param("size");

    if ($data_level eq 'all') {
        $data_level = '';
    }

    my @traits;
    if (($trial_ids eq 'all') && ($stock_id eq 'all')) {
      my $bs = CXGN::BreederSearch->new( { dbh=> $c->dbc->dbh() } );
      my $status = $bs->test_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass});
      unless ($status->{'success'}) {
          $c->stash->{rest} = { select => '<center><p>Direct trait select is not currently available</p></center>'};
          return;
      }
      my $query = $bs->metadata_query([ 'traits' ], {}, {});
      @traits = @{$query->{results}};
      #print STDERR "Traits: ".Dumper(@traits)."\n";
    } elsif (looks_like_number($stock_id)) {
        my $stock = CXGN::Chado::Stock->new($schema, $stock_id);
        my @trait_list = $stock->get_trait_list();
        foreach (@trait_list){
            my @val = ($_->[0], $_->[2]."|".$_->[1]);
            push @traits, \@val;
        }
    } elsif ($trial_ids ne 'all') {
        my @trial_ids = split ',', $trial_ids;
        my %unique_traits_ids;
        my %unique_traits_ids_count;
        my %unique_traits_ids_drone_project;
        foreach (@trial_ids){
            my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
            my $traits_assayed = $trial->get_traits_assayed($data_level, $trait_format, $contains_composable_cv_type);
            foreach (@$traits_assayed) {
                $unique_traits_ids{$_->[0]} = $_;
                if ($_->[5]) {
                    push @{$unique_traits_ids_drone_project{$_->[0]}}, $_->[5];
                }
                if ($_->[3]) {
                    $unique_traits_ids_count{$_->[0]} += $_->[3];
                }
            }
        }
        if ($select_format eq 'component_table_select') {
            my $html = '<table class="table table-hover table-bordered" id="'.$id.'"><thead><th>Observation Variable Components</th><th>Select</th></thead><tbody>';
            my %unique_components;
            foreach (values %unique_traits_ids) {
                foreach my $component (@{$_->[2]}) {
                    $unique_components{$_->[0]}->{num_pheno} = $_->[3];
                    $unique_components{$_->[0]}->{imaging_project_id} = $_->[4];
                    $unique_components{$_->[0]}->{imaging_project_name} = $_->[5];
                    if ($component->{cv_type} && $component->{cv_type} eq $contains_composable_cv_type) {
                        $unique_components{$_->[0]}->{contains_cv_type} = $component->{name};
                    }
                    else {
                        push @{$unique_components{$_->[0]}->{cv_types}}, $component->{name};
                    }
                }
            }
            my %separated_components;
            while (my ($k, $v) = each %unique_components) {
                my $string_cv_types = join ',', @{$v->{cv_types}};
                push @{$separated_components{$string_cv_types}}, [$k, $v->{contains_cv_type}, $v->{num_pheno}, $v->{imaging_project_id}, $v->{imaging_project_name}];
            }
            foreach my $k (sort keys %separated_components) {
                my $v = $separated_components{$k};
                $html .= "<tr><td>".$k."</td><td>";
                foreach (@$v) {
                    $html .= "<input type='checkbox' name = '".$name."' value ='".$_->[0]."'";
                    if ($select_all) {
                        $html .= "checked";
                    }
                    $html .= ">&nbsp;".$_->[1]." (".$_->[2]." Phenotypes";
                    if ($_->[3] && $_->[4]) {
                        $html .= " From ".$_->[4];
                    }
                    $html .= ")<br/>";
                }
                $html .= "</td></tr>";
            }
            $html .= "</tbody></table>";
            $c->stash->{rest} = { select => $html };
            $c->detach;
        }
        elsif ($select_format eq 'component_table_multiseason_select') {
            my $html = '<table class="table table-hover table-bordered" id="'.$id.'"><thead><th>Observation Variable Components</th><th>Select</th></thead><tbody>';
            my %unique_components;
            foreach (values %unique_traits_ids) {
                foreach my $component (@{$_->[2]}) {
                    $unique_components{$_->[0]}->{num_pheno} = $_->[3];
                    $unique_components{$_->[0]}->{imaging_project_id} = $_->[4];
                    $unique_components{$_->[0]}->{imaging_project_name} = $_->[5];
                    if ($component->{cv_type} && $component->{cv_type} eq $contains_composable_cv_type) {
                        $unique_components{$_->[0]}->{contains_cv_type} = $component->{name};
                    }
                    else {
                        push @{$unique_components{$_->[0]}->{cv_types}}, $component->{name};
                    }
                }
            }
            my %separated_components;
            while (my ($k, $v) = each %unique_components) {
                my $string_cv_types = join ',', @{$v->{cv_types}};
                push @{$separated_components{$string_cv_types}}, [$k, $v->{contains_cv_type}, $v->{num_pheno}, $v->{imaging_project_id}, $v->{imaging_project_name}];
            }
            foreach my $k (sort keys %separated_components) {
                my $v = $separated_components{$k};
                $html .= "<tr><td>".$k."</td><td>";
                foreach (@$v) {
                    $html .= "<input type='checkbox' name = '".$name."' value ='".$_->[0]."'";
                    if ($select_all) {
                        $html .= "checked";
                    }
                    $html .= ">&nbsp;".$_->[1]." (".$_->[2]." Phenotypes";
                    if ($_->[3] && $_->[4]) {
                        $html .= " From ".$_->[4];
                    }
                    $html .= ")<br/>";
                }
                $html .= "</td></tr>";
            }
            $html .= "</tbody></table>";
            $c->stash->{rest} = { select => $html };
            $c->detach;
        }
        elsif ($select_format eq 'html_select') {
            foreach (values %unique_traits_ids) {
                my $text = $_->[1];
                my $phenotype_count = $unique_traits_ids_count{$_->[0]};
                if (exists($unique_traits_ids_drone_project{$_->[0]})) {
                    my $imaging_project_names = join ',', @{$unique_traits_ids_drone_project{$_->[0]}};
                    $text .= " ($imaging_project_names $phenotype_count Phenotypes)";
                } else {
                    $text .= " (".$phenotype_count." Phenotypes)";
                }
                push @traits, [$_->[0], $text];
            }
        }
    }

    @traits = sort { $a->[1] cmp $b->[1] } @traits;
    if ($empty) { unshift @traits, [ "", "Please select a trait" ]; }

    my $html = simple_selectbox_html(
      multiple => $multiple,
      name => $name,
      id => $id,
      choices => \@traits,
      size => $size
    );
    $c->stash->{rest} = { select => $html };
}

sub get_phenotyped_trait_components_select : Path('/ajax/html/select/phenotyped_trait_components') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_ids = $c->req->param('trial_ids');
    #my $stock_id = $c->req->param('stock_id') || 'all';
    #my $stock_type = $c->req->param('stock_type') . 's' || 'none';
    my $data_level = $c->req->param('data_level') || 'all';
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    if ($data_level eq 'all') {
        $data_level = '';
    }

    my @trial_ids = split ',', $trial_ids;

    my @trait_components;
    foreach (@trial_ids){
        my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
        push @trait_components, @{$trial->get_trait_components_assayed($data_level, $composable_cvterm_format)};
    }
    #print STDERR Dumper \@trait_components;
    my %unique_trait_components = map {$_->[0] => $_->[1]} @trait_components;
    my @unique_components;
    foreach my $id (keys %unique_trait_components){
        push @unique_components, [$id, $unique_trait_components{$id}];
    }
    #print STDERR Dumper \@unique_components;

    my $id = $c->req->param("id") || "html_trait_component_select";
    my $name = $c->req->param("name") || "html_trait_component_select";

    my $html = simple_selectbox_html(
      multiple => 1,
      name => $name,
      id => $id,
      choices => \@unique_components,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_composable_cvs_allowed_combinations_select : Path('/ajax/html/select/composable_cvs_allowed_combinations') Args(0) {
    my $self = shift;
    my $c = shift;
    my $id = $c->req->param("id") || "html_composable_cvs_combinations_select";
    my $name = $c->req->param("name") || "html_composable_cvs_combinations_select";
    my $composable_cvs_allowed_combinations = $c->config->{composable_cvs_allowed_combinations};
    my @combinations = split ',', $composable_cvs_allowed_combinations;
    my @select;
    foreach (@combinations){
        my @parts = split /\|/, $_; #/#
        push @select, [$parts[1], $parts[0]];
    }
    my $html = simple_selectbox_html(
      name => $name,
      id => $id,
      choices => \@select,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_crosses_select : Path('/ajax/html/select/crosses') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema } );
    my $breeding_program_id = $c->req->param("breeding_program_id");
    my $breeding_program_name = $c->req->param("breeding_program_name");

    my $projects;
    if (!$breeding_program_id && !$breeding_program_name) {
        $projects = $p->get_breeding_programs();
    } elsif ($breeding_program_id){
        push @$projects, [$breeding_program_id];
    } else {
        push @$projects, [$schema->resultset('Project::Project')->find({name => $breeding_program_name})->project_id()];
    }

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
    my $multiple = defined($c->req->param("multiple")) ? $c->req->param("multiple") : 1;
    my $size = $c->req->param("size");
    my @crosses;
    foreach my $project (@$projects) {
      my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$cross_trials) {
          push @crosses, $_;
      }
    }
    @crosses = sort @crosses;

    my $html = simple_selectbox_html(
      multiple => $multiple,
      name => $name,
      id => $id,
      size => $size,
      choices => \@crosses,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_genotyping_protocol_select : Path('/ajax/html/select/genotyping_protocol') Args(0) {
    my $self = shift;
    my $c = shift;

    my $id = $c->req->param("id") || "gtp_select";
    my $name = $c->req->param("name") || "genotyping_protocol_select";
    my $empty = $c->req->param("empty") || "";
    my $default_gtp;
    my %gtps;

    my $gt_protocols = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } )->get_gt_protocols();

    if (@$gt_protocols) {
        $default_gtp = $c->config->{default_genotyping_protocol};
        %gtps = map { @$_[1] => @$_[0] } @$gt_protocols;
    }

    if ($empty){
        unshift@$gt_protocols, ['', "Select a genotyping protocol"]
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => $gt_protocols,
        selected => $gtps{$default_gtp}
    );
    $c->stash->{rest} = { select => $html };
}

sub get_trait_components_select : Path('/ajax/html/select/trait_components') Args(0) {

  my $self = shift;
  my $c = shift;

  my $cv_id = $c->req->param('cv_id');
  #print STDERR "cv_id = $cv_id\n";
  my $id = $c->req->param("id") || "component_select";
  my $name = $c->req->param("name") || "component_select";
  my $default = $c->req->param("default") || 0;
  my $multiple =  $c->req->param("multiple") || 0;
  my $size = $c->req->param('size') || '5';

  my $dbh = $c->dbc->dbh();
  my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
  my @components = $onto->get_terms($cv_id);
  #print STDERR Dumper \@components;
  if ($default) { unshift @components, [ '', $default ]; }

  my $html = simple_selectbox_html(
    name => $name,
    multiple => $multiple,
    id => $id,
    choices => \@components,
    size => $size
  );

  $c->stash->{rest} = { select => $html };

}


sub ontology_children_select : Path('/ajax/html/select/ontology_children') Args(0) {
    my ($self, $c) = @_;
    my $parent_node_cvterm = $c->request->param("parent_node_cvterm");
    my $rel_cvterm = $c->request->param("rel_cvterm");
    my $rel_cv = $c->request->param("rel_cv");
    my $size = $c->req->param('size') || '5';
    my $value_format = $c->req->param('value_format') || 'ids';
    print STDERR "Parent Node $parent_node_cvterm\n";

    my $select_name = $c->request->param("selectbox_name");
    my $select_id = $c->request->param("selectbox_id");
    my $selected = $c->req->param("selected");
    my $empty = $c->request->param("empty") || '';
    my $multiple =  $c->req->param("multiple") || 0;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $parent_node_cvterm_row = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $parent_node_cvterm);
    my $parent_node_cvterm_id;
    if ($parent_node_cvterm_row){
        $parent_node_cvterm_id = $parent_node_cvterm_row->cvterm_id();
    }
    my $rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $rel_cvterm, $rel_cv)->cvterm_id();

    my $ontology_children_ref = $schema->resultset("Cv::CvtermRelationship")->search({type_id => $rel_cvterm_id, object_id => $parent_node_cvterm_id})->search_related('subject');
    my @ontology_children;
    while (my $child = $ontology_children_ref->next() ) {
        my $cvterm_id = $child->cvterm_id();
        my $dbxref_info = $child->search_related('dbxref');
        my $accession = $dbxref_info->first()->accession();
        my $db_info = $dbxref_info->search_related('db');
        my $db_name = $db_info->first()->name();
        if ($value_format eq 'ids'){
            push @ontology_children, [$cvterm_id, $child->name."|".$db_name.":".$accession];
        }
        if ($value_format eq 'names'){
            push @ontology_children, [$child->name."|".$db_name.":".$accession, $child->name."|".$db_name.":".$accession];
        }
    }

    @ontology_children = sort { $a->[1] cmp $b->[1] } @ontology_children;
    if ($empty) {
        unshift @ontology_children, [ 0, "None" ];
    }
    #print STDERR Dumper \@ontology_children;
    my $html = simple_selectbox_html(
        name => $select_name,
        id => $select_id,
        multiple => $multiple,
        choices => \@ontology_children,
        selected => $selected
    );
    $c->stash->{rest} = { select => $html };
}

sub all_ontology_terms_select : Path('/ajax/html/select/all_ontology_terms') Args(0) {
    my ($self, $c) = @_;
    my $db_id = $c->request->param("db_id");
    my $size = $c->req->param('size') || '5';

    my $select_name = $c->request->param("selectbox_name");
    my $select_id = $c->request->param("selectbox_id");

    my $empty = $c->request->param("empty") || '';
    my $multiple =  $c->req->param("multiple") || 0;
    my $exclude_top_term =  $c->req->param("exclude_top_term") || 1;

    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $exclude_top_sql = '';
    if ($exclude_top_term) {
        $exclude_top_sql = " AND dbxref.accession != '0000000' ";
    }

    my @ontology_terms;
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db using(db_id) WHERE db_id=$db_id $exclude_top_sql ORDER BY cvterm.name;";
    my $sth = $bcs_schema->storage->dbh->prepare($q);
    $sth->execute();
    while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $accession, $count) = $sth->fetchrow_array()) {
        push @ontology_terms, [$cvterm_id, $cvterm_name."|".$db_name.":".$accession];
    }

    #@ontology_terms = sort { $a->[1] cmp $b->[1] } @ontology_terms;
    if ($empty) {
        unshift @ontology_terms, [ 0, "None" ];
    }
    #print STDERR Dumper \@ontology_children;
    my $html = simple_selectbox_html(
        name => $select_name,
        id => $select_id,
        multiple => $multiple,
        choices => \@ontology_terms,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_datasets_select :Path('/ajax/html/select/datasets') Args(0) {
    my $self = shift;
    my $c = shift;
    my $checkbox_name = $c->request->param("checkbox_name") || 'dataset_select_checkbox';
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $num = int(rand(1000));
    my $user_id;
    my @datasets;
    if ($c->user()) {
        if ($user_id = $c->user->get_object()->get_sp_person_id()) {

            my $user_datasets = CXGN::Dataset->get_datasets_by_user(
                $c->dbic_schema("CXGN::People::Schema"),
                $user_id
            );
            #print STDERR "Retrieved datasets: ".Dumper($user_datasets);

            foreach (@$user_datasets) {
                my $dataset_id = $_->[0];
                my $dataset_name = $_->[1];
                my $dataset_description = $_->[2];

                my $ds = CXGN::Dataset->new({
                    schema => $schema,
                    people_schema => $people_schema,
                    sp_dataset_id => $dataset_id
                });
                my $info = $ds->get_dataset_data();

                my $dataset_info = {
                    id => $dataset_id,
                    name => $dataset_name,
                    description => $dataset_description,
                    info => $info
                };

                push @datasets, $dataset_info;
            }
        }
    }
    #print STDERR Dumper \@datasets;

    my $lt = CXGN::List::Transform->new();
    my %transform_dict = (
        'plots' => 'stock_ids_2_stocks',
        'accessions' => 'stock_ids_2_stocks',
        'traits' => 'trait_ids_2_trait_names',
        'locations' => 'locations_ids_2_location',
        'plants' => 'stock_ids_2_stocks',
        'trials' => 'project_ids_2_projects',
        'trial_types' => 'cvterm_ids_2_cvterms',
        'breeding_programs' => 'project_ids_2_projects',
        'genotyping_protocols' => 'nd_protocol_ids_2_protocols'
    );

    my $html = '<table class="table table-bordered table-hover" id="html-select-dataset-table-'.$num.'"><thead><tr><th>Select</th><th>Dataset Name</th><th>Contents</th></tr></thead><tbody>';
    foreach my $ds (@datasets) {
        $html .= '<tr><td><input type="checkbox" name="'.$checkbox_name.'" value="'.$ds->{id}.'"></td><td>'.$ds->{name}.'</td><td>';

        $html .= '<table class="table-bordered"><thead><tr>';
        foreach my $cat (@{$ds->{info}->{category_order}}) {
            $html .= '<th>'.ucfirst($cat).'</th>';
        }
        $html .= '</tr></thead><tbody><tr>';
        foreach my $cat (@{$ds->{info}->{category_order}}) {
            my $ids = $ds->{info}->{categories}->{$cat};

            my @items;
            if (exists($transform_dict{$cat})) {
                my $transform = $lt->transform($schema, $transform_dict{$cat}, $ids);
                @items = @{$transform->{transform}};
            }
            else {
		if (defined($ids)) {
		    @items = @$ids;
		}
            }

            $html .= "<td><div class='well well-sm'>";
            $html .= "<select class='form-control' multiple>";
            foreach (@items) {
                $html .= "<option value='$_' disabled>$_</option>";
            }
            $html .= "</select>";
            $html .= "</td></div>";
        }
        $html .= "</tr></tbody></table>";
        $html .= '</td></tr>';
    }

    $html .= "</tbody></table>";

    $html .= "<script>jQuery(document).ready(function() { jQuery('#html-select-dataset-table-".$num."').DataTable({ 'lengthMenu': [[2, 4, 6, 8, 10, 25, 50, -1], [2, 4, 6, 8, 10, 25, 50, 'All']] }); } );</script>";

    $c->stash->{rest} = { select => $html };
}

sub get_datasets_intersect_select : Path('/ajax/html/select/datasets_intersect') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');

    my $name = $c->req->param("name");
    my $id = $c->req->param("id");
    my $names_as_values = $c->req->param("names_as_values");
    my $empty = $c->req->param("empty") || "";

    my $dataset_param = $c->req->param("param");
    my $dataset_ids = decode_json $c->req->param("dataset_ids");

    my $first_dataset_id = shift @$dataset_ids;
    my $dataset_info = CXGN::Dataset->new({people_schema => $people_schema, schema => $schema, sp_dataset_id => $first_dataset_id})->get_dataset_data();
    my $i = $dataset_info->{categories}->{$dataset_param} || [];

    my @intersect = @$i;
    foreach my $dataset_id (@$dataset_ids) {
        if ($dataset_id) {
            my $dataset_info = CXGN::Dataset->new({people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id})->get_dataset_data();
            my $j = $dataset_info->{categories}->{$dataset_param} || [];
            @intersect = intersect (@intersect, @$j);
        }
    }
    # print STDERR Dumper @intersect;

    my $lt = CXGN::List::Transform->new();
    my %transform_dict = (
        'plots' => 'stock_ids_2_stocks',
        'accessions' => 'stock_ids_2_stocks',
        'traits' => 'trait_ids_2_trait_names',
        'locations' => 'locations_ids_2_location',
        'plants' => 'stock_ids_2_stocks',
        'trials' => 'project_ids_2_projects',
        'trial_types' => 'cvterm_ids_2_cvterms',
        'breeding_programs' => 'project_ids_2_projects',
        'genotyping_protocols' => 'nd_protocol_ids_2_protocols'
    );

    my @items;
    if (exists($transform_dict{$dataset_param})) {
        my $transform = $lt->transform($schema, $transform_dict{$dataset_param}, \@intersect);
        @items = @{$transform->{transform}};
    }

    my @result;
    my $counter = 0;
    foreach (@intersect) {
        if (!$names_as_values) {
            push @result, [$_, $items[$counter]];
        } else {
            push @result, [$items[$counter], $items[$counter]];
        }
        $counter++;
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_drone_imagery_parameter_select : Path('/ajax/html/select/drone_imagery_parameter_select') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $project_id = $c->req->param("field_trial_id");
    my $drone_run_parameter = $c->req->param("parameter");

    my $id = $c->req->param("id") || "drone_imagery_plot_polygon_select";
    my $name = $c->req->param("name") || "drone_imagery_plot_polygon_select";
    my $empty = $c->req->param("empty") || "";

    my $parameter_type_id;
    if ($drone_run_parameter eq 'plot_polygons') {
        $parameter_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    }
    elsif ($drone_run_parameter eq 'plot_polygons_separated') {
        $parameter_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_separated', 'project_property')->cvterm_id();
    }
    elsif ($drone_run_parameter eq 'image_cropping') {
        $parameter_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    }
    else {
        $c->stash->{rest} = { error => "Parameter not supported!" };
        $c->detach();
    }

    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_imagery_plot_polygons_rs = $schema->resultset("Project::Projectprop")->search({
        'me.type_id' => $parameter_type_id,
        'project_relationship_subject_projects.type_id' => $drone_run_band_project_relationship_type_id,
        'project_relationship_subject_projects_2.type_id' => $project_relationship_type_id,
        'object_project_2.project_id' => $project_id
    },{join => {'project' => {'project_relationship_subject_projects' => {'object_project' => {'project_relationship_subject_projects' => 'object_project'}}}}, '+select' => ['project.name'], '+as' => ['project_name']});

    my @result;
    while (my $r = $drone_imagery_plot_polygons_rs->next) {
        push @result, [$r->projectprop_id, $r->get_column('project_name')];
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_drone_imagery_drone_runs_with_gcps : Path('/ajax/html/select/drone_runs_with_gcps') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $id = $c->req->param("id") || "drone_imagery_drone_run_gcp_select";
    my $name = $c->req->param("name") || "drone_imagery_drone_run_gcp_select";
    my $empty = $c->req->param("empty") || "";

    my $field_trial_id = $c->req->param('field_trial_id');

    my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_ground_control_points_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_ground_control_points', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();

    my $q = "SELECT project.project_id, project.name
        FROM project
        JOIN projectprop AS gcps ON(project.project_id = gcps.project_id AND gcps.type_id=$drone_run_ground_control_points_type_id)
        JOIN projectprop AS processed ON(project.project_id = processed.project_id AND processed.type_id=$processed_cvterm_id)
        JOIN project_relationship ON(project.project_id=project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
        WHERE project_relationship.object_project_id=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($field_trial_id);

    my @result;
    while( my ($project_id, $name) = $h->fetchrow_array()) {
        push @result, [$project_id, $name];
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_drone_imagery_drone_runs : Path('/ajax/html/select/drone_runs') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $id = $c->req->param("id") || "drone_imagery_drone_run_select";
    my $name = $c->req->param("name") || "drone_imagery_drone_run_select";
    my $empty = $c->req->param("empty") || "";

    my $field_trial_id = $c->req->param('field_trial_id');

    my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();

    my $q = "SELECT project.project_id, project.name
        FROM project
        JOIN projectprop AS processed ON(project.project_id = processed.project_id AND processed.type_id=$processed_cvterm_id)
        JOIN project_relationship ON(project.project_id=project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
        WHERE project_relationship.object_project_id=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($field_trial_id);

    my @result;
    while( my ($project_id, $name) = $h->fetchrow_array()) {
        push @result, [$project_id, $name];
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_drone_imagery_plot_polygon_types : Path('/ajax/html/select/drone_imagery_plot_polygon_types') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $names_as_select = $c->req->param("names_as_select") || 0;
    my $standard_process = $c->req->param("standard_process_type") || 'minimal';

    my $id = $c->req->param("id") || "drone_imagery_plot_polygon_type_select";
    my $name = $c->req->param("name") || "drone_imagery_plot_polygon_type_select";
    my $empty = $c->req->param("empty") || "";

    my $plot_polygon_image_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);

    my %terms;
    while (my($type_id, $o) = each %$plot_polygon_image_types) {
        my %standard_processes = map {$_ => 1} @{$o->{standard_process}};
        if (exists($standard_processes{$standard_process})) {
            $terms{$type_id} = $o;
        }
    }

    my @result;
    foreach my $type_id (sort keys %terms) {
        my $t = $terms{$type_id};
        if ($names_as_select) {
            push @result, [$t->{name}, $t->{name}];
        } else {
            push @result, [$type_id, $t->{name}];
        }
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_micasense_aligned_raw_images : Path('/ajax/html/select/micasense_aligned_raw_images') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $drone_run_project_id = $c->req->param("drone_run_project_id");

    my $id = $c->req->param("id") || "drone_imagery_plot_polygon_type_select";
    my $name = $c->req->param("name") || "drone_imagery_plot_polygon_type_select";
    my $empty = $c->req->param("empty") || "";

    my $saved_image_stacks_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks', 'project_property')->cvterm_id();
    my $saved_micasense_stacks_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_type_id
    });
    my $saved_micasense_stacks;
    if ($saved_micasense_stacks_json) {
        $saved_micasense_stacks = decode_json $saved_micasense_stacks_json->value();
    }

    my @result;
    foreach (sort {$a <=> $b} keys %$saved_micasense_stacks) {
        my $image_ids_array = $saved_micasense_stacks->{$_};
        my @image_ids;
        foreach (@$image_ids_array) {
            push @image_ids, $_->{image_id};
        }
        my $image_ids_string = join ',', @image_ids;
        push @result, [$image_ids_string, $image_ids_string];
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_micasense_aligned_raw_images_grid : Path('/ajax/html/select/micasense_aligned_raw_images_grid') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $drone_run_project_id = $c->req->param("drone_run_project_id");

    my $id = $c->req->param("id") || "drone_imagery_micasense_stacks_grid_select";
    my $name = $c->req->param("name") || "drone_imagery_micasense_stacks_grid_select";

    my $saved_image_stacks_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks', 'project_property')->cvterm_id();
    my $saved_micasense_stacks_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_type_id
    });
    my $saved_micasense_stacks;
    if ($saved_micasense_stacks_json) {
        $saved_micasense_stacks = decode_json $saved_micasense_stacks_json->value();
    }

    my $manual_plot_polygon_template_partial = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_partial', 'project_property')->cvterm_id();
    my $q = "SELECT value FROM projectprop WHERE project_id=? AND type_id=$manual_plot_polygon_template_partial;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($drone_run_project_id);

    my @result;
    my %unique_image_polygons;
    while (my ($value) = $h->fetchrow_array()) {
        if ($value) {
            my $partial_templates = decode_json $value;
            foreach my $t (@$partial_templates) {
                my $nir_image_id = $t->{image_id};
                my $polygon = $t->{stock_polygon};
                my $template_name = $t->{template_name};
                push @{$unique_image_polygons{$nir_image_id}}, {
                    template_name => $template_name,
                    stock_polygon => $polygon
                };
            }
        }
    }

    my %gps_images;
    my %longitudes;
    my %latitudes;
    foreach (sort {$a <=> $b} keys %$saved_micasense_stacks) {
        my $image_ids_array = $saved_micasense_stacks->{$_};
        my $nir_image = $image_ids_array->[3];
        my $latitude = nearest(0.00001,$nir_image->{latitude});
        my $longitude = nearest(0.00001,$nir_image->{longitude});
        $longitudes{$longitude}++;
        $latitudes{$latitude}++;
        my @stack_image_ids;
        foreach (@$image_ids_array) {
            push @stack_image_ids, $_->{image_id};
        }
        my $nir_image_id = $nir_image->{image_id};
        my @template_strings;
        my @polygons;
        if ($unique_image_polygons{$nir_image_id}) {
            foreach (@{$unique_image_polygons{$nir_image_id}}) {
                push @polygons, $_->{stock_polygon};
                push @template_strings, $_->{template_name};
            }
        }
        my $template_string = join ',', @template_strings;
        push @{$gps_images{$latitude}->{$longitude}}, {
            nir_image_id => $nir_image_id,
            image_ids => \@stack_image_ids,
            template_names => $template_string,
            polygons => \@polygons
        };
    }
    # print STDERR Dumper \%longitudes;
    # print STDERR Dumper \%latitudes;

    my $html = "<table class='table table-bordered table-hover'><thead><tr><th>Latitudes</th>";
    foreach my $lon (sort {$a <=> $b} keys %longitudes) {
        $html .= "<th>".$lon."</th>";
    }
    $html .= "</tr></thead><tbody>";
    foreach my $lat (sort {$a <=> $b} keys %latitudes) {
        $html .= "<tr><td>".$lat."</td>";
        foreach my $lon (sort {$a <=> $b} keys %longitudes) {
            $html .= "<td>";
            if ($gps_images{$lat}->{$lon}) {
                foreach my $img_id_info (@{$gps_images{$lat}->{$lon}}) {
                    $html .= "<span class='glyphicon glyphicon-picture' name='".$name."' data-image_id='".$img_id_info->{nir_image_id}."' data-image_ids='".encode_json($img_id_info->{image_ids})."' data-polygons='".uri_encode(encode_json($img_id_info->{polygons}))."' ></span>";
                    if ($img_id_info->{template_names}) {
                        $html .= "Templates: ".$img_id_info->{template_names};
                    }
                }
            }
            $html .= "</td>";
        }
        $html .= "</tr>";
    }
    $html .= "</tbody></table>";

    $c->stash->{rest} = { select => $html };
}

sub get_plot_polygon_templates_partial : Path('/ajax/html/select/plot_polygon_templates_partial') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $drone_run_project_id = $c->req->param("drone_run_project_id");

    my $id = $c->req->param("id") || "drone_imagery_plot_polygon_template_partial_type_select";
    my $name = $c->req->param("name") || "drone_imagery_plot_polygon_template_partial_type_select";
    my $empty = $c->req->param("empty") || "";

    my $manual_plot_polygon_template_partial = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_partial', 'project_property')->cvterm_id();
    my $q = "SELECT value FROM projectprop WHERE project_id=? AND type_id=$manual_plot_polygon_template_partial;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($drone_run_project_id);

    my @result;
    my %unique_results;
    while (my ($value) = $h->fetchrow_array()) {
        if ($value) {
            my $partial_templates = decode_json $value;
            foreach my $t (@$partial_templates) {
                my $image_id = $t->{image_id};
                my $polygon = $t->{polygon};
                my $template_name = $t->{template_name};
                $unique_results{$template_name.": ".scalar(keys %$polygon)." Plots"} = uri_encode(encode_json($polygon));
            }
        }
    }

    while (my ($k, $v) = each %unique_results) {
        push @result, [$v, $k];
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_plot_image_sizes : Path('/ajax/html/select/plot_image_sizes') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $drone_run_project_id = $c->req->param("drone_run_project_id");

    my $id = $c->req->param("id") || "drone_imagery_plot_polygon_type_select";
    my $name = $c->req->param("name") || "drone_imagery_plot_polygon_type_select";
    my $empty = $c->req->param("empty") || "";

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$drone_run_project_id],
    });
    my ($result, $total_count) = $images_search->search();

    my @result;
    my %unique_sizes;
    foreach (@$result) {
        my $image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        my $image_url = $image->get_image_url('original_converted');
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my @size = imgsize($image_fullpath);
        my $str = join ',', @size;
        $unique_sizes{$str} = \@size;
    }

    while (my($str, $size) = each %unique_sizes) {
        push @result, [$str, $size->[0]." width and ".$size->[1]." height"];
    }

    if ($empty) {
        unshift @result, ['', "Select one"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub get_drone_imagery_drone_run_band : Path('/ajax/html/select/drone_imagery_drone_run_band') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $drone_run_project_id = $c->req->param("drone_run_project_id");

    my $id = $c->req->param("id") || "drone_imagery_drone_run_band_select";
    my $name = $c->req->param("name") || "drone_imagery_drone_run_band_select";
    my $empty = $c->req->param("empty") || "";

    my $drone_run_band_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_imagery_drone_run_bands_rs = $schema->resultset("Project::Project")->search({
        'project_relationship_subject_projects.type_id' => $drone_run_band_project_relationship_type_id,
        'object_project.project_id' => $drone_run_project_id
    },{join => {'project_relationship_subject_projects' => 'object_project' }});

    my @result;
    while (my $r = $drone_imagery_drone_run_bands_rs->next) {
        push @result, [$r->project_id, $r->name];
    }

    if ($empty) {
        unshift @result, ['', "Select a drone run band"];
    }

    my $html = simple_selectbox_html(
        name => $name,
        id => $id,
        choices => \@result,
    );
    $c->stash->{rest} = { select => $html };
}

sub _clean_inputs {
	no warnings 'uninitialized';
	my $params = shift;
	foreach (keys %$params){
		my $values = $params->{$_};
		my $ret_val;
		if (ref \$values eq 'SCALAR'){
			push @$ret_val, $values;
		} elsif (ref $values eq 'ARRAY'){
			$ret_val = $values;
		} else {
			die "Input is not a scalar or an arrayref\n";
		}
		@$ret_val = grep {$_ ne undef} @$ret_val;
		@$ret_val = grep {$_ ne ''} @$ret_val;
        $_ =~ s/\[\]$//; #ajax POST with arrays adds [] to the end of the name e.g. germplasmName[]. since all inputs are arrays now we can remove the [].
		$params->{$_} = $ret_val;
	}
	return $params;
}

1;
