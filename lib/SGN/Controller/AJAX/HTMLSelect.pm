
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

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
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
        my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
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

    my @trials;
    foreach my $project (@$projects) {
      my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$field_trials) {
          push @trials, $_;
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

    my (@field_trials, @crossing_trials, @genotyping_trials) = [];
    foreach my $project (@$projects) {
      my ($field_trials, $crossing_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($project->[0]);
      foreach (@$field_trials) {
          push @field_trials, $_;
      }
      foreach (@$crossing_trials) {
          push @crossing_trials, $_;
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
    push @choices, '__Lists';
    foreach my $item (@$lists) {
        push @choices, [@$item[0], @$item[1]];
    }
    push @choices, '__Public Lists';
    foreach my $item (@$public_lists) {
        push @choices, [@$item[0], @$item[1]];
    }
    # push @choices, '__Crossing Trials';
    # @crossing_trials = sort { $a->[1] cmp $b->[1] } @crossing_trials;
    # foreach my $trial (@crossing_trials) {
    #     push @choices, $trial;
    # }
    #
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
    my $offset = $c->req->param('seedlot_offset') ? $c->req->param('seedlot_offset') : '';
    my $limit = $c->req->param('seedlot_limit') ? $c->req->param('seedlot_limit') : '';
    my $search_seedlot_name = $c->req->param('seedlot_name') ? $c->req->param('seedlot_name') : '';
    my $search_breeding_program_name = $c->req->param('seedlot_breeding_program_name') ? $c->req->param('seedlot_breeding_program_name') : '';
    my $search_location = $c->req->param('seedlot_location') ? $c->req->param('seedlot_location') : '';
    my $search_amount = $c->req->param('seedlot_amount') ? $c->req->param('seedlot_amount') : '';
    my $search_weight = $c->req->param('seedlot_weight') ? $c->req->param('seedlot_weight') : '';
    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $c->dbic_schema("Bio::Chado::Schema", "sgn_chado"),
        $c->dbic_schema("CXGN::People::Schema"),
        $c->dbic_schema("CXGN::Phenome::Schema"),
        $offset,
        $limit,
        $search_seedlot_name,
        $search_breeding_program_name,
        $search_location,
        $search_amount,
        $accessions,
        $crosses,
        1,
        $search_weight
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
    my $cvprop_type_names = $c->req->param("cvprop_type_name") ? decode_json $c->req->param("cvprop_type_name") : ['trait_ontology'];
    my $use_full_trait_name = $c->req->param("use_full_trait_name") || 0;

    my $observation_variables = CXGN::BrAPI::v1::ObservationVariables->new({
        context => $c,
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
        metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
        phenome_schema=>$c->dbic_schema("CXGN::Phenome::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        page_size => 1000000,
        page => 0,
        status => []
    });

    #Using code pattern found in SGN::Controller::Ontology->onto_browser
    my $onto_root_namespaces = $c->config->{trait_variable_onto_root_namespaces};
    my @namespaces = split ", ", $onto_root_namespaces;
    foreach my $n (@namespaces) {
        $n =~ s/\s*(\w+)\s*\(.*\)/$1/g;
    }

    my $result = $observation_variables->observation_variable_ontologies({name_spaces => \@namespaces, cvprop_type_names => $cvprop_type_names});
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

sub get_traits_select : Path('/ajax/html/select/traits') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trial_ids = $c->req->param('trial_ids') || 'all';
    my $stock_id = $c->req->param('stock_id') || 'all';
    my $stock_type = $c->req->param('stock_type') ? $c->req->param('stock_type') . 's' : 'none';
    my $data_level = $c->req->param('data_level') || 'all';
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

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
		foreach (@trial_ids){
			my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
			my $traits_assayed = $trial->get_traits_assayed($data_level);
			foreach (@$traits_assayed) {
				$unique_traits_ids{$_->[0]} = [$_->[0], $_->[1]." (".$_->[2]." Phenotypes)"];
			}
		}
        @traits = values %unique_traits_ids;
	}

	@traits = sort { $a->[1] cmp $b->[1] } @traits;

    my $id = $c->req->param("id") || "html_trial_select";
    my $name = $c->req->param("name") || "html_trial_select";
	my $size = $c->req->param("size");

    my $html = simple_selectbox_html(
      multiple => 1,
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

    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my @ontology_terms;
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db using(db_id) WHERE db_id=$db_id ORDER BY cvterm.name;";
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

    my $html = '<select><option disabled="1">None</option></select>';
    my $user_id;
    if ($c->user()) {
	if ($user_id = $c->user->get_object()->get_sp_person_id()) {

	    my $datasets = CXGN::Dataset->get_datasets_by_user(
		$c->dbic_schema("CXGN::People::Schema"),
		$user_id);

#	    print STDERR "Retrieved datasets: ".Dumper($datasets);

	    $html = simple_selectbox_html(
		name => 'available_datasets',
		id => 'available_datasets',
		choices => $datasets,
		);

	}
    }
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
    if ($drone_run_parameter eq 'image_cropping') {
        $parameter_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
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
