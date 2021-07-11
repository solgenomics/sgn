=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#

=cut


package SGN::Controller::solGS::Search;

use Moose;
use namespace::autoclean;

use Algorithm::Combinatorics qw /combinations/;
use Array::Utils qw(:all);
use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;
use File::Copy;
use File::Basename;
use JSON;
use List::MoreUtils qw /uniq/;
use Try::Tiny;


BEGIN { extends 'Catalyst::Controller' }



sub solgs : Path('/solgs'){
    my ($self, $c) = @_;
    $c->forward('search');
}


sub solgs_breeder_search :Path('/solgs/breeder_search') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{referer}  = $c->req->referer();
    $c->stash->{template} = '/solgs/breeder_search_solgs.mas';
}

sub solgs_login_message :Path('/solgs/login/message') Args(0) {
    my ($self, $c) = @_;

    my $page = $c->req->param('page');

    my $msg = "This is a private data. If you are the owner, "
	. "please <a href=\"/user/login?goto_url=$page\">login</a> to view it.";

    $c->controller('solGS::Utils')->generic_message($c, $msg);

    $c->stash->{template} = "/generic_message.mas";

}


sub search : Path('/solgs/search') Args() {
    my ($self, $c) = @_;

    # $self->gs_traits_index($c);
    # my $gs_traits_index = $c->stash->{gs_traits_index};

    $c->stash(template => $c->controller('solGS::Files')->template('/search/solgs.mas'),
	      # gs_traits_index => $gs_traits_index,
          );

}


sub search_trials : Path('/solgs/search/trials') Args() {
    my ($self, $c) = @_;

    my $show_result = $c->req->param('show_result');

    my $limit = $show_result =~ /all/ ? undef : 10;

    my $projects_ids = $c->model('solGS::solGS')->all_gs_projects($limit);

    my $ret->{status} = 'failed';
    my $formatted_trials = [];

    if (@$projects_ids)
    {
    	my $projects_rs = $c->model('solGS::solGS')->project_details([$projects_ids]);

    	$self->get_projects_details($c, $projects_rs);
    	my $projects = $c->stash->{projects_details};

    	$self->format_gs_projects($c, $projects);
    	$formatted_trials = $c->stash->{formatted_gs_projects};

    	$ret->{status} = 'success';
    }

    $ret->{trials}   = $formatted_trials;
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub search_trials_trait : Path('/solgs/search/trials/trait') Args() {
    my ($self, $c, $trait_id, $gp, $protocol_id) = @_;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    $c->stash->{genotyping_protocol_id} = $protocol_id;

    $c->stash->{template} = $c->controller('solGS::Files')->template('/search/trials/trait.mas');

}


sub show_search_result_pops : Path('/solgs/search/result/populations') Args() {
    my ($self, $c, $trait_id, $gp, $protocol_id) = @_;

    my $combine = $c->req->param('combine');
    my $page = $c->req->param('page') || 1;

    my $projects_ids = $c->model('solGS::solGS')->search_trait_trials($trait_id, $protocol_id);

    my $ret->{status} = 'failed';
    my $formatted_projects = [];

    if (@$projects_ids)
    {
	my $projects_rs  = $c->model('solGS::solGS')->project_details($projects_ids);
	my $trait        = $c->model('solGS::solGS')->trait_name($trait_id);

	$self->get_projects_details($c, $projects_rs);
	my $projects = $c->stash->{projects_details};

	$self->format_trait_gs_projects($c, $trait_id, $projects, $protocol_id);
	$formatted_projects = $c->stash->{formatted_gs_projects};

	$ret->{status} = 'success';
    }

    $ret->{trials}   = $formatted_projects;

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub search_traits : Path('/solgs/search/traits/') Args() {
    my ($self, $c, $query, $gp, $protocol_id) = @_;

    my $traits = $c->model('solGS::solGS')->search_trait($query);
    my $result = $c->model('solGS::solGS')->trait_details($traits);

    my $ret->{status} = 0;
    if ($result->first)
    {
	$ret->{status} = 1;
	$ret->{genotyping_protocol_id} = $protocol_id;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub load_acronyms: Path('/solgs/load/trait/acronyms') Args() {
    my ($self, $c) = @_;

   my $id = $c->req->param('id');
   $c->controller('solGS::solGS')->get_all_traits($c, $id);
   my $acronyms = $c->controller('solGS::solGS')->get_acronym_pairs($c, $id);

   my $ret->{acronyms}  = $acronyms;
   my $json = JSON->new();
   $ret = $json->encode($ret);

   $c->res->content_type('application/json');
   $c->res->body($ret);

}



sub gs_traits : Path('/solgs/traits') Args(1) {
    my ($self, $c, $index) = @_;

    my @traits_list;

    if ($index =~ /^\w{1}$/)
    {
    $self->traits_starting_with($c, $index);
    my $traits_gr = $c->stash->{trait_subgroup};

    foreach my $trait (@$traits_gr)
    {
    $self->hyperlink_traits($c, $trait);
    my $trait_url = $c->stash->{traits_urls};

    $c->controller('solGS::solGS')->get_trait_details($c, $trait);
    push @traits_list, [$trait_url, $c->stash->{trait_def}];
    }

    $c->stash( template    => $c->controller('solGS::Files')->template('/search/traits/list.mas'),
                   index       => $index,
                   traits_list => \@traits_list
            );
    }
    else
    {
    $c->forward('search');
    }
}


sub show_search_result_traits : Path('/solgs/search/result/traits') Args() {
    my ($self, $c, $query, $gp, $protocol_id) = @_;

    my $traits = $c->model('solGS::solGS')->search_trait($query);
    my $result    = $c->model('solGS::solGS')->trait_details($traits);

    my @rows;
    while (my $row = $result->next)
    {
        my $id   = $row->cvterm_id;
        my $name = $row->name;
        my $def  = $row->definition;

        push @rows, [ qq |<a href="/solgs/search/trials/trait/$id/gp/$protocol_id"  onclick="solGS.waitPage()">$name</a>|, $def];
    }

    if (@rows)
    {
	$c->stash(template   => $c->controller('solGS::Files')->template('/search/result/traits.mas'),
		  result     => \@rows,
		  query      => $query,
		  genotyping_protocol_id => $protocol_id
	    );
    }

}


sub check_genotype_data_population :Path('/solgs/check/genotype/data/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;
     my $ret->{has_genotype} = $self->check_population_has_genotype($c);

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_phenotype_data_population :Path('/solgs/check/phenotype/data/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;
    my $ret->{has_phenotype} = $self->check_population_has_phenotype($c);

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_population_exists :Path('/solgs/check/population/exists/') Args(0) {
    my ($self, $c) = @_;

    my $name = $c->req->param('name');

    my $rs = $c->model("solGS::solGS")->project_details_by_name($name);

    my @pop_ids;
    while (my $row = $rs->next)
    {
        push @pop_ids, $row->id;
        my $id =  $row->id;
    }

    my $ret->{population_ids} = \@pop_ids;
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_training_population :Path('/solgs/check/training/population/') Args() {
    my ($self, $c) = @_;

    my @pop_ids = $c->req->param('population_ids[]');
    my $protocol_id = $c->req->param('genotyping_protocol_id');

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $protocol_id = $c->stash->{genotyping_protocol_id};

    my @gs_pop_ids;

    foreach my $pop_id (@pop_ids)
    {
        $c->stash->{pop_id} = $pop_id;
        $c->stash->{training_pop_id} = $pop_id;

        my $is_training_pop = $self->check_population_is_training_population($c, $pop_id, $protocol_id);

        if ($is_training_pop)
        {
            push @gs_pop_ids, $pop_id;
        }
    }

	my $pr_rs = $c->model('solGS::solGS')->project_details(\@gs_pop_ids);
	$self->projects_links($c, $pr_rs);
	my $training_pop_data = $c->stash->{projects_pages};

    my $ret->{is_training_population} =  1 if @gs_pop_ids;
    $ret->{training_pop_data} = $training_pop_data;
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub search_selection_pops :Path('/solgs/search/selection/populations/') {
    my ($self, $c, $tr_pop_id) = @_;

    $c->stash->{training_pop_id} = $tr_pop_id;

    $self->search_all_relevant_selection_pops($c, $tr_pop_id);
    my $selection_pops_list = $c->stash->{all_relevant_selection_pops};

    my $ret->{selection_pops_list} = 0;
    if ($selection_pops_list)
    {
	$ret->{data} = $selection_pops_list;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_selection_population_relevance :Path('/solgs/check/selection/population/relevance') Args() {
    my ($self, $c) = @_;

    my $training_pop_id    = $c->req->param('training_pop_id');
    my $selection_pop_name = $c->req->param('selection_pop_name');
    my $trait_id           = $c->req->param('trait_id');
    my $protocol_id        = $c->req->param('genotyping_protocol_id');

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
	$c->stash->{trait_id} = $trait_id;

    my $referer = $c->req->referer;

    if ($referer =~ /combined\//)
    {
	$c->stash->{data_set_type} = 'combined populations';
	$c->stash->{combo_pops_id} = $training_pop_id;
    }

    my $pr_rs = $c->model("solGS::solGS")->project_details_by_exact_name($selection_pop_name);

    my $selection_pop_id;
    while (my $row = $pr_rs->next) {
	$selection_pop_id = $row->project_id;
    }

    my $ret = {};
    my $similarity = 0;
    if ($selection_pop_id !~ /$training_pop_id/)
    {
	    my $has_genotype;
    	if ($selection_pop_id)
    	{
    	    $has_genotype = $self->check_population_has_genotype($c, $selection_pop_id, $protocol_id);
    	}

    	if ($has_genotype)
    	{
	    # $c->controller('solGS::Files')->genotype_file_name($c, $selection_pop_id, $protocol_id);
	    # my $selection_geno_file = $c->stash->{genotype_file_name};
        #
	    # if (!-s $selection_geno_file)
	    # {
		# 	# $c->controller('solGS::solGS')->first_stock_genotype_data($c, $selection_pop_id, $protocol_id);
        #
		# 	$c->controller('solGS::Files')->first_stock_genotype_file($c, $selection_pop_id, $protocol_id);
		# 	$selection_geno_file = $c->stash->{first_stock_genotype_file};
	    # }

	    # $c->controller('solGS::Files')->first_stock_genotype_file($c, $selection_pop_id, $protocol_id);
	    # my $selection_geno_file = $c->stash->{first_stock_genotype_file};

	    # $c->controller('solGS::Files')->genotype_file_name($c, $training_pop_id, $protocol_id);
	    # my $training_geno_file = $c->stash->{genotype_file_name};

	    $similarity = 1;  #$self->compare_marker_set_similarity([$selection_geno_file, $training_geno_file]);
	   }

    	my $selection_pop_data;
    	unless ($similarity < 0.5 )
    	{
    	    $c->stash->{training_pop_id} = $training_pop_id;
    	    $self->format_selection_pops($c, [$selection_pop_id]);
    	    $selection_pop_data = $c->stash->{selection_pops_list};
    	    $self->save_selection_pops($c, [$selection_pop_id]);
    	}

    	$ret->{selection_pop_data} = $selection_pop_data;
    	$ret->{similarity}         = $similarity;
    	$ret->{has_genotype}       = $has_genotype;
    	$ret->{selection_pop_id}   = $selection_pop_id;
    }
    else
    {
	$ret->{selection_pop_id}   = $selection_pop_id;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub projects_links {
    my ($self, $c, $pr_rs) = @_;

    my $protocol_id = $c->stash->{genotyping_protocol_id};

    $self->get_projects_details($c, $pr_rs);
    my $projects  = $c->stash->{projects_details};

    my @projects_pages;
    my $update_marker_count;

    foreach my $pr_id (keys %$projects)
    {
		my $pr_name     = $projects->{$pr_id}{project_name};
		my $pr_desc     = $projects->{$pr_id}{project_desc};
		my $pr_year     = $projects->{$pr_id}{project_year};
		my $pr_location = $projects->{$pr_id}{project_location};

		my $dummy_name = $pr_name =~ /test\w*/ig;
		#my $dummy_desc = $pr_desc =~ /test\w*/ig;

		my $has_genotype = $self->check_population_has_genotype($c);

		no warnings 'uninitialized';

		unless ($dummy_name || !$pr_name )
		{
		    #$self->trial_compatibility_table($c, $has_genotype);
		    #my $match_code = $c->stash->{trial_compatibility_code};

		    my $checkbox = qq |<form> <input type="checkbox" name="project" value="$pr_id" onclick="solGS.combinedTrials.getPopIds()"/> </form> |;

		    #$match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:30px">code</div> |;

			my $args = {
	   		  'training_pop_id' => $pr_id,
	   		  'genotyping_protocol_id' => $protocol_id,
	   		  'data_set_type' => 'single population'
	   	  	};

	   	 	my $training_pop_page = $c->controller('solGS::Path')->training_page_url($args);

		    push @projects_pages, [$checkbox, qq|<a href="$training_pop_page" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|,
					   $pr_desc, $pr_location, $pr_year
			];

		}

    }

    $c->stash->{projects_pages} = \@projects_pages;
}


sub project_description {
    my ($self, $c, $pr_id) = @_;

    $c->stash->{pop_id} = $pr_id;
    $c->stash->{training_pop_id} = $pr_id;
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    if ($c->stash->{list_id})
    {
        $c->controller('solGS::List')->list_population_summary($c);
    }
    elsif ($c->stash->{dataset_id})
    {
	$c->controller('solGS::Dataset')->dataset_population_summary($c);
    }
    else
    {
        my $pr_rs = $c->model('solGS::solGS')->project_details($pr_id);

        while (my $row = $pr_rs->next)
        {
            $c->stash(project_id   => $row->id,
                      project_name => $row->name,
                      project_desc => $row->description
                );
        }

        $self->get_project_owners($c, $pr_id);
        $c->stash->{owner} = $c->stash->{project_owners};
    }

    my $markers_no = $c->controller('solGS::solGS')->get_markers_count($c, {'training_pop' => 1, 'training_pop_id' => $pr_id});
    my $stocks_no = $c->controller('solGS::solGS')->training_pop_lines_count($c, $pr_id, $protocol_id);

    $c->controller('solGS::Files')->traits_acronym_file($c, $pr_id);
    my $traits_file = $c->stash->{traits_acronym_file};
    my @traits_lines = read_file($traits_file, {binmode => ':utf8'});
    my $traits_no = scalar(@traits_lines) - 1;

    my $protocol_url = $c->controller('solGS::genotypingProtocol')->create_protocol_url($c, $protocol_id);

    $c->stash(markers_no => $markers_no,
              traits_no  => $traits_no,
              stocks_no  => $stocks_no,
	      protocol_url => $protocol_url,
        );

}


sub format_trait_gs_projects {
   my ($self, $c, $trait_id, $projects, $protocol_id) = @_;

   my @formatted_projects;
   $c->stash->{genotyping_protocol_id} = $protocol_id;

	foreach my $pr_id (keys %$projects)
   {
       my $pr_name     = $projects->{$pr_id}{project_name};
       my $pr_desc     = $projects->{$pr_id}{project_desc};
       my $pr_year     = $projects->{$pr_id}{project_year};
       my $pr_location = $projects->{$pr_id}{project_location};

	   if ($pr_location !~ /computation/i)
	  {
	       $c->stash->{pop_id} = $pr_id;
	       my $has_genotype = $self->check_population_has_genotype($c);

	       if ($has_genotype)
	       {
			   #my $trial_compatibility_file = $self->trial_compatibility_file($c);

			   #$self->trial_compatibility_table($c, $has_genotype);
			   #my $match_code = $c->stash->{trial_compatibility_code};

			   my $checkbox = qq |<form> <input  type="checkbox" name="project" value="$pr_id" onclick="solGS.combinedTrials.getPopIds()"/> </form> |;
			   #$match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;

			   my $args = {
				   	'trait_id' => $trait_id,
		   			'training_pop_id' => $pr_id,
					'genotyping_protocol_id' => $protocol_id,
					'data_set_type' => 'single population'
				};

		      	my $model_page = $c->controller('solGS::Path')->model_page_url($args);

			   push @formatted_projects, [ $checkbox, qq|<a href="$model_page" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|, $pr_desc, $pr_location, $pr_year];
	       }
	   }
   }

   $c->stash->{formatted_gs_projects} = \@formatted_projects;

}


sub format_gs_projects {
   my ($self, $c, $projects) = @_;

   my @formatted_projects;

   my $protocol_id = $c->stash->{genotyping_protocol_id};

   foreach my $pr_id (keys %$projects)
   {
       my $pr_name     = $projects->{$pr_id}{project_name};
       my $pr_desc     = $projects->{$pr_id}{project_desc};
       my $pr_year     = $projects->{$pr_id}{project_year};
       my $pr_location = $projects->{$pr_id}{project_location};

      # $c->stash->{pop_id} = $pr_id;
      # $self->check_population_has_genotype($c);
      # my $has_genotype = $c->stash->{population_has_genotype};
	  if ($pr_location !~ /computation/i)
	  {
	       my $has_genotype = $c->config->{default_genotyping_protocol};

	       if ($has_genotype)
	       {
			   my $trial_compatibility_file = $self->trial_compatibility_file($c);

			   $self->trial_compatibility_table($c, $has_genotype);
			   my $match_code = $c->stash->{trial_compatibility_code};

					   my $checkbox = qq |<form> <input  type="checkbox" name="project" value="$pr_id" onclick="solGS.combinedTrials.getPopIds()"/> </form> |;
					   $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;

			   my $args = {
		  		  'training_pop_id' => $pr_id,
		  		  'genotyping_protocol_id' => $protocol_id,
		  		  'data_set_type' => 'single population'
		  	  	};

	  	 		my $training_pop_page = $c->controller('solGS::Path')->training_page_url($args);

		   		push @formatted_projects, [ $checkbox, qq|<a href="$training_pop_page" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|, $pr_desc, $pr_location, $pr_year, $match_code];
	       }
	   }
   }

   $c->stash->{formatted_gs_projects} = \@formatted_projects;

}


sub trial_compatibility_table {
    my ($self, $c, $markers) = @_;

    $self->trial_compatibility_file($c);
    my $compatibility_file =  $c->stash->{trial_compatibility_file};

    my $color;

    if (-s $compatibility_file)
    {
        my @line =  read_file($compatibility_file, {binmode => ':utf8'});
        my  ($entry) = grep(/$markers/, @line);
        chomp($entry);

        if($entry)
        {
            ($markers, $color) = split(/\t/, $entry);
            $c->stash->{trial_compatibility_code} = $color;
        }
    }

    if (!$color)
    {
        my ($red, $blue, $green) = map { int(rand(255)) } 1..3;
        $color = 'rgb' . '(' . "$red,$blue,$green" . ')';

        my $color_code = $markers . "\t" . $color . "\n";

        $c->stash->{trial_compatibility_code} = $color;
        write_file($compatibility_file, {append => 1, binmode => ':utf8'}, $color_code);
    }
}


sub trial_compatibility_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'trial_compatibility',
                      file      => 'trial_compatibility_codes',
                      stash_key => 'trial_compatibility_file'
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub get_projects_details {
    my ($self, $c, $pr_rs) = @_;

    my ($year, $location, $pr_id, $pr_name, $pr_desc);
    my %projects_details = ();

    while (my $pr = $pr_rs->next)
    {
        $pr_id   = $pr->get_column('project_id');
		$pr_name = $pr->get_column('name');
		$pr_desc = $pr->get_column('description');

		my $pr_yr_rs = $c->model('solGS::solGS')->project_year($pr_id);

		while (my $pr = $pr_yr_rs->next)
		{
		    $year = $pr->value;
		}

		my $location = $c->model('solGS::solGS')->project_location($pr_id);

		$projects_details{$pr_id} = {
		    project_name     => $pr_name,
		    project_desc     => $pr_desc,
		    project_year     => $year,
		    project_location => $location,
		};
    }

    $c->stash->{projects_details} = \%projects_details;

}


sub list_of_prediction_pops {
    my ($self, $c, $training_pop_id) = @_;

    $c->controller('solGS::Files')->list_of_prediction_pops_file($c, $training_pop_id);
    my $pred_pops_file = $c->stash->{list_of_prediction_pops_file};

    my @pred_pops_ids = read_file($pred_pops_file, {binmode => ':utf8'});
    grep(s/\s//g, @pred_pops_ids);

    $c->stash->{selection_pops_ids} = \@pred_pops_ids;

    $self->format_selection_pops($c, \@pred_pops_ids);
    $c->stash->{list_of_prediction_pops} = $c->stash->{selection_pops_list};

}


sub check_population_is_training_population {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $pop_id = $c->stash->{pop_id} if !$pop_id;
    $c->stash->{pop_id} = $pop_id;
    $protocol_id = $c->stash->{genotyping_protocol_id} if !$protocol_id;

    my $is_gs;
    my $has_phenotype = $self->check_population_has_phenotype($c);
    my $is_computation = $self->check_saved_analysis_trial($c, $pop_id);

	if ($has_phenotype && !$is_computation)
	{
	    my $has_genotype = $self->check_population_has_genotype($c);
        $is_gs = 1 if $has_genotype;
	}

    if ($is_gs )
    {
	return 1;
    }
	else
	{
		return;
	}

}


sub check_saved_analysis_trial {
    my ($self, $c, $pop_id) = @_;

    my $location = $c->model('solGS::solGS')->project_location($pop_id);
    if ($location && $location =~ /computation/i)
    {
       return 1;
    }
    else
    {
       return;
    }

}


sub check_population_has_phenotype {
    my ($self, $c, $pop_id) = @_;

    my $pop_id = $c->stash->{pop_id} if !$pop_id;

	$c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
	my $pheno_file = $c->stash->{phenotype_file_name};

    my $has_phenotype;
	if (-s $pheno_file)
	{
        $has_phenotype = 1;
	}
    else
	{
        $has_phenotype = $c->model("solGS::solGS")->has_phenotype($pop_id);
	}

    return $has_phenotype;

}


sub check_population_has_genotype {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $pop_id = $c->stash->{pop_id} if !$pop_id;
    $protocol_id = $c->stash->{genotyping_protocol_id} if !$protocol_id;

    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    my $geno_file = $c->stash->{genotype_file_name};

    $c->controller('solGS::Files')->first_stock_genotype_file($c, $pop_id, $protocol_id);
	my $first_stock_file = $c->stash->{first_stock_genotype_file};

    my $has_genotype;

    if (-s $geno_file || -s $first_stock_file)
    {
	       $has_genotype = 1;
    }
    else
    {
		$has_genotype = $c->model('solGS::solGS')->has_genotype($pop_id, $protocol_id);
    }

    return $has_genotype;

}


sub save_selection_pops {
    my ($self, $c, $selection_pop_id) = @_;

    my $training_pop_id  = $c->stash->{training_pop_id};

    $c->controller('solGS::Files')->list_of_prediction_pops_file($c, $training_pop_id);
    my $selection_pops_file = $c->stash->{list_of_prediction_pops_file};

    my @existing_pops_ids = read_file($selection_pops_file, {binmode => ':utf8'});

    my @uniq_ids = unique(@existing_pops_ids, @$selection_pop_id);
    my $formatted_ids = join("\n", @uniq_ids);

    write_file($selection_pops_file, {binmode => ':utf8'}, $formatted_ids);

}


sub search_all_relevant_selection_pops {
    my ($self, $c, $training_pop_id) = @_;

    my @pred_pops_ids = @{$c->model('solGS::solGS')->prediction_pops($training_pop_id)};

    $self->save_selection_pops($c, \@pred_pops_ids);

    $self->format_selection_pops($c, \@pred_pops_ids);

    $c->stash->{all_relevant_selection_pops} = $c->stash->{selection_pops_list};

}


sub get_project_owners {
    my ($self, $c, $pr_id) = @_;

    my $owners = $c->model("solGS::solGS")->get_stock_owners($pr_id);
    my $owners_names;

    if ($owners)
    {
        for (my $i=0; $i < scalar(@$owners); $i++)
        {
            my $owner_name = $owners->[$i]->{'first_name'} . "\t" . $owners->[$i]->{'last_name'} if $owners->[$i];

            unless (!$owner_name)
            {
                $owners_names .= $owners_names ? ', ' . $owner_name : $owner_name;
            }
        }
    }

    $c->stash->{project_owners} = $owners_names;
}


sub format_selection_pops {
    my ($self, $c, $selection_pops_ids) = @_;

    my $training_pop_id = $c->stash->{training_pop_id};

    my @selection_pops_ids = @{$selection_pops_ids};
    my @data;

    if (@selection_pops_ids) {

        foreach my $selection_pop_id (@selection_pops_ids)
        {
          my $selection_pop_rs = $c->model('solGS::solGS')->project_details($selection_pop_id);
          my $selection_pop_link;

          while (my $row = $selection_pop_rs->next)
          {
              my $name = $row->name;
              my $desc = $row->description;

             # unless ($name =~ /test/ || $desc =~ /test/)
             # {
                  my $id_pop_name->{id}    = $selection_pop_id;
                  $id_pop_name->{name}     = $name;
                  $id_pop_name->{pop_type} = 'selection';
                  $id_pop_name             = to_json($id_pop_name);

                  # $pred_pop_link = qq | <a href="/solgs/model/$training_pop_id/prediction/$selection_pop_id"
                  #                    onclick="solGS.waitPage(this.href); return false;"><input type="hidden" value=\'$id_pop_name\'>$name</data>
                  #                    </a>
		  # 		      |;

	      $selection_pop_link = qq | <data><input type="hidden" value=\'$id_pop_name\'>$name</data>|;


	      my $pr_yr_rs = $c->model('solGS::solGS')->project_year($selection_pop_id);
	      my $project_yr;

	      while ( my $yr_r = $pr_yr_rs->next )
	      {
		  $project_yr = $yr_r->value;
	      }

	      $c->controller('solGS::Download')->selection_prediction_download_urls($c, $training_pop_id, $selection_pop_id);
	      my $download_selection = $c->stash->{selection_prediction_download};

	      push @data,  [$selection_pop_link, $desc, $project_yr, $download_selection];
          }
        }
    }

    $c->stash->{selection_pops_list} = \@data;

}


sub get_project_details {
    my ($self, $c, $pr_id) = @_;

    my $pr_rs = $c->model('solGS::solGS')->project_details($pr_id);

    while (my $row = $pr_rs->next)
    {
	$c->stash(project_id   => $row->id,
		  project_name => $row->name,
		  project_desc => $row->description
	    );
    }

}


sub compare_marker_set_similarity {
    my ($self, $marker_file_pair) = @_;

    my $file_1 = $marker_file_pair->[0];
    my $file_2 = $marker_file_pair->[1];

    my $first_markers = (read_file($marker_file_pair->[0], {binmode => ':utf8'}))[0];
    my $sec_markers   = (read_file($marker_file_pair->[1], {binmode => ':utf8'}))[0];

    my @first_geno_markers = split(/\t/, $first_markers);
    my @sec_geno_markers   = split(/\t/, $sec_markers);

    if ( @first_geno_markers && @sec_geno_markers)
    {
	my $common_markers = scalar(intersect(@first_geno_markers, @sec_geno_markers));
	my $similarity     = $common_markers / scalar(@first_geno_markers);

	return $similarity;
    }
    else
    {
	return 0;
    }

}


sub compare_genotyping_platforms {
    my ($self, $c,  $g_files) = @_;

    my $combinations = combinations($g_files, 2);
    my $combo_cnt    = combinations($g_files, 2);

    my $not_matching_pops;
    my $cnt = 0;
    my $cnt_pairs = 0;

    while ($combo_cnt->next)
    {
        $cnt_pairs++;
    }

    while (my $pair = $combinations->next)
    {
	$cnt++;
	my $similarity = $self->compare_marker_set_similarity($pair);

        unless ($similarity > 0.5 )
        {
            no warnings 'uninitialized';
            my $pop_id_1 = fileparse($pair->[0]);
            my $pop_id_2 = fileparse($pair->[1]);

            map { s/genotype_data_|\.txt//g } $pop_id_1, $pop_id_2;

            my $list_type_pop = $c->stash->{list_prediction};

            unless ($list_type_pop)
            {
                my @pop_names;
                foreach ($pop_id_1, $pop_id_2)
                {
                    my $pr_rs = $c->model('solGS::solGS')->project_details($_);

                    while (my $row = $pr_rs->next)
                    {
                        push @pop_names,  $row->name;
                    }
                }

                $not_matching_pops .= '[ ' . $pop_names[0]. ' and ' . $pop_names[1] . ' ]';
                $not_matching_pops .= ', ' if $cnt != $cnt_pairs;
            }
            # else
            # {
            #     $not_matching_pops = 'not_matching';
            # }
        }
    }

    $c->stash->{pops_with_no_genotype_match} = $not_matching_pops;

}


sub store_project_marker_count {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $marker_count = $c->stash->{marker_count};

    unless ($marker_count)
    {
	my $markers = $c->model("solGS::solGS")->get_project_genotyping_markers($pop_id);
	my @markers = split('\t', $markers);
	$marker_count = scalar(@markers);
    }

    my $genoprop = {'project_id' => $pop_id, 'marker_count' => $marker_count};
    $c->model("solGS::solGS")->set_project_genotypeprop($genoprop);

}


sub gs_traits_index {
    my ($self, $c) = @_;

    $self->all_gs_traits_list($c);
    my $all_traits = $c->stash->{all_gs_traits};
    my @all_traits =  sort{$a cmp $b} @$all_traits;

    my @indices = ('A'..'Z');
    my %traits_hash;
    my @valid_indices;

    foreach my $index (@indices)
    {
        my @index_traits;
        foreach my $trait (@all_traits)
        {
            if ($trait =~ /^$index/i)
            {
                push @index_traits, $trait;
            }
        }
        if (@index_traits)
        {
            $traits_hash{$index}=[ @index_traits ];
        }
    }

    foreach my $k ( keys(%traits_hash))
    {
	push @valid_indices, $k;
    }

    @valid_indices = sort( @valid_indices );

    my $trait_index;
    foreach my $v_i (@valid_indices)
    {
        my $url = "/solgs/traits/$v_i";
        $trait_index .= $c->controller('solGS::Path')->create_hyperlink($url, $v_i);
	unless ($v_i eq $valid_indices[-1])
        {
	    $trait_index .= " | ";
	}
    }

    $c->stash->{gs_traits_index} = $trait_index;

}


sub hyperlink_traits {
    my ($self, $c, $traits) = @_;

    if (ref($traits) eq 'ARRAY')
    {
	my @traits_urls;
	foreach my $tr (@$traits)
	{
        my $url = "/solgs/search/result/traits/$tr";
        my $trait_url = $c->controller('solGS::Path')->create_hyperlink($url, $tr);
	    push @traits_urls, [$trait_url];
	}

	$c->stash->{traits_urls} = \@traits_urls;
    }
    else
    {
    my $url = "/solgs/search/result/traits/$traits";
	$c->stash->{traits_urls} = $c->controller('solGS::Path')->create_hyperlink($url, $traits);
    }
}


sub traits_starting_with {
    my ($self, $c, $index) = @_;

    $self->all_gs_traits_list($c);
    my $all_traits = $c->stash->{all_gs_traits};

    my $trait_gr = [
        sort { $a cmp $b  }
        grep { /^$index/i }
        uniq @$all_traits
        ];

    $c->stash->{trait_subgroup} = $trait_gr;
}


sub all_gs_traits_list {
    my ($self, $c) = @_;

    # $self->trial_compatibility_file($c);
    # my $file = $c->stash->{trial_compatibility_file};

    # my $traits;
    # my $mv_name = 'all_gs_traits';
    #
    # my $matview = $c->model('solGS::solGS')->check_matview_exists($mv_name);
    #
    # if (!$matview)
    # {
    # $c->model('solGS::solGS')->materialized_view_all_gs_traits();
	# $c->model('solGS::solGS')->insert_matview_public($mv_name);
    # }
    # else
    # {
	# if (!-s $file)
	# {
    # $c->model('solGS::solGS')->refresh_materialized_view_all_gs_traits();
    # $c->model('solGS::solGS')->update_matview_public($mv_name);
	# }
    # }

    # try
    # {
        my $traits = $c->model('solGS::solGS')->all_gs_traits();
    # }
    # catch
    # {
    #
	# if ($_ =~ /materialized view \"all_gs_traits\" has not been populated/)
    #     {
    #         try
    #         {
    #             $c->model('solGS::solGS')->refresh_materialized_view_all_gs_traits();
    #             $c->model('solGS::solGS')->update_matview_public($mv_name);
    #             $traits = $c->model('solGS::solGS')->all_gs_traits();
    #         };
    #     }
    # };

    $c->stash->{all_gs_traits} = $traits;
    return $traits;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

__PACKAGE__->meta->make_immutable;

#######
1;
######
