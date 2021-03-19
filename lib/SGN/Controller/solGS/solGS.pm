package SGN::Controller::solGS::solGS;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
use Statistics::Descriptive;
use Math::Round::Var;
use Algorithm::Combinatorics qw /combinations/;
use Array::Utils qw(:all);
use CXGN::Tools::Run;
use JSON;
use Storable qw/ nstore retrieve /;
use Carp qw/ carp confess croak /;
use SGN::Controller::solGS::Utils;


BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#

#__PACKAGE__->config(namespace => '');

=head1 NAME

solGS::Controller::Root - Root Controller for solGS

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut


# sub index :Path :Args(0) {
#     my ($self, $c) = @_;
#     $c->forward('search');
# }

sub solgs : Path('/solgs'){
    my ($self, $c) = @_;
    $c->forward('search');
}


sub solgs_breeder_search :Path('/solgs/breeder_search') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{referer}  = $c->req->referer();
    $c->stash->{template} = '/solgs/breeder_search_solgs.mas';
}


sub submit :Path('/solgs/submit/intro')  Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} =  $c->controller('solGS::Files')->template('/submit/intro.mas');
}


sub solgs_login_message :Path('/solgs/login/message') Args(0) {
    my ($self, $c) = @_;

    my $page = $c->req->param('page');

    my $msg = "This is a private data. If you are the owner, "
	. "please <a href=\"/user/login?goto_url=$page\">login</a> to view it.";

    $c->controller('solGS::Utils')->generic_message($c, $msg);

}


sub search : Path('/solgs/search') Args() {
    my ($self, $c) = @_;

    $self->gs_traits_index($c);
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
	my $projects_rs = $c->model('solGS::solGS')->project_details($projects_ids);

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

	$self->check_population_has_genotype($c);
	my $has_genotype = $c->stash->{population_has_genotype};

	no warnings 'uninitialized';

	unless ($dummy_name || !$pr_name )
	{
	    #$self->trial_compatibility_table($c, $has_genotype);
	    #my $match_code = $c->stash->{trial_compatibility_code};

	    my $checkbox = qq |<form> <input type="checkbox" name="project" value="$pr_id" onclick="solGS.combinedTrials.getPopIds()"/> </form> |;

	    #$match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:30px">code</div> |;

	    push @projects_pages, [$checkbox, qq|<a href="/solgs/population/$pr_id/gp/$protocol_id" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|,
				   $pr_desc, $pr_location, $pr_year
		];


	}

    }

    $c->stash->{projects_pages} = \@projects_pages;
}


sub search_trials_trait : Path('/solgs/search/trials/trait') Args() {
    my ($self, $c, $trait_id, $gp, $protocol_id) = @_;

    $self->get_trait_details($c, $trait_id);
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
	       $self->check_population_has_genotype($c);
	       my $has_genotype = $c->stash->{population_has_genotype};

	       if ($has_genotype)
	       {
			   #my $trial_compatibility_file = $self->trial_compatibility_file($c);

			   #$self->trial_compatibility_table($c, $has_genotype);
			   #my $match_code = $c->stash->{trial_compatibility_code};

			   my $checkbox = qq |<form> <input  type="checkbox" name="project" value="$pr_id" onclick="solGS.combinedTrials.getPopIds()"/> </form> |;
			   #$match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;

			   push @formatted_projects, [ $checkbox, qq|<a href="/solgs/trait/$trait_id/population/$pr_id/gp/$protocol_id" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|, $pr_desc, $pr_location, $pr_year];
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

			   push @formatted_projects, [ $checkbox, qq|<a href="/solgs/population/$pr_id/gp/$protocol_id" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|, $pr_desc, $pr_location, $pr_year, $match_code];
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


sub population : Path('/solgs/population') Args() {
    my ($self, $c, $pop_id, $gp, $protocol_id) = @_;

    if (!$pop_id)
    {
		my $msg = "You can not access this page with out population id.";
		$c->controller('solGS::Utils')->generic_message($c, $msg);
    }

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $c->stash->{training_pop_id} = $pop_id;
    #$c->stash->{pop_id} = $pop_id;

    if ($pop_id =~ /dataset/)
    {
		$c->stash->{dataset_id} = $pop_id =~ s/\w+_//r;
    }
    elsif ($pop_id =~ /list/)
    {
		$c->stash->{list_id} = $pop_id =~ s/\w+_//r;
    }

    my $cached = $c->controller('solGS::CachedResult')->check_single_trial_training_data($c, $pop_id, $protocol_id);

    if (!$cached)
    {
	my $msg = "Cached output for this training population  does not exist anymore.\n"
	    . "Please go to <a href=\"/solgs/search/\">the search page</a>"
	    . " and create the training population data.";

	$c->controller('solGS::Utils')->generic_message($c, $msg);
    }
    else
    {
		$c->controller('solGS::Utils')->save_metadata($c);
	    $self->get_all_traits($c);

		$self->project_description($c, $pop_id);

		$c->stash->{training_pop_name} = $c->stash->{project_name};
		$c->stash->{training_pop_desc} = $c->stash->{project_desc};

	    $c->stash->{template} = $c->controller('solGS::Files')->template('/population.mas');

	    my $acronym = $self->get_acronym_pairs($c, $pop_id);
	    $c->stash->{acronym} = $acronym;
    }

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


sub get_markers_count {
    my ($self, $c, $pop_hash) = @_;

    my $filtered_geno_file;
    my $markers_cnt;

    my $protocol_id = $c->stash->{genotyping_protocol_id};

    if ($pop_hash->{training_pop})
    {
	my $training_pop_id = $pop_hash->{training_pop_id};
	$c->stash->{pop_id} = $training_pop_id;
	$c->controller('solGS::Files')->filtered_training_genotype_file($c, $training_pop_id, $protocol_id);
	$filtered_geno_file  = $c->stash->{filtered_training_genotype_file};

	if (-s $filtered_geno_file)
	{
	    my @geno_lines = read_file($filtered_geno_file, {binmode => ':utf8'});
	    $markers_cnt = scalar(split('\t', $geno_lines[0]));
	}
	else
	{
	    $c->controller('solGS::Files')->genotype_file_name($c, $training_pop_id, $protocol_id);
	    my $geno_file  = $c->stash->{genotype_file_name};

	    my  @geno_lines = read_file($geno_file, {binmode => ':utf8'});
	    $markers_cnt= scalar(split ('\t', $geno_lines[0]));
	}

    }
    elsif ($pop_hash->{selection_pop})
    {
	my $selection_pop_id = $pop_hash->{selection_pop_id};
	$c->stash->{pop_id} = $selection_pop_id;
	$c->controller('solGS::Files')->filtered_selection_genotype_file($c);
	$filtered_geno_file  = $c->stash->{filtered_selection_genotype_file};

	if (-s $filtered_geno_file)
	{
	    my @geno_lines = read_file($filtered_geno_file, {binmode => ':utf8'});
	    $markers_cnt = scalar(split('\t', $geno_lines[0]));

	}
	else
	{
	    $c->controller('solGS::Files')->genotype_file_name($c, $selection_pop_id, $protocol_id);
	    my $geno_file  = $c->stash->{genotype_file_name};

	    my @geno_lines = read_file($geno_file, {binmode => ':utf8'});
	    $markers_cnt= scalar(split ('\t', $geno_lines[0]));
	}
    }

    return $markers_cnt - 1;

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

    my $markers_no = $self->get_markers_count($c, {'training_pop' => 1, 'training_pop_id' => $pr_id});
    my $stocks_no = $self->training_pop_lines_count($c, $pr_id, $protocol_id);

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


sub predicted_lines_count {
    my ($self, $c, $args) = @_;

    my $training_pop_id = $args->{training_pop_id};
    my $selection_pop_id = $args->{selection_pop_id};
    my $trait_id = $args->{trait_id};

    my $gebvs_file;
    if (!$selection_pop_id)
    {
	$c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $trait_id);
	$gebvs_file = $c->stash->{rrblup_training_gebvs_file};
    }
    elsif ($selection_pop_id && $training_pop_id)
    {
	# my $identifier = $training_pop_id . '_' . $selection_pop_id;
	$c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
	$gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
    }

    my $geno = qx /wc -l $gebvs_file/;
    my ($geno_lines, $g_file) = split(" ", $geno);

    my $count = $geno_lines > 1 ? $geno_lines - 1 : 0;

    return $count;
}


sub training_pop_lines_count {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $c->stash->{genotyping_protocol_id} = $protocol_id;
    my $count;
    if ($c->req->path =~ /solgs\/trait\//)
    {
	my $trait_id = $c->stash->{trait_id};
    	$count = $self->predicted_lines_count($c, {'training_pop_id' => $pop_id, 'trait_id'=> $trait_id});
    }
    else
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
	my $geno_file  = $c->stash->{genotype_file_name};
	my $geno = qx /wc -l $geno_file/;
	my ($geno_lines, $g_file) = split(" ", $geno);

	$count = $geno_lines > 1 ? $geno_lines - 1 : 0;
    }

    return $count;
}


sub check_training_pop_size : Path('/solgs/check/training/pop/size') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('args');

    my $json = JSON->new();
    $args = $json->decode($args);

    my $pop_id = @{$args->{training_pop_id}}[0];
    my $type   = $args->{data_set_type};
    my $protocol_id  = $args->{genotyping_protocol_id};

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    my $count;
    if ($type =~ /single/)
    {
	$count = $self->training_pop_lines_count($c, $pop_id, $protocol_id);
    }
    elsif ($type =~ /combined/)
    {
	$c->stash->{combo_pops_id} = $pop_id;
	$count = $c->controller('solGS::combinedTrials')->count_combined_trials_lines_count($c, $pop_id, $protocol_id);
    }

    my $ret->{status} = 'failed';

    if ($count)
    {
	$ret->{status} = 'success';
	$ret->{member_count} = $count;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub selection_trait :Path('/solgs/selection/') Args() {
    my ($self, $c, $selection_pop_id,
        $model_key, $training_pop_id,
        $trait_key, $trait_id, $gp, $protocol_id) = @_;

    $self->get_trait_details($c, $trait_id);
	my $trait_abbr = $c->stash->{trait_abbr};

    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;
    $c->stash->{data_set_type} = 'single population';
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $protocol_id = $c->stash->{genotyping_protocol_id};

    # my $identifier    = $training_pop_id . '_' . $selection_pop_id;

    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
    my $gebvs_file = $c->stash->{rrblup_selection_gebvs_file};

    if (!-s $gebvs_file)
    {
    	my $model_page = qq | <a href="/solgs/trait/$trait_id/population/$training_pop_id/gp/$protocol_id">training model page</a> |;

    	my $msg = "No cached output was found for this trait.\n"
    	    . " Please go to the $model_page and run the prediction.";

	$c->controller('solGS::Utils')->generic_message($c, $msg);
    }
    else
    {
	if ($training_pop_id =~ /list/)
	{
	    $c->stash->{list_id} = $training_pop_id =~ s/\w+_//r;
	    $c->controller('solGS::List')->list_population_summary($c);
	    $c->stash->{training_pop_id} = $c->stash->{project_id};
	    $c->stash->{training_pop_name} = $c->stash->{project_name};
	    $c->stash->{training_pop_desc} = $c->stash->{project_desc};
	    $c->stash->{training_pop_owner} = $c->stash->{owner};
	}
	elsif ($training_pop_id =~ /dataset/)
	{
	    $c->stash->{dataset_id} = $training_pop_id =~ s/\w+_//r;
	    $c->controller('solGS::Dataset')->dataset_population_summary($c);
	    $c->stash->{training_pop_id} = $c->stash->{project_id};
	    $c->stash->{training_pop_name} = $c->stash->{project_name};
	    $c->stash->{training_pop_desc} = $c->stash->{project_desc};
	    $c->stash->{training_pop_owner} = $c->stash->{owner};
	}
	else
	{
	    $self->get_project_details($c, $training_pop_id);
	    $c->stash->{training_pop_id} = $c->stash->{project_id};
	    $c->stash->{training_pop_name} = $c->stash->{project_name};
	    $c->stash->{training_pop_desc} = $c->stash->{project_desc};

	    $self->get_project_owners($c, $training_pop_id);
	    $c->stash->{training_pop_owner} = $c->stash->{project_owners};
	}

	my $training_pop_name = $c->stash->{training_pop_name};
	my $model_url =  my $model_page = qq | <a href="/solgs/trait/$trait_id/population/$training_pop_id/gp/$protocol_id">$training_pop_name -- $trait_abbr</a> |;

	$c->stash->{model_page_url} = $model_url;

	if ($selection_pop_id =~ /list/)
	{
	    $c->stash->{list_id} = $selection_pop_id =~ s/\w+_//r;

	    $c->controller('solGS::List')->list_population_summary($c);
	    $c->stash->{selection_pop_id} = $c->stash->{project_id};
	    $c->stash->{selection_pop_name} = $c->stash->{project_name};
	    $c->stash->{selection_pop_desc} = $c->stash->{project_desc};
	    $c->stash->{selection_pop_owner} = $c->stash->{owner};
	}
	elsif ($selection_pop_id =~ /dataset/)
	{
	    $c->stash->{dataset_id} = $selection_pop_id =~ s/\w+_//r;
	    $c->controller('solGS::Dataset')->dataset_population_summary($c);
	    $c->stash->{selection_pop_id} = $c->stash->{project_id};
	    $c->stash->{selection_pop_name} = $c->stash->{project_name};
	    $c->stash->{selection_pop_desc} = $c->stash->{project_desc};
	    $c->stash->{selection_pop_owner} = $c->stash->{owner};
	}
	else
	{
	    $self->get_project_details($c, $selection_pop_id);
	    $c->stash->{selection_pop_id} = $c->stash->{project_id};
	    $c->stash->{selection_pop_name} = $c->stash->{project_name};
	    $c->stash->{selection_pop_desc} = $c->stash->{project_desc};

	    $self->get_project_owners($c, $selection_pop_id);
	    $c->stash->{selection_pop_owner} = $c->stash->{project_owners};
	}

	my $tr_pop_mr_cnt = $self->get_markers_count($c, {'training_pop' => 1, 'training_pop_id' => $training_pop_id});
	my $sel_pop_mr_cnt = $self->get_markers_count($c, {'selection_pop' => 1, 'selection_pop_id' => $selection_pop_id});

	my $protocol_url = $c->controller('solGS::genotypingProtocol')->create_protocol_url($c, $protocol_id);
	$c->stash->{protocol_url} = $protocol_url;

	$c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
	my $gebvs_file = $c->stash->{rrblup_selection_gebvs_file};

	my @stock_rows = read_file($gebvs_file, {binmode => ':utf8'});
	$c->stash->{selection_stocks_cnt} = scalar(@stock_rows) - 1;
	$c->stash->{training_markers_cnt} = $tr_pop_mr_cnt;
	$c->stash->{selection_markers_cnt} = $sel_pop_mr_cnt;

	my $ma_args = {'selection_pop' => 1, 'selection_pop_id' => $selection_pop_id};
	$c->stash->{selection_markers_cnt} = $self->get_markers_count($c, $ma_args);
	my $protocol_url = $c->controller('solGS::genotypingProtocol')->create_protocol_url($c, $protocol_id);
	$c->stash->{protocol_url} = $protocol_url;

	my $args = {
	    'training_pop_id' => $training_pop_id,
	    'selection_pop_id'=> $selection_pop_id,
	    'trait_id' => $trait_id
	};

	$c->stash->{selection_stocks_cnt} = $self->predicted_lines_count($c, $args);

	$self->top_blups($c, $gebvs_file);

	$c->stash->{blups_download_url} = qq | <a href="/solgs/download/prediction/model/$training_pop_id/prediction/$selection_pop_id/$trait_id/gp/$protocol_id">Download all GEBVs</a>|;

	$c->stash->{template} = $c->controller('solGS::Files')->template('/population/selection_trait.mas');
    }

}


sub build_single_trait_model {
    my ($self, $c)  = @_;

    my $trait_id =  $c->stash->{trait_id};
    $self->get_trait_details($c, $trait_id);

    $self->get_rrblup_output($c);

}


sub trait :Path('/solgs/trait') Args() {
    my ($self, $c, $trait_id, $key, $pop_id, $gp, $protocol_id) = @_;


    if ($pop_id =~ /dataset/)
    {
	$c->stash->{dataset_id} = $pop_id =~ s/\w+_//r;
    }
    elsif ($pop_id =~ /list/)
    {
	$c->stash->{list_id} = $pop_id =~ s/\w+_//r;
    }

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $c->stash->{pop_id}   = $pop_id;
    $c->stash->{training_pop_id} = $pop_id;
    $c->stash->{trait_id} = $trait_id;

	my $pop_name;
	my $pop_link;
    if ($pop_id && $trait_id)
    {
	#$c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
	#my $gebv_file = $c->stash->{rrblup_training_gebvs_file};
	$self->project_description($c, $pop_id);
	$pop_name = $c->stash->{project_name};
	$c->stash->{training_pop_name} = $pop_name;
	$c->stash->{training_pop_desc} = $c->stash->{project_desc};

	$pop_link = qq | <a href="/solgs/population/$pop_id/gp/$protocol_id">$pop_name </a>| ;

	my $cached = $c->controller('solGS::CachedResult')->check_single_trial_model_output($c, $pop_id, $trait_id, $protocol_id);

	if (!$cached)
	{
	    my $msg = "Cached output for this model does not exist anymore.\n"
		. " Please go to $pop_link and run the analysis.";

	    $c->controller('solGS::Utils')->generic_message($c, $msg);

	}
	else
	{
	    $self->get_trait_details($c, $trait_id);
	    $self->gs_modeling_files($c);

	    $c->controller('solGS::modelAccuracy')->cross_validation_stat($c, $pop_id, $c->stash->{trait_abbr});
	    $c->controller('solGS::Files')->traits_acronym_file($c, $pop_id);
	    my $acronym_file = $c->stash->{traits_acronym_file};

	    if (!-e $acronym_file || !-s $acronym_file)
	    {
		$self->get_all_traits($c);
	    }

	    $self->model_phenotype_stat($c);

		$c->stash->{training_pop_url} = $pop_link;

	    $c->stash->{template} = $c->controller('solGS::Files')->template("/population/trait.mas");
	}
    }

}


sub gs_modeling_files {
    my ($self, $c) = @_;

    $self->output_files($c);
    $self->input_files($c);
    $c->controller('solGS::modelAccuracy')->model_accuracy_report($c);
    $self->top_blups($c, $c->stash->{rrblup_training_gebvs_file});
    $c->controller('solGS::Download')->training_prediction_download_urls($c);
    $self->top_markers($c, $c->stash->{marker_effects_file});
    $self->model_parameters($c);

}


sub save_model_info_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{combo_pops_id};
    my $trait_id = $c->stash->{trait_id};
    my $trait_abbr = $c->stash->{trait_abbr};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $info = 'Name' . "\t" . 'Value' . "\n";
    $info .= 'protocol_id' . "\t" . $protocol_id . "\n";
    $info .= 'model_id' . "\t" . $pop_id . "\n";
    $info .= 'trait_abbr' . "\t" . $trait_abbr . "\n";
    $info .= 'trait_id' . "\t" . $trait_id . "\n";

    my $file = $c->controller('solGS::Files')->model_info_file($c);
    write_file($file, {binmode => ':utf8'}, $info);

}


sub input_files {
    my ($self, $c) = @_;

    if ($c->stash->{data_set_type} =~ /combined populations/i)
    {
	$c->controller('solGS::combinedTrials')->combined_pops_gs_input_files($c);
	my $input_file = $c->stash->{combined_pops_gs_input_files};
	$c->stash->{input_files} = $input_file;
    }
    else
    {
	my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
	my $protocol_id = $c->stash->{genotyping_protocol_id};

	$self->save_model_info_file($c);

	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
	my $geno_file   = $c->stash->{genotype_file_name};

	$c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
	my $pheno_file  = $c->stash->{phenotype_file_name};

	$c->controller('solGS::Files')->model_info_file($c);
	my $model_info_file  = $c->stash->{model_info_file};

	$c->controller('solGS::Files')->formatted_phenotype_file($c);
	my $formatted_phenotype_file  = $c->stash->{formatted_phenotype_file};

	my $selection_pop_id = $c->stash->{prediction_pop_id} ||$c->stash->{selection_pop_id} ;
	my ($selection_population_file, $filtered_pred_geno_file);

	if ($selection_pop_id)
	{
	    $selection_population_file = $c->stash->{selection_population_file};
	}

	my $traits_file = $c->stash->{selected_traits_file};
	no warnings 'uninitialized';

	my $input_files = join ("\t",
				$pheno_file,
				$formatted_phenotype_file,
				$geno_file,
				$traits_file,
				$model_info_file,
				$selection_population_file,
	    );

	my $name = "input_files_${pop_id}";
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	my $tempfile = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
	write_file($tempfile, {binmode => ':utf8'}, $input_files);
	$c->stash->{input_files} = $tempfile;
    }
}


sub output_files {
    my ($self, $c) = @_;

    my $training_pop_id   = $c->stash->{pop_id};
    $training_pop_id = $c->stash->{model_id} || $c->stash->{training_pop_id}  if !$training_pop_id;

    my $trait    = $c->stash->{trait_abbr};
    my $trait_id = $c->stash->{trait_id};

    $c->controller('solGS::Files')->marker_effects_file($c);
    $c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
    $c->controller('solGS::Files')->validation_file($c);
    $c->controller("solGS::Files")->model_phenodata_file($c);
    $c->controller("solGS::Files")->variance_components_file($c);
    $c->controller('solGS::Files')->relationship_matrix_file($c);
    $c->controller('solGS::Files')->relationship_matrix_adjusted_file($c);
    $c->controller('solGS::Files')->inbreeding_coefficients_file($c);
    $c->controller('solGS::Files')->average_kinship_file($c);
    $c->controller('solGS::Files')->filtered_training_genotype_file($c);

    my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};


    no warnings 'uninitialized';

    if ($selection_pop_id)
    {
	# my $identifier    = $pop_id . '_' . $selection_pop_id;
        $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c,$training_pop_id, $selection_pop_id, $trait_id);
    }

    my $file_list = join ("\t",
                          $c->stash->{rrblup_training_gebvs_file},
                          $c->stash->{marker_effects_file},
                          $c->stash->{validation_file},
                          $c->stash->{model_phenodata_file},
                          $c->stash->{selected_traits_gebv_file},
                          $c->stash->{variance_components_file},
			  $c->stash->{relationship_matrix_table_file},
			  $c->stash->{relationship_matrix_adjusted_table_file},
			  $c->stash->{inbreeding_coefficients_file},
			  $c->stash->{average_kinship_file},
			  $c->stash->{relationship_matrix_json_file},
			  $c->stash->{relationship_matrix_adjusted_json_file},
			  $c->stash->{filtered_training_genotype_file},
                          $c->stash->{rrblup_selection_gebvs_file}
        );

    my $name = "output_files_${trait}_${training_pop_id}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $tempfile = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $file_list);

    $c->stash->{output_files} = $tempfile;

}


sub top_markers {
    my ($self, $c, $markers_file) = @_;

    $c->stash->{top_marker_effects} = $c->controller('solGS::Utils')->top_10($markers_file);
}


sub top_blups {
    my ($self, $c, $gebv_file) = @_;

    $c->stash->{top_blups} = $c->controller('solGS::Utils')->top_10($gebv_file);
}


sub predict_selection_pop_single_trait {
    my ($self, $c) = @_;

    if ($c->stash->{data_set_type} =~ /single population/)
    {
	$self->predict_selection_pop_single_pop_model($c)
    }
    else
    {
	$c->controller('solGS::combinedTrials')->predict_selection_pop_combined_pops_model($c);
    }

}


sub predict_selection_pop_multi_traits {
    my ($self, $c) = @_;

    my $data_set_type    = $c->stash->{data_set_type};
    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $protocol_id      = $c->stash->{genotyping_protocol_id};

    $c->stash->{pop_id} = $training_pop_id;

    my @traits = @{$c->stash->{training_traits_ids}} if $c->stash->{training_traits_ids};

    $self->traits_with_valid_models($c);
    my @traits_with_valid_models = @{$c->stash->{traits_ids_with_valid_models}};

    $c->stash->{training_traits_ids} = \@traits_with_valid_models;

    my @unpredicted_traits;
    foreach my $trait_id (@{$c->stash->{training_traits_ids}})
    {
	# my $identifier = $training_pop_id .'_' . $selection_pop_id;
	$c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id,  $trait_id);

	push @unpredicted_traits, $trait_id if !-s $c->stash->{rrblup_selection_gebvs_file};
    }

    if (@unpredicted_traits)
    {
	$c->stash->{training_traits_ids} = \@unpredicted_traits;

	$c->controller('solGS::Files')->genotype_file_name($c, $selection_pop_id, $protocol_id);

	if (!-s $c->stash->{genotype_file_name})
	{
	    $self->get_selection_pop_query_args_file($c);
	    $c->stash->{prerequisite_jobs} = $c->stash->{selection_pop_query_args_file};
	}

	$c->controller('solGS::Files')->selection_population_file($c, $selection_pop_id, $protocol_id);

	$self->get_gs_modeling_jobs_args_file($c);
	$c->stash->{dependent_jobs} =  $c->stash->{gs_modeling_jobs_args_file};


	#$c->stash->{prerequisite_type} = 'selection_pop_download_data';

	$self->run_async($c);
    }
    else
    {
	croak "No traits to predict: $!\n";
    }

}


sub predict_selection_pop_single_pop_model {
    my ($self, $c) = @_;

    my $trait_id          = $c->stash->{trait_id};
    my $training_pop_id   = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    my $protocol_id       = $c->stash->{genotyping_protocol_id};

    $self->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    # my $identifier = $training_pop_id . '_' . $prediction_pop_id;
    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);

    my $rrblup_selection_gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
    $c->stash->{selection_pop_id} = $selection_pop_id;

    if (!-s $rrblup_selection_gebvs_file)
    {
	$c->stash->{pop_id} = $training_pop_id;
	$c->controller('solGS::Files')->phenotype_file_name($c, $training_pop_id);
	my $pheno_file = $c->stash->{phenotype_file_name};

	$c->controller('solGS::Files')->genotype_file_name($c, $training_pop_id, $protocol_id);
	my $geno_file = $c->stash->{genotype_file_name};

	$c->stash->{pheno_file} = $pheno_file;
	$c->stash->{geno_file}  = $geno_file;

	$c->controller('solGS::Files')->selection_population_file($c, $selection_pop_id, $protocol_id);

	$self->get_rrblup_output($c);
    }

}


sub selection_prediction :Path('/solgs/model') Args() {
    my ($self, $c, $training_pop_id, $pop, $selection_pop_id, $gp, $protocol_id) = @_;

    my $referer = $c->req->referer;
    my $path    = $c->req->path;
    my $base    = $c->req->base;
    $referer    =~ s/$base//;

    $c->stash->{training_pop_id}   = $training_pop_id;
    $c->stash->{model_id}          = $training_pop_id;
    $c->stash->{pop_id}            = $training_pop_id;
    $c->stash->{prediction_pop_id} = $selection_pop_id;
    $c->stash->{selection_pop_id}  = $selection_pop_id;
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    if ($referer =~ /solgs\/model\/combined\/trials\//)
    {
        my ($combo_pops_id, $trait_id) = $referer =~ m/(\d+)/g;

        $c->stash->{data_set_type}     = "combined populations";
        $c->stash->{combo_pops_id}     = $combo_pops_id;
        $c->stash->{trait_id}          = $trait_id;

	$c->controller('solGS::combinedTrials')->predict_selection_pop_combined_pops_model($c);

        $c->controller('solGS::combinedTrials')->combined_pops_summary($c);
        $self->model_phenotype_stat($c);
        $self->gs_modeling_files($c);

        $c->res->redirect("/solgs/model/combined/trials/$combo_pops_id/trait/$trait_id/gp/$protocol_id");
        $c->detach();
    }
    elsif ($referer =~ /solgs\/trait\//)
    {
        my ($trait_id, $pop_id) = $referer =~ m/(\d+)/g;

        $c->stash->{data_set_type} = "single population";
        $c->stash->{trait_id}      = $trait_id;

	$self->predict_selection_pop_single_pop_model($c);

	$self->model_phenotype_stat($c);
        $self->gs_modeling_files($c);

	$c->res->redirect("/solgs/trait/$trait_id/population/$training_pop_id/gp/$protocol_id");
	$c->detach();
    }
    elsif ($referer =~ /solgs\/models\/combined\/trials/)
    {
        $c->stash->{data_set_type}     = "combined populations";
        $c->stash->{combo_pops_id}     = $training_pop_id;

	$self->traits_with_valid_models($c);
	my @traits_abbrs = @ {$c->stash->{traits_with_valid_models}};

        foreach my $trait_abbr (@traits_abbrs)
        {
	    $c->stash->{trait_abbr} = $trait_abbr;
	    $self->get_trait_details_of_trait_abbr($c);
	    $c->controller('solGS::combinedTrials')->predict_selection_pop_combined_pops_model($c);
	}

        $c->res->redirect("/solgs/models/combined/trials/$training_pop_id/gp/$protocol_id");
        $c->detach();
    }
    elsif ($referer =~ /solgs\/traits\/all\/population\//)
    {
	$c->stash->{data_set_type}  = "single population";

	$self->predict_selection_pop_multi_traits($c);

        $c->res->redirect("/solgs/traits/all/population/$training_pop_id/gp/$protocol_id");
        $c->detach();
    }

}


sub list_predicted_selection_pops {
    my ($self, $c, $model_id) = @_;

    my $dir = $c->stash->{solgs_cache_dir};

    opendir my $dh, $dir or die "can't open $dir: $!\n";

    my  @files  =  grep { /rrblup_selection_gebvs_\w+_${model_id}_/ && -f "$dir/$_" }
    readdir($dh);

    closedir $dh;

    my @pred_pops;

    foreach (@files)
    {
        unless ($_ =~ /list/) {
            my ($model_id2, $pred_pop_id) = $_ =~ m/\d+/g;

            push @pred_pops, $pred_pop_id;
        }
    }

    @pred_pops = uniq(@pred_pops);

    $c->stash->{list_of_predicted_selection_pops} = \@pred_pops;

}


sub prediction_pop_analyzed_traits {
    my ($self, $c, $training_pop_id, $selection_pop_id) = @_;

    my @selected_analyzed_traits = @{$c->stash->{training_traits_ids}} if $c->stash->{training_traits_ids};

    no warnings 'uninitialized';

    my $dir = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir or die "can't open $dir: $!\n";

    my @files;
    my @trait_ids;
    my @trait_abbrs;
    my @selected_trait_abbrs;
    my @selected_files;

    if (@selected_analyzed_traits)
    {
	@trait_ids;

	foreach my $trait_id (@selected_analyzed_traits)
	{
	    $c->stash->{trait_id} = $trait_id;
	    $self->get_trait_details($c);
	    push @selected_trait_abbrs, $c->stash->{trait_abbr};

	    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
	    my $file = $c->stash->{rrblup_selection_gebvs_file};

	    if ( -s $c->stash->{rrblup_selection_gebvs_file})
	    {
		push @selected_files, $c->stash->{rrblup_selection_gebvs_file};
		push @trait_ids, $trait_id;
	    }
	}
    }

    @trait_abbrs = @selected_trait_abbrs if @selected_trait_abbrs;
    @files       = @selected_files if @selected_files;

    $c->stash->{prediction_pop_analyzed_traits}       = \@trait_abbrs;
    $c->stash->{prediction_pop_analyzed_traits_ids}   = \@trait_ids;
    $c->stash->{prediction_pop_analyzed_traits_files} = \@files;

}


sub model_parameters {
    my ($self, $c) = @_;

    $c->controller("solGS::Files")->variance_components_file($c);
    my $file = $c->stash->{variance_components_file};

    my $params = $c->controller('solGS::Utils')->read_file_data($file, {binmode => ':utf8'});
    $c->stash->{model_parameters} = $params;

}


sub solgs_details_trait :Path('/solgs/details/trait/') Args(1) {
    my ($self, $c, $trait_id) = @_;

    $trait_id = $c->req->param('trait_id') if !$trait_id;

    my $ret->{status} = undef;

    if ($trait_id)
    {
	$self->get_trait_details($c, $trait_id);
	$ret->{name}    = $c->stash->{trait_name};
	$ret->{def}     = $c->stash->{trait_def};
	$ret->{abbr}    = $c->stash->{trait_abbr};
	$ret->{id}      = $c->stash->{trait_id};
	$ret->{status}  = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_trait_details {
    my ($self, $c, $trait) = @_;

    $trait = $c->stash->{trait_id} if !$trait;

    die "Can't get trait details with out trait id or name: $!\n" if !$trait;

    my ($trait_name, $trait_def, $trait_id, $trait_abbr);

    if ($trait =~ /^\d+$/)
    {
	$trait = $c->model('solGS::solGS')->trait_name($trait);
    }

    if ($trait)
    {
	my $rs = $c->model('solGS::solGS')->trait_details($trait);

	while (my $row = $rs->next)
	{
	    $trait_id   = $row->id;
	    $trait_name = $row->name;
	    $trait_def  = $row->definition;
	    $trait_abbr = $c->controller('solGS::Utils')->abbreviate_term($trait_name);
	}
    }

    my $abbr = $c->controller('solGS::Utils')->abbreviate_term($trait_name);

    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;
    $c->stash->{trait_def}  = $trait_def;
    $c->stash->{trait_abbr} = $abbr;

}


sub check_selection_pops_list :Path('/solgs/check/selection/populations') Args(1) {
    my ($self, $c, $tr_pop_id) = @_;

    my @traits_ids = $c->req->param('training_traits_ids[]');
    $c->stash->{training_traits_ids} = \@traits_ids;
    $c->stash->{training_pop_id} = $tr_pop_id;
    my $protocol_id = $c->req->param('genotyping_protocol_id');

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $c->controller('solGS::Files')->list_of_prediction_pops_file($c, $tr_pop_id);
    my $pred_pops_file = $c->stash->{list_of_prediction_pops_file};

    my $ret->{result} = 0;

    if (-s $pred_pops_file)
    {
	$self->list_of_prediction_pops($c, $tr_pop_id);
	my $selection_pops_ids = $c->stash->{selection_pops_ids};
	my $formatted_selection_pops = $c->stash->{list_of_prediction_pops};

	$self->prediction_pop_analyzed_traits($c, $tr_pop_id, $selection_pops_ids->[0]);
	my $selection_pop_traits = $c->stash->{prediction_pop_analyzed_traits_ids};

	$ret->{selection_traits} = $selection_pop_traits;
	$ret->{data} = $formatted_selection_pops;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub selection_population_predicted_traits :Path('/solgs/selection/population/predicted/traits/') Args(0) {
    my ($self, $c) = @_;

    my $training_pop_id = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');

    $c->stash->{genotyping_protocol_id} = $c->req->param('genotyping_protocol_id');
    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;

    my $ret->{selection_traits} = undef;
    if ($training_pop_id && $selection_pop_id)
    {
	$self->prediction_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
	my $selection_pop_traits = $c->stash->{prediction_pop_analyzed_traits_ids};
	$ret->{selection_traits} = $selection_pop_traits;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_genotype_data_population :Path('/solgs/check/genotype/data/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;
    $self->check_population_has_genotype($c);

    my $ret->{has_genotype} = $c->stash->{population_has_genotype};
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_phenotype_data_population :Path('/solgs/check/phenotype/data/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;
    $self->check_population_has_phenotype($c);

    my $ret->{has_phenotype} = $c->stash->{population_has_phenotype};
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_population_exists :Path('/solgs/check/population/exists/') Args(0) {
    my ($self, $c) = @_;

    my $name = $c->req->param('name');

    my $rs = $c->model("solGS::solGS")->project_details_by_name($name);

    my $pop_id;
    while (my $row = $rs->next)
    {
        $pop_id =  $row->id;
    }

    my $ret->{population_id} = $pop_id;
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_training_population :Path('/solgs/check/training/population/') Args() {
    my ($self, $c, $pop_id, $gp, $protocol_id) = @_;

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $c->stash->{pop_id} = $pop_id;
    $c->stash->{training_pop_id} = $pop_id;

    my $is_training_pop = $self->check_population_is_training_population($c, $pop_id, $protocol_id);

    my $training_pop_data;
    if ($is_training_pop)
    {
	my $pr_rs = $c->model('solGS::solGS')->project_details($pop_id);
	$self->projects_links($c, $pr_rs);
	$training_pop_data = $c->stash->{projects_pages};
    }

    my $ret->{is_training_population} =  $is_training_pop;
    $ret->{training_pop_data} = $training_pop_data;
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_population_is_training_population {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;
    $protocol_id = $c->stash->{genotyping_protocol_id} if !$protocol_id;

    my $is_gs = $c->model("solGS::solGS")->get_project_type($pop_id);

    my $has_phenotype;
    my $has_genotype;

    if ($is_gs !~ /genomic selection/)
    {
	$self->check_population_has_phenotype($c);
	$has_phenotype = $c->stash->{population_has_phenotype};

	if ($has_phenotype)
	{
	    $self->check_population_has_genotype($c);
	    $has_genotype = $c->stash->{population_has_genotype};
	}
    }

    if ($is_gs || ($has_phenotype && $has_genotype))
    {
	return 1;
    }
	else
	{
		return 0;
	}

}


sub check_population_has_phenotype {
    my ($self, $c) = @_;

    my $pr_id = $c->stash->{pop_id};
    my $is_gs = $c->model("solGS::solGS")->get_project_type($pr_id);
    my $has_phenotype = 1 if $is_gs;

    if ($is_gs !~ /genomic selection/)
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $pr_id);
	my $pheno_file = $c->stash->{phenotype_file_name};

	if (!-s $pheno_file)
	{
	    $has_phenotype = $c->model("solGS::solGS")->has_phenotype($pr_id);
	}
	else
	{
	    $has_phenotype = 1;
	}
    }

    $c->stash->{population_has_phenotype} = $has_phenotype;

}


sub check_population_has_genotype {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    my $geno_file = $c->stash->{genotype_file_name};

    my $has_genotype;

    if (-s $geno_file)
    {
	$has_genotype = 1;
    }
    else
    {
	$c->controller('solGS::Files')->first_stock_genotype_file($c, $pop_id, $protocol_id);
	my $first_stock_file = $c->stash->{first_stock_genotype_file};

	$has_genotype = 1 if -s $first_stock_file;
    }

    if (!$has_genotype)
    {
		$has_genotype = $c->model('solGS::solGS')->has_genotype($pop_id, $protocol_id);
    }

    $c->stash->{population_has_genotype} = $has_genotype;

}

sub check_selection_population_relevance :Path('/solgs/check/selection/population/relevance') Args() {
    my ($self, $c) = @_;

    #my $data_set_type      = $c->req->param('data_set_type');
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

    if ($selection_pop_id !~ /$training_pop_id/)
    {
	my $has_genotype;
	if ($selection_pop_id)
	{
	    $c->stash->{pop_id} = $selection_pop_id;
	    $c->stash->{selection_pop_id} = $selection_pop_id;
	    $self->check_population_has_genotype($c);
	    $has_genotype = $c->stash->{population_has_genotype};
	}

	my $similarity;
	if ($has_genotype)
	{
	    $c->controller('solGS::Files')->genotype_file_name($c, $selection_pop_id, $protocol_id);
	    my $selection_geno_file = $c->stash->{genotype_file_name};

	    if (!-s $selection_geno_file)
	    {
		$self->first_stock_genotype_data($c, $selection_pop_id, $protocol_id);

		$c->controller('solGS::Files')->first_stock_genotype_file($c, $selection_pop_id, $protocol_id);
		$selection_geno_file = $c->stash->{first_stock_genotype_file};
	    }

	    $c->controller('solGS::Files')->genotype_file_name($c, $training_pop_id, $protocol_id);
	    my $training_geno_file = $c->stash->{genotype_file_name};

	    $similarity = $self->compare_marker_set_similarity([$selection_geno_file, $training_geno_file]);
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


sub search_all_relevant_selection_pops {
    my ($self, $c, $training_pop_id) = @_;

    my @pred_pops_ids = @{$c->model('solGS::solGS')->prediction_pops($training_pop_id)};

    $self->save_selection_pops($c, \@pred_pops_ids);

    $self->format_selection_pops($c, \@pred_pops_ids);

    $c->stash->{all_relevant_selection_pops} = $c->stash->{selection_pops_list};

}


sub format_selection_pops {
    my ($self, $c, $pred_pops_ids) = @_;

    my $training_pop_id = $c->stash->{training_pop_id};

    my @pred_pops_ids = @{$pred_pops_ids};
    my @data;

    if (@pred_pops_ids) {

        foreach my $prediction_pop_id (@pred_pops_ids)
        {
          my $pred_pop_rs = $c->model('solGS::solGS')->project_details($prediction_pop_id);
          my $pred_pop_link;

          while (my $row = $pred_pop_rs->next)
          {
              my $name = $row->name;
              my $desc = $row->description;

             # unless ($name =~ /test/ || $desc =~ /test/)
             # {
                  my $id_pop_name->{id}    = $prediction_pop_id;
                  $id_pop_name->{name}     = $name;
                  $id_pop_name->{pop_type} = 'selection';
                  $id_pop_name             = to_json($id_pop_name);

                  # $pred_pop_link = qq | <a href="/solgs/model/$training_pop_id/prediction/$prediction_pop_id"
                  #                    onclick="solGS.waitPage(this.href); return false;"><input type="hidden" value=\'$id_pop_name\'>$name</data>
                  #                    </a>
		  # 		      |;

	      $pred_pop_link = qq | <data><input type="hidden" value=\'$id_pop_name\'>$name</data>|;


	      my $pr_yr_rs = $c->model('solGS::solGS')->project_year($prediction_pop_id);
	      my $project_yr;

	      while ( my $yr_r = $pr_yr_rs->next )
	      {
		  $project_yr = $yr_r->value;
	      }

	      $c->controller('solGS::Download')->selection_prediction_download_urls($c, $training_pop_id, $prediction_pop_id);
	      my $download_prediction = $c->stash->{selection_prediction_download};

	      push @data,  [$pred_pop_link, $desc, $project_yr, $download_prediction];
          }
        }
    }

    $c->stash->{selection_pops_list} = \@data;

}


sub get_trait_details_of_trait_abbr {
    my ($self, $c) = @_;

    my $trait_abbr = $c->stash->{trait_abbr};

    my $acronym_pairs = $self->get_acronym_pairs($c, $c->stash->{training_pop_id});

    if ($acronym_pairs)
    {
	foreach my $r (@$acronym_pairs)
	{
	    if ($r->[0] eq $trait_abbr)
	    {
		my $trait_name =  $r->[1];
		$trait_name    =~ s/^\s+|\s+$//g;

		my $trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);
		$self->get_trait_details($c, $trait_id);
	    }
	}
    }

}


sub build_multiple_traits_models {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my @selected_traits =  @{$c->stash->{training_traits_ids}};
    my $trait_id = $selected_traits[0] if scalar(@selected_traits) == 1;

    my $traits;

    for (my $i = 0; $i <= $#selected_traits; $i++)
    {
	my $tr   = $c->model('solGS::solGS')->trait_name($selected_traits[$i]);
	my $abbr = $c->controller('solGS::Utils')->abbreviate_term($tr);
	$traits .= $abbr;
	$traits .= "\t" unless ($i == $#selected_traits);

    }

    my $name = "selected_traits_pop_${pop_id}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);

    write_file($file, {binmode => ':utf8'}, $traits);
    $c->stash->{selected_traits_file} = $file;

    $name     = "trait_info_${trait_id}_pop_${pop_id}";
    my $file2 = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);

    $c->stash->{trait_file} = $file2;

    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $cached = $c->controller('solGS::CachedResult')->check_single_trial_training_data($c, $pop_id, $protocol_id);

    if (!$cached)
    {
	$self->get_training_pop_data_query_job_args_file($c, [$pop_id], $protocol_id);
	$c->stash->{prerequisite_jobs} = $c->stash->{training_pop_data_query_job_args_file};
    }


    $self->get_gs_modeling_jobs_args_file($c);
    $c->stash->{dependent_jobs} =  $c->stash->{gs_modeling_jobs_args_file};
    $self->run_async($c);

}


sub all_traits_output :Path('/solgs/traits/all/population') Args() {
     my ($self, $c, $training_pop_id, $tr_txt, $traits_selection_id, $gp, $protocol_id) = @_;

     $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

     my @traits_ids;

     if ($traits_selection_id =~ /^\d+$/)
     {
	$c->controller('solGS::TraitsGebvs')->get_traits_selection_list($c, $traits_selection_id);
	@traits_ids = @{$c->stash->{traits_selection_list}} if $c->stash->{traits_selection_list};
     }

     if ($training_pop_id =~ /list/)
     {
	 $c->stash->{list_id} = $training_pop_id =~ s/list_//r;
     }

     $self->project_description($c, $training_pop_id);
     my $training_pop_name = $c->stash->{project_name};
     my $training_pop_desc = $c->stash->{project_desc};

     my $training_pop_page = qq | <a href="/solgs/population/$training_pop_id/gp/$protocol_id">$training_pop_name</a> |;

     my @select_analysed_traits;

     if(!@traits_ids)
     {
	 my $msg = "Cached output for this page does not exist anymore.\n"
	     . " Please go to $training_pop_page and run the analysis.";

	 $c->controller('solGS::Utils')->generic_message($c, $msg);
     }
     else
     {
	 my @traits_pages;
	 if (scalar(@traits_ids) == 1)
	 {
	     my $trait_id = $traits_ids[0];
	     $c->res->redirect("/solgs/trait/$trait_id/population/$training_pop_id/gp/$protocol_id");
	     $c->detach();
	 }
	 else
	 {
	     foreach my $trait_id (@traits_ids)
	     {
		 $c->stash->{trait_id} = $trait_id;
		 $c->stash->{model_id} = $training_pop_id;
		 $c->controller('solGS::modelAccuracy')->create_model_summary($c, $training_pop_id, $trait_id);
		 my $model_summary = $c->stash->{model_summary};

		 push @traits_pages, $model_summary;
	     }
	 }

	 $c->stash->{training_traits_ids} = \@traits_ids;
	 $self->analyzed_traits($c);
	 my $analyzed_traits = $c->stash->{analyzed_traits};

	 $c->stash->{trait_pages} = \@traits_pages;

	 my @training_pop_data = ([$training_pop_page, $training_pop_desc, \@traits_pages]);

	 $c->stash->{model_data} = \@training_pop_data;
	 $c->stash->{training_pop_id} = $training_pop_id;
	 $c->stash->{training_pop_name} = $training_pop_name;
	 $c->stash->{training_pop_desc} = $training_pop_desc;
	 $c->stash->{training_pop_url} = $training_pop_page;


	 $self->get_acronym_pairs($c, $training_pop_id);

	 $c->stash->{template} = '/solgs/population/multiple_traits_output.mas';
     }

}


sub traits_with_valid_models {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};

    $self->analyzed_traits($c);

    my @analyzed_traits = @{$c->stash->{analyzed_traits}};
    my @filtered_analyzed_traits;
    my @valid_traits_ids;

    foreach my $analyzed_trait (@analyzed_traits)
    {
        $c->controller('solGS::modelAccuracy')->get_model_accuracy_value($c, $pop_id, $analyzed_trait);
        my $av = $c->stash->{accuracy_value};
        if ($av && $av =~ m/\d+/ && $av > 0)
        {
            push @filtered_analyzed_traits, $analyzed_trait;


	    $c->stash->{trait_abbr} = $analyzed_trait;
	    $self->get_trait_details_of_trait_abbr($c);
	    push @valid_traits_ids, $c->stash->{trait_id};
        }
    }

    @filtered_analyzed_traits = uniq(@filtered_analyzed_traits);
    @valid_traits_ids = uniq(@valid_traits_ids);

    $c->stash->{traits_with_valid_models} = \@filtered_analyzed_traits;
    $c->stash->{traits_ids_with_valid_models} = \@valid_traits_ids;

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


sub submit_cluster_compare_trials_markers {
    my ($self, $c, $geno_files) = @_;

    $c->stash->{r_temp_file} = 'compare-trials-markers';
    $self->create_cluster_accesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;

    try
    {
        my $compare_trials_job = CXGN::Tools::Run->run_cluster_perl({

            method        => ["SGN::Controller::solGS::solGS" => "compare_genotyping_platforms"],
    	    args          => ['SGN::Context', $geno_files],
    	    load_packages => ['SGN::Controller::solGS::solGS', 'SGN::Context'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },

         });

	$c->stash->{r_job_tempdir} = $compare_trials_job->tempdir();

	$c->stash->{r_job_id} = $compare_trials_job->job_id();
	$c->stash->{cluster_job} = $compare_trials_job;

	unless ($background_job)
	{
	    $compare_trials_job->wait();
	}

    }
    catch
    {
	$status = $_;
	$status =~ s/\n at .+//s;
    };

}


sub phenotype_graph :Path('/solgs/phenotype/graph') Args(0) {
    my ($self, $c) = @_;

    my $pop_id        = $c->req->param('pop_id');
    my $trait_id      = $c->req->param('trait_id');
    my $combo_pops_id = $c->req->param('combo_pops_id');

    my $protocol_id = $c->req->param('genotyping_protocol_id');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $self->get_trait_details($c, $trait_id);

    $c->stash->{pop_id}        = $pop_id;
    $c->stash->{combo_pops_id} = $combo_pops_id;

    $c->stash->{data_set_type} = 'combined populations' if $combo_pops_id;

    $c->controller("solGS::Files")->model_phenodata_file($c);

    my $model_pheno_file = $c->{stash}->{model_phenodata_file};
    my $model_data = $c->controller("solGS::Utils")->read_file_data($model_pheno_file);

    my $ret->{status} = 'failed';

    if (@$model_data)
    {
        $ret->{status} = 'success';
        $ret->{trait_data} = $model_data;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub model_phenodata_type {
    my ($self, $c, $model_pheno_file) = @_;

    my $mean_type;
    if (-s $model_pheno_file)
    {
	my @model_data = read_file($model_pheno_file, {binmode => ':utf8'});
	$mean_type = shift(@model_data);

	if ($mean_type =~ /fixed_effects/)
	{
	    $mean_type = 'Adjusted means, fixed (genotype) effects model';
	}
	elsif ($mean_type =~ /random_effects/)
	{
	    $mean_type = 'Adjusted means, random (genotype) effects model';
	}
	else
	{
	    if ($c->req->path =~ /combined\/populations\//)
	    {
		$mean_type = 'Average of adjusted means and/or arithmetic means across trials.';
	    }
	    else
	    {
		$mean_type = 'Arithmetic means';
	    }
	}
    }

    return $mean_type;

}


#generates descriptive stat for a trait phenotype data
sub model_phenotype_stat {
    my ($self, $c) = @_;

    $c->controller("solGS::Files")->model_phenodata_file($c);
    my $model_pheno_file = $c->{stash}->{model_phenodata_file};

    my $model_data = $c->controller("solGS::Utils")->read_file_data($model_pheno_file);

    my @desc_stat;
    my $background_job = $c->stash->{background_job};

    my $pheno_type = $self->model_phenodata_type($c, $model_pheno_file);

    if ($model_data && !$background_job)
    {
	my @pheno_data;
	foreach (@$model_data)
	{
	    unless (!$_->[0])
	    {
		my $d = $_->[1];
		chomp($d);

		if ($d =~ /\d+/)
		{
		    push @pheno_data, $d;
		}
	    }
	}

	my $stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@pheno_data);

	my $min  = $stat->min;
	my $max  = $stat->max;
	my $mean = $stat->mean;
	my $med  = $stat->median;
	my $std  = $stat->standard_deviation;
	my $cnt  = scalar(@$model_data);
	my $cv   = ($std / $mean) * 100;
	my $na   = scalar(@$model_data) - scalar(@pheno_data);

	if ($na == 0) { $na = '--'; }

	my $round = Math::Round::Var->new(0.01);
	$std  = $round->round($std);
	$mean = $round->round($mean);
	$cv   = $round->round($cv);
	$cv   = $cv . '%';

	@desc_stat =  (
	    [ 'Phenotype data type', $pheno_type],
	    [ 'Total no. of genotypes', $cnt ],
	    [ 'Genotypes missing data', $na ],
	    [ 'Minimum', $min ],
	    [ 'Maximum', $max ],
	    [ 'Arithmetic mean', $mean ],
	    [ 'Median', $med ],
	    [ 'Standard deviation', $std ],
	    [ 'Coefficient of variation', $cv ]
	    );
    }
    else
    {
	@desc_stat =  ( [ 'Total no. of genotypes', 'None' ],
			[ 'Genotypes missing data', 'None' ],
			[ 'Minimum', 'None' ],
			[ 'Maximum', 'None' ],
			[ 'Arithmetic mean', 'None' ],
			[ 'Median', 'None'],
			[ 'Standard deviation', 'None' ],
			[ 'Coefficient of variation', 'None' ]
	    );

    }

    $c->stash->{descriptive_stat} = \@desc_stat;
}
#sends an array of trait gebv data to an ajax request
#with a population id and trait id parameters
sub gebv_graph :Path('/solgs/trait/gebv/graph') Args(0) {
    my ($self, $c) = @_;

    my $training_pop_id  = $c->req->param('training_pop_id');
    my $trait_id         = $c->req->param('trait_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');
    my $protocol_id      = $c->req->param('genotyping_protocol_id');

    if ($combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
	$c->stash->{data_set_type} = 'combined populations';
	$training_pop_id = $combo_pops_id;
	$c->stash->{combo_pops_id} = $combo_pops_id;
    }

    $c->stash->{pop_id} = $training_pop_id;
    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{prediction_pop_id} = $selection_pop_id;
    $c->stash->{selectiion_pop_id} = $selection_pop_id;
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $self->get_trait_details($c, $trait_id);

    my $page = $c->req->referer();
    my $gebv_file;

    if ($page =~ /solgs\/selection\//)
    {
        # my $identifier =  $training_pop_id . '_' . $selection_pop_id;
        $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
        $gebv_file = $c->stash->{rrblup_selection_gebvs_file};
    }
    else
    {
        $c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
        $gebv_file = $c->stash->{rrblup_training_gebvs_file};
    }

    my $gebv_data = $c->controller("solGS::Utils")->read_file_data($gebv_file);

    my $ret->{status} = 'failed';

    if (@$gebv_data)
    {
        $ret->{status} = 'success';
        $ret->{gebv_data} = $gebv_data;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub save_single_trial_traits {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;

    $c->controller('solGS::Files')->traits_list_file($c, $pop_id);
    my $traits_file = $c->stash->{traits_list_file};

    if (!-s $traits_file)
    {
	my $trait_names = $c->controller('solGS::Utils')->get_clean_trial_trait_names($c, $pop_id);

	$trait_names = join("\t", @$trait_names);
	write_file($traits_file, {binmode => ':utf8'}, $trait_names);
    }

}


sub get_all_traits {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;

    $c->controller('solGS::Files')->traits_list_file($c, $pop_id);
    my $traits_file = $c->stash->{traits_list_file};

    if (!-s $traits_file)
    {
	my $page = $c->req->path;
	if ($page =~ /solgs\/population\/|anova\/|correlation\// && $pop_id !~ /\D+/)
	{
	    $self->save_single_trial_traits($c, $pop_id);
	}
    }

    my $traits = read_file($traits_file, {binmode => ':utf8'});

    $c->controller('solGS::Files')->traits_acronym_file($c, $pop_id);
    my $acronym_file = $c->stash->{traits_acronym_file};

    unless (-s $acronym_file)
    {
	my @filtered_traits = split(/\t/, $traits);
	my $acronymized_traits = $c->controller('solGS::Utils')->acronymize_traits(\@filtered_traits);
	my $acronym_table = $acronymized_traits->{acronym_table};

	$self->traits_acronym_table($c, $acronym_table, $pop_id);
    }

    $self->create_trait_data($c, $pop_id);
}


sub create_trait_data {
    my ($self, $c, $pop_id) = @_;

    my $acronym_pairs = $self->get_acronym_pairs($c, $pop_id);

    if (@$acronym_pairs)
    {
	my $table = 'trait_id' . "\t" . 'trait_name' . "\t" . 'acronym' . "\n";
	foreach (@$acronym_pairs)
	{
	    my $trait_name = $_->[1];
	    $trait_name    =~ s/\n//g;

	    my $trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);

	    if ($trait_id)
	    {
		$table .= $trait_id . "\t" . $trait_name . "\t" . $_->[0] . "\n";
	    }
	}

	$c->controller('solGS::Files')->all_traits_file($c, $pop_id);
	my $traits_file =  $c->stash->{all_traits_file};
	write_file($traits_file, {binmode => ':utf8'}, $table);
    }
}


sub get_acronym_pairs {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;
    #$pop_id = $c->stash->{combo_pops_id} if !$pop_id;

    my $dir    = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir
        or die "can't open $dir: $!\n";

    no warnings 'uninitialized';

    my ($file)   =  grep(/traits_acronym_pop_${pop_id}/, readdir($dh));
    $dh->close;

    my $acronyms_file = catfile($dir, $file);

    my @acronym_pairs;
    if (-f $acronyms_file)
    {
        @acronym_pairs =  map { [ split(/\t/) ] }  read_file($acronyms_file, {binmode => ':utf8'});
        shift(@acronym_pairs); # remove header;
    }

    @acronym_pairs = sort {uc $a->[0] cmp uc $b->[0] } @acronym_pairs;

    $c->stash->{acronym} = \@acronym_pairs;

    return \@acronym_pairs;

}


sub traits_acronym_table {
    my ($self, $c, $acronym_table, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;

    if (keys %$acronym_table)
    {
	my $table = 'Acronym' . "\t" . 'Trait name' . "\n";

	foreach (keys %$acronym_table)
	{
	    $table .= $_ . "\t" . $acronym_table->{$_} . "\n";
	}

	$c->controller('solGS::Files')->traits_acronym_file($c, $pop_id);
	my $acronym_file =  $c->stash->{traits_acronym_file};

	write_file($acronym_file, {binmode => ':utf8'}, $table);
    }

}


sub analyzed_traits {
    my ($self, $c) = @_;

    my $training_pop_id = $c->stash->{model_id} || $c->stash->{training_pop_id};
    my @selected_analyzed_traits = @{$c->stash->{training_traits_ids}} if $c->stash->{training_traits_ids};

    my @traits;
    my @traits_ids;
    my @si_traits;
    my @valid_traits_files;
    my @analyzed_traits_files;

    foreach my $trait_id (@selected_analyzed_traits)
    {
	    $c->stash->{trait_id} = $trait_id;
	    $self->get_trait_details($c);
	    my $trait = $c->stash->{trait_abbr};

            $c->controller('solGS::modelAccuracy')->get_model_accuracy_value($c, $training_pop_id, $trait);
            my $av = $c->stash->{accuracy_value};

	    my $trait_file;
            if ($av && $av =~ m/\d+/ && $av > 0)
            {
		$c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $trait_id);
		$trait_file = $c->stash->{rrblup_training_gebvs_file};
		push @valid_traits_files, $trait_file;
		push @si_traits, $trait;
            }


	    push @traits, $trait;
	    push @analyzed_traits_files, $trait_file;
    }

    @traits = uniq(@traits);
    @si_traits = uniq(@si_traits);

    $c->stash->{analyzed_traits}        = \@traits;
    $c->stash->{analyzed_traits_ids}    = \@selected_analyzed_traits;
    $c->stash->{analyzed_traits_files}  = \@analyzed_traits_files;
    $c->stash->{selection_index_traits} = \@si_traits;
    $c->stash->{analyzed_valid_traits_files}  = \@valid_traits_files;
}


sub all_gs_traits_list {
    my ($self, $c) = @_;

    $self->trial_compatibility_file($c);
    my $file = $c->stash->{trial_compatibility_file};

    my $traits;
    my $mv_name = 'all_gs_traits';

    my $matview = $c->model('solGS::solGS')->check_matview_exists($mv_name);

    if (!$matview)
    {
        $c->model('solGS::solGS')->materialized_view_all_gs_traits();
	$c->model('solGS::solGS')->insert_matview_public($mv_name);
    }
    else
    {
	if (!-s $file)
	{
	    $c->model('solGS::solGS')->refresh_materialized_view_all_gs_traits();
	    $c->model('solGS::solGS')->update_matview_public($mv_name);
	}
    }

    try
    {
        $traits = $c->model('solGS::solGS')->all_gs_traits();
    }
    catch
    {

	if ($_ =~ /materialized view \"all_gs_traits\" has not been populated/)
        {
            try
            {
                $c->model('solGS::solGS')->refresh_materialized_view_all_gs_traits();
                $c->model('solGS::solGS')->update_matview_public($mv_name);
                $traits = $c->model('solGS::solGS')->all_gs_traits();
            };
        }
    };

    $c->stash->{all_gs_traits} = $traits;

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
        $trait_index .= qq | <a href=/solgs/traits/$v_i>$v_i</a> |;
	unless ($v_i eq $valid_indices[-1])
        {
	    $trait_index .= " | ";
	}
    }

    $c->stash->{gs_traits_index} = $trait_index;

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


sub hyperlink_traits {
    my ($self, $c, $traits) = @_;

    if (ref($traits) eq 'ARRAY')
    {
	my @traits_urls;
	foreach my $tr (@$traits)
	{
	    push @traits_urls, [ qq | <a href="/solgs/search/result/traits/$tr">$tr</a> | ];
	}

	$c->stash->{traits_urls} = \@traits_urls;
    }
    else
    {
	$c->stash->{traits_urls} = qq | <a href="/solgs/search/result/traits/$traits">$traits</a> |;
    }
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

	    $self->get_trait_details($c, $trait);
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


sub get_cluster_phenotype_query_job_args {
    my ($self, $c, $trials) = @_;

    my @queries;

    $c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, $trials);
    $c->stash->{phenotype_files_list} = $c->stash->{multi_pops_pheno_files};

    foreach my $trial_id (@$trials)
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $trial_id);

	if (!-s $c->stash->{phenotype_file_name})
	{
	    my $args = $self->phenotype_trial_query_args($c, $trial_id);

	    $c->stash->{r_temp_file} = "phenotype-data-query-${trial_id}";
	    $self->create_cluster_accesible_tmp_files($c);
	    my $out_temp_file = $c->stash->{out_file_temp};
	    my $err_temp_file = $c->stash->{err_file_temp};

	    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	    my $background_job = $c->stash->{background_job};

	    my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "pheno-data-args_file-${trial_id}");

	    nstore $args, $args_file
		or croak "data query script: $! serializing phenotype data query details to $args_file ";

	    my $cmd = 'mx-run solGS::queryJobs '
	    	. ' --data_type phenotype '
	    	. ' --population_type trial '
	    	. ' --args_file ' . $args_file;


	    my $config_args = {
		'temp_dir' => $temp_dir,
		'out_file' => $out_temp_file,
		'err_file' => $err_temp_file,
		'cluster_host' => 'localhost'
	    };

	    my $config = $self->create_cluster_config($c, $config_args);

	    my $job_args = {
		'cmd' => $cmd,
		'config' => $config,
		'background_job'=> $background_job,
		'temp_dir' => $temp_dir,
	    };

	    push @queries, $job_args;
	}
    }

    $c->stash->{cluster_phenotype_query_job_args} = \@queries;

}


sub get_pheno_data_query_job_args_file {
    my ($self, $c, $trials) = @_;

    $self->get_cluster_phenotype_query_job_args($c, $trials);
    my $pheno_query_args = $c->stash->{cluster_phenotype_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $pheno_query_args_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'phenotype_data_query_args_file');

    nstore $pheno_query_args, $pheno_query_args_file
	or croak "pheno  data query job : $! serializing selection pop data query details to $pheno_query_args_file";

    $c->stash->{pheno_data_query_job_args_file} = $pheno_query_args_file;
}


sub get_geno_data_query_job_args_file {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->get_cluster_genotype_query_job_args($c, $trials, $protocol_id);
    my $geno_query_args = $c->stash->{cluster_genotype_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $geno_query_args_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'genotype_data_query_args_file');

    nstore $geno_query_args, $geno_query_args_file
	or croak "geno  data query job : $! serializing selection pop data query details to $geno_query_args_file";

    $c->stash->{geno_data_query_job_args_file} = $geno_query_args_file;
}


sub submit_cluster_phenotype_query {
    my ($self, $c, $trials) = @_;

    $self->get_pheno_data_query_job_args_file($c, $trials);
    $c->stash->{dependent_jobs} =  $c->stash->{pheno_data_query_job_args_file};
    $self->run_async($c);
}


sub submit_cluster_genotype_query {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->get_geno_data_query_job_args_file($c, $trials, $protocol_id);
    $c->stash->{dependent_jobs} =  $c->stash->{geno_data_query_job_args_file};
    $self->run_async($c);
}


sub submit_cluster_training_pop_data_query {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->get_training_pop_data_query_job_args_file($c, $trials, $protocol_id);
    $c->stash->{dependent_jobs} = $c->stash->{training_pop_data_query_job_args_file};
    $self->run_async($c);
}


sub training_pop_data_query_job_args {
    my ($self, $c, $trials, $protocol_id) = @_;

    my @queries;

    foreach my $trial (@$trials)
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $trial);

	if (!-s $c->stash->{phenotype_file_name})
	{
	    $self->get_cluster_phenotype_query_job_args($c, [$trial]);
	    my $pheno_query = $c->stash->{cluster_phenotype_query_job_args};
	    push @queries, @$pheno_query if $pheno_query;
	}

	$c->controller('solGS::Files')->genotype_file_name($c, $trial, $protocol_id);

	if (!-s $c->stash->{genotype_file_name})
	{
	    $self->get_cluster_genotype_query_job_args($c, [$trial], $protocol_id);
	    my $geno_query = $c->stash->{cluster_genotype_query_job_args};
	    push @queries, @$geno_query if $geno_query;
	}
    }


    $c->stash->{training_pop_data_query_job_args} = \@queries;
}


sub get_training_pop_data_query_job_args_file {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->training_pop_data_query_job_args($c, $trials, $protocol_id);
    my $training_query_args = $c->stash->{training_pop_data_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $training_query_args_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'training_pop_data_query_args');

    nstore $training_query_args, $training_query_args_file
	or croak "training pop data query job : $! serializing selection pop data query details to $training_query_args_file";

    $c->stash->{training_pop_data_query_job_args_file} = $training_query_args_file;
}


sub get_cluster_genotype_query_job_args {
    my ($self, $c, $trials, $protocol_id) = @_;

    my @queries;

    foreach my $trial_id (@$trials)
    {
	my $geno_file;
	if ($c->stash->{check_data_exists})
	{
	    $c->controller('solGS::Files')->first_stock_genotype_file($c, $trial_id, $protocol_id);
	    $geno_file = $c->stash->{first_stock_genotype_file};
	}
	else
	{
	    $c->controller('solGS::Files')->genotype_file_name($c, $trial_id, $protocol_id);
	    $geno_file = $c->stash->{genotype_file_name};
	}

	if (!-s $geno_file)
	{
	    #my $pop_id = $args->{selection_pop_id} || $args->{selection_pop_id} || $args->{training_pop_id};
	    my $args = $self->genotype_trial_query_args($c, $trial_id, $protocol_id);

	    $c->stash->{r_temp_file} = "genotype-data-query-${trial_id}";
	    $self->create_cluster_accesible_tmp_files($c);
	    my $out_temp_file = $c->stash->{out_file_temp};
	    my $err_temp_file = $c->stash->{err_file_temp};

	    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	    my $background_job = $c->stash->{background_job};

	    my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "geno-data-args_file-${trial_id}");

	    nstore $args, $args_file
		or croak "data queryscript: $! serializing model details to $args_file ";

	    my $check_data_exists =  $c->stash->{check_data_exists} ? 1 : 0;

	    my $cmd = 'mx-run solGS::queryJobs '
	    	. ' --data_type genotype '
	    	. ' --population_type trial '
	    	. ' --args_file ' . $args_file
		. ' --check_data_exists ' . $check_data_exists;

	    my $config_args = {
		'temp_dir' => $temp_dir,
		'out_file' => $out_temp_file,
		'err_file' => $err_temp_file,
		'cluster_host' => 'localhost'
	    };

	    my $config = $self->create_cluster_config($c, $config_args);

	    my $job_args = {
		'cmd' => $cmd,
		'config' => $config,
		'background_job'=> $background_job,
		'temp_dir' => $temp_dir,
	    };

	    push @queries, $job_args;
	}
    }

    $c->stash->{cluster_genotype_query_job_args} = \@queries;
}


sub first_stock_genotype_data {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $c->stash->{check_data_exists} = 1;
    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    my $geno_file = $c->stash->{genotype_file_name};

    $c->controller('solGS::Files')->first_stock_genotype_file($c, $pop_id, $protocol_id);
    my $f_geno_file = $c->stash->{first_stock_genotype_file};

    if (!-s $geno_file && !-s $f_geno_file)
    {
	$self->submit_cluster_genotype_query($c, [$pop_id], $protocol_id);
    }
}


sub phenotype_file {
    my ($self, $c, $pop_id) = @_;

    if (!$pop_id) {
	$pop_id = $c->stash->{pop_id}
	|| $c->stash->{training_pop_id}
	|| $c->stash->{trial_id};
    }

    $c->stash->{pop_id}  = $pop_id;
    die "Population id must be provided to get the phenotype data set." if !$pop_id;
    $pop_id =~ s/combined_//;

    if ($c->stash->{list_reference} || $pop_id =~ /list/) {
	if (!$c->user) {

	    my $page = "/" . $c->req->path;

	    $c->res->redirect("/solgs/login/message?page=$page");
	    $c->detach;
	}
    }

    $c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
    my $pheno_file = $c->stash->{phenotype_file_name};

    no warnings 'uninitialized';

    unless ( -s $pheno_file)
    {
	if ($pop_id !~ /list/)
	{
	    #my $args = $self->phenotype_trial_query_args($c);
	    $self->submit_cluster_phenotype_query($c, [$pop_id]);
	}
    }

    $self->get_all_traits($c);

    $c->stash->{phenotype_file} = $pheno_file;

}


sub genotype_trial_query_args {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    my $geno_file;
    my $check_data_exists = $c->stash->{check_data_exists};

    if ($c->stash->{check_data_exists})
    {
	$c->controller('solGS::Files')->first_stock_genotype_file($c, $pop_id, $protocol_id);
	$geno_file = $c->stash->{first_stock_genotype_file};
    }
    else
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
	$geno_file = $c->stash->{genotype_file_name};
    }

    my $args = {
	'trial_id' => $pop_id,
	'genotype_file'       => $geno_file,
	'genotyping_protocol_id' => $protocol_id,
	'cache_dir'     => $c->stash->{solgs_cache_dir},
    };

    return $args;

}


sub phenotype_trial_query_args {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{pop_id} if !$pop_id;

    $c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
    my $pheno_file = $c->stash->{phenotype_file_name};

    $c->controller('solGS::Files')->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    no warnings 'uninitialized';

    $c->controller('solGS::Files')->traits_list_file($c);
    my $traits_file =  $c->stash->{traits_list_file};

    my $args = {
	'population_id'    => $pop_id,
	'phenotype_file'   => $pheno_file,
	'traits_list_file' => $traits_file,
	'metadata_file'    => $metadata_file,
    };

    return $args;
}


sub format_phenotype_dataset {
    my ($self, $data_ref, $metadata, $traits_file) = @_;

    my $data = $$data_ref;
    my @rows = split (/\n/, $data);

    my $formatted_headers = $self->format_phenotype_dataset_headers($rows[0], $metadata, $traits_file);
    $rows[0] = $formatted_headers;

    my $formatted_dataset = $self->format_phenotype_dataset_rows(\@rows);

    return $formatted_dataset;
}


sub format_phenotype_dataset_rows {
    my ($self, $data_rows) = @_;

    my $data = join("\n", @$data_rows);

    return $data;

}


sub format_phenotype_dataset_headers {
    my ($self, $all_headers, $meta_headers,  $traits_file) = @_;

    $all_headers = SGN::Controller::solGS::Utils->clean_traits($all_headers);

    my $traits = $all_headers;

    foreach my $mh (@$meta_headers) {
	$traits =~ s/($mh)//g;
    }

    write_file($traits_file, {binmode => ':utf8'}, $traits) if $traits_file && $traits_file =~ /pop_list/;

    my  @filtered_traits = split(/\t/, $traits);

    my $acronymized_traits = SGN::Controller::solGS::Utils->acronymize_traits(\@filtered_traits);
    my $acronym_table = $acronymized_traits->{acronym_table};

    my $formatted_headers;
    my @headers = split("\t", $all_headers);

    foreach my $hd (@headers)
    {
	my $acronym;
	foreach my $acr (keys %$acronym_table)
	{
	    $acronym =  $acr if $acronym_table->{$acr} =~ /$hd/;
	    last if $acronym;
	}

	$formatted_headers .= $acronym ? $acronym : $hd;
	$formatted_headers .= "\t" unless ($headers[-1] eq $hd);
    }

    return $formatted_headers;

}


sub genotype_file  {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $pop_id  = $c->stash->{pop_id} if !$pop_id;

    my $training_pop_id = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};

    $pop_id = $training_pop_id || $selection_pop_id if !$pop_id;
    die "Population id must be provided to get the genotype data set." if !$pop_id;

    if ($pop_id =~ /list/)
    {
  	if (!$c->user)
	{
	    my $path = "/" . $c->req->path;
	    $c->res->redirect("/solgs/login/message?page=$path");
	    $c->detach;
	}
    }

    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    my $geno_file = $c->stash->{genotype_file_name};

    no warnings 'uninitialized';
    unless (-s $geno_file)
    {
	my $args = $self->genotype_trial_query_args($c, $pop_id, $protocol_id);
	$self->submit_cluster_genotype_query($c, $args, $protocol_id);
    }

    $c->stash->{genotype_file} = $geno_file;

}


sub get_rrblup_output {
    my ($self, $c) = @_;

    $c->stash->{pop_id} = $c->stash->{combo_pops_id} if $c->stash->{combo_pops_id};

    my $pop_id        = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $trait_abbr    = $c->stash->{trait_abbr};
    my $trait_name    = $c->stash->{trait_name};
    my $trait_id      = $c->stash->{trait_id};

    my $data_set_type = $c->stash->{data_set_type};
    my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};

    my ($traits_file, @traits, @trait_pages);

    $c->stash->{selection_pop_id} = $selection_pop_id;
    if ($trait_id)
    {
        $self->run_rrblup_trait($c, $trait_id);
    }
    else
    {
        $traits_file = $c->stash->{selected_traits_file};
        my $content  = read_file($traits_file, {binmode => ':utf8'});

        if ($content =~ /\t/)
        {
            @traits = split(/\t/, $content);
        }
        else
        {
            push  @traits, $content;
        }

        no warnings 'uninitialized';

        foreach my $tr (@traits)
        {
            my $acronym_pairs = $self->get_acronym_pairs($c);
            my $trait_name;
            if ($acronym_pairs)
            {
                foreach my $r (@$acronym_pairs)
                {
                    if ($r->[0] eq $tr)
                    {
                        $trait_name = $r->[1];
                        $trait_name =~ s/\n//g;
                        $c->stash->{trait_name} = $trait_name;
                        $c->stash->{trait_abbr} = $r->[0];
                    }
                }
            }

	    my $trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);
            $self->run_rrblup_trait($c, $trait_id);


            push @trait_pages, [ qq | <a href="/solgs/trait/$trait_id/population/$pop_id" onclick="solGS.waitPage()">$tr</a>| ];
        }
    }

    $c->stash->{combo_pops_analysis_result} = 0;

    no warnings 'uninitialized';

    if ($data_set_type !~ /combined populations/)
    {
        if (scalar(@traits) == 1)
        {
            $self->gs_modeling_files($c);
            $c->stash->{template} = $c->controller('solGS::Files')->template('population/trait.mas');
        }

        if (scalar(@traits) > 1)
        {
            $c->stash->{model_id} = $pop_id;
            $self->analyzed_traits($c);
            $c->stash->{template}    = $c->controller('solGS::Files')->template('/population/multiple_traits_output.mas');
            $c->stash->{trait_pages} = \@trait_pages;
        }
    }
    else
    {
        $c->stash->{combo_pops_analysis_result} = 1;
    }

}


sub run_rrblup_trait {
    my ($self, $c, $trait_id) = @_;

    $trait_id = $c->stash->{trait_id} if !$trait_id;

    $c->stash->{trait_id} = $trait_id;
    $self->get_trait_details($c, $trait_id);

    my $training_pop_id = $c->stash->{training_pop_id} || $c->stash->{pop_id};
    my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};

    $self->input_files($c);
    $self->output_files($c);
    $c->stash->{r_script} = 'R/solGS/gs.r';

    my $training_pop_gebvs_file = $c->stash->{rrblup_training_gebvs_file};
    my $selection_pop_gebvs_file = $c->stash->{rrblup_selection_gebvs_file};

    if ($training_pop_id && !-s $training_pop_gebvs_file)
    {
	$self->run_r_script($c);
    }
    elsif (($selection_pop_id && !-s $selection_pop_gebvs_file))
    {

	$self->get_selection_pop_query_args_file($c);
	my $pre_req = $c->stash->{selection_pop_query_args_file};

	$self->get_gs_modeling_jobs_args_file($c);
	my $dependent_job = $c->stash->{gs_modeling_jobs_args_file};

	$c->stash->{prerequisite_jobs} = $pre_req;
	$c->stash->{dependent_jobs}  = $dependent_job;

	$self->run_async($c);
    }

}


sub create_cluster_accesible_tmp_files {
    my ($self, $c, $template) = @_;

    my $temp_file_template = $template || $c->stash->{r_temp_file};

    my $temp_dir = $c->stash->{analysis_tempfiles_dir} || $c->stash->{solgs_tempfiles_dir};

    my $in_file  = $c->controller('solGS::Files')->create_tempfile($temp_dir, "${temp_file_template}-in");
    my $out_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "${temp_file_template}-out");
    my $err_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "${temp_file_template}-err");

    $c->stash(
	in_file_temp  => $in_file,
	out_file_temp => $out_file,
	err_file_temp => $err_file,
	);

}


sub run_async {
    my ($self, $c) = @_;

    my $prerequisite_jobs  = $c->stash->{prerequisite_jobs} || 'none';
    my $background_job     = $c->stash->{background_job};
    my $dependent_jobs     = $c->stash->{dependent_jobs};

    my $temp_dir            = $c->stash->{analysis_tempfiles_dir} || $c->stash->{solgs_tempfiles_dir};

    $c->stash->{r_temp_file} = 'run-async';
    $self->create_cluster_accesible_tmp_files($c);
    my $err_temp_file = $c->stash->{err_file_temp};
    my $out_temp_file = $c->stash->{out_file_temp};

    my $referer = $c->req->referer;

    my $report_file = 'none';

    if ($background_job)
    {
	$c->stash->{async} = 1;
	$c->controller('solGS::AnalysisQueue')->get_analysis_report_job_args_file($c, 2);
	$report_file = $c->stash->{analysis_report_job_args_file};
    }

    my $config_args = {
	'temp_dir' => $temp_dir,
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file,
	'cluster_host' => 'localhost'
    };

    my $job_config = $self->create_cluster_config($c, $config_args);
    my $job_config_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'job_config_file');

    nstore $job_config, $job_config_file
	or croak "job config file: $! serializing job config to $job_config_file ";

    my $cmd = 'mx-run solGS::asyncJob'
	. ' --prerequisite_jobs '   . $prerequisite_jobs
	. ' --dependent_jobs '      . $dependent_jobs
    	. ' --analysis_report_job ' . $report_file
	. ' --config_file '         . $job_config_file;


    my $cluster_job_args = {
	'cmd' => $cmd,
	'config' => $job_config,
	'background_job'  => $background_job,
	'temp_dir'     => $temp_dir,
	'async'        => $c->stash->{async},
    };

    my $job = $self->submit_job_cluster($c, $cluster_job_args);

}


sub get_gs_r_temp_file {
    my ($self, $c) = @_;

    my $pop_id   = $c->stash->{pop_id};
    my $trait_id = $c->stash->{trait_id};

    my $data_set_type = $c->stash->{data_set_type};

    my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    $c->stash->{selection_pop_id} = $selection_pop_id;

    $pop_id = $c->stash->{combo_pops_id} if !$pop_id;
    my $identifier = $selection_pop_id ? $pop_id . '-' . $selection_pop_id : $pop_id;

    if ($data_set_type =~ /combined populations/)
    {
	my $combo_identifier = $c->stash->{combo_pops_id};
        $c->stash->{r_temp_file} = "gs-rrblup-combo-${identifier}-${trait_id}";
    }
    else
    {
       $c->stash->{r_temp_file} = "gs-rrblup-${identifier}-${trait_id}";
    }

}


sub get_selection_pop_query_args {
    my ($self, $c) = @_;

    my $selection_pop_id = $c->stash->{selection_pop_id} || $c->stash->{prediction_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $selection_pop_geno_file;
    my $pop_type;

    if ($selection_pop_id)
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $selection_pop_id, $protocol_id);
	$selection_pop_geno_file = $c->stash->{genotype_file_name};
    }

    my $genotypes_ids;
    if ($selection_pop_id =~ /list/)
    {
	$c->controller('solGS::List')->get_genotypes_list_details($c);
	$genotypes_ids = $c->stash->{genotypes_ids};
	$pop_type = 'list';
    }
    elsif ($selection_pop_id =~ /dataset/)
    {
	# $c->controller('solGS::Dataset')->get_dataset_genotypes_list($c);
	# $genotypes_ids = $c->stash->{genotypes_ids};

	$pop_type = 'dataset';
    }
    else
    {
	$pop_type = 'trial';
    }

    $c->stash->{population_type} = $pop_type;
    my $temp_file_template = "genotype-data-query-${selection_pop_id}";
    $self->create_cluster_accesible_tmp_files($c, $temp_file_template);
    my $in_file   = $c->stash->{in_file_temp};
    my $out_temp_file  = $c->stash->{out_file_temp};
    my $err_temp_file  = $c->stash->{err_file_temp};

    my $selection_pop_query_args = {
	'trial_id' => $selection_pop_id,
	'genotype_file' => $selection_pop_geno_file,
	'genotypes_ids'  => $genotypes_ids,
	'dataset_id'    => $c->stash->{dataset_id},
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file,
	'population_type' => $pop_type,
	'genotyping_protocol_id' => $protocol_id
    };

    $c->stash->{selection_pop_query_args} = $selection_pop_query_args;

}


sub get_cluster_query_job_args {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{selection_pop_id} || $c->stash->{prediction_pop_id};
    my $protocol_id =  $c->stash->{genotyping_protocol_id};

    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    my $geno_file = $c->stash->{genotype_file_name};

    my @queries;

    if (!-s $geno_file)
    {
	$c->stash->{r_temp_file} = "genotype-data-query-${pop_id}";
	$self->create_cluster_accesible_tmp_files($c);
	my $out_temp_file = $c->stash->{out_file_temp};
	my $err_temp_file = $c->stash->{err_file_temp};

	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	my $background_job = $c->stash->{background_job};

	$self->get_selection_pop_query_args($c);
	my $query_args = $c->stash->{selection_pop_query_args};
	my $genotype_file = $query_args->{genotype_file};
	my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "geno-data-args_file-${pop_id}");

	my $pop_type = $query_args->{population_type};
	my $data_type = 'genotype';

	nstore $query_args, $args_file
	    or croak "data query script: $! serializing model details to $args_file ";

	my $cmd = 'mx-run solGS::queryJobs '
	    . ' --data_type ' . $data_type
	    . ' --population_type ' . $pop_type
	    . ' --args_file ' . $args_file;

	my $config_args = {
	    'temp_dir' => $temp_dir,
	    'out_file' => $out_temp_file,
	    'err_file' => $err_temp_file,
	    'cluster_host' => 'localhost'
	};

	my $config = $self->create_cluster_config($c, $config_args);

	my $job_args = {
	    'cmd' => $cmd,
	    'config' => $config,
	    'background_job'=> $background_job,
	    'temp_dir' => $temp_dir,
	    'genotype_file' => $genotype_file
	};

	push @queries, $job_args;

    }

    $c->stash->{cluster_query_job_args} = \@queries;
}


sub get_selection_pop_query_args_file {
    my ($self, $c) = @_;

    $self->get_cluster_query_job_args($c);
    my $selection_pop_query_args = $c->stash->{cluster_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $selection_pop_query_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'selection_pop_query_args');

    nstore $selection_pop_query_args, $selection_pop_query_file
	or croak "selection pop query job : $! serializing selection pop data query details to $selection_pop_query_file";

    $c->stash->{selection_pop_query_args_file} = $selection_pop_query_file;
}


sub modeling_jobs {
    my ($self, $c) = @_;

    my $modeling_traits = $c->stash->{training_traits_ids} || [$c->stash->{trait_id}];
    my $training_pop_id = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};

    my @modeling_jobs;

    if ($modeling_traits) {

	foreach my $trait_id (@$modeling_traits)
	{
	    $c->stash->{trait_id} = $trait_id;
	    $self->get_trait_details($c);

	    $self->input_files($c);
	    $self->output_files($c);

	    my $selection_pop_gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
	    my $training_pop_gebvs_file = $c->stash->{rrblup_training_gebvs_file};

	    if (($training_pop_id && !-s $training_pop_gebvs_file) ||
		($selection_pop_id && !-s $selection_pop_gebvs_file))
	    {
		$self->get_gs_r_temp_file($c);
		$c->stash->{r_script} = 'R/solGS/gs.r';
		$self->get_cluster_r_job_args($c);

		push @modeling_jobs, $c->stash->{cluster_r_job_args};
	    }
	}
    }

    return \@modeling_jobs;
}


sub get_gs_modeling_jobs_args_file {
    my ($self, $c) = @_;

    my $modeling_jobs = [];

    if ($c->stash->{training_traits_ids})
    {
	$modeling_jobs =  $self->modeling_jobs($c);
    }

    if ($modeling_jobs)
    {
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	my $model_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'gs_model_args');

	nstore $modeling_jobs, $model_file
	    or croak "gs r script: $! serializing model details to $model_file";

	$c->stash->{gs_modeling_jobs_args_file} = $model_file;
    }

}


sub run_r_script {
    my ($self, $c) = @_;

    if ($c->stash->{background_job})
    {
	$self->get_gs_modeling_jobs_args_file($c);
	$c->stash->{dependent_jobs} =  $c->stash->{gs_modeling_jobs_args_file};
	$self->run_async($c);
    }
    else
    {
	$self->get_cluster_r_job_args($c);
	my $cluster_job_args = $c->stash->{cluster_r_job_args};
	$self->submit_job_cluster($c, $cluster_job_args);
    }

}


sub get_cluster_r_job_args {
    my ($self, $c) = @_;

    my $r_script     = $c->stash->{r_script};
    my $input_files  = $c->stash->{input_files};
    my $output_files = $c->stash->{output_files};

    if ($r_script =~ /gs/)
    {
	$self->get_gs_r_temp_file($c);
    }

    $self->create_cluster_accesible_tmp_files($c);
    my $in_file   = $c->stash->{in_file_temp};
    my $out_temp_file  = $c->stash->{out_file_temp};
    my $err_temp_file  = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{analysis_tempfiles_dir} || $c->stash->{solgs_tempfiles_dir};

    {
        my $r_cmd_file = $c->path_to($r_script);
        copy($r_cmd_file, $in_file)
            or die "could not copy '$r_cmd_file' to '$in_file'";
    }

    my $config_args = {
	'temp_dir' => $temp_dir,
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file
    };

    my $config = $self->create_cluster_config($c, $config_args);

    my $cmd = 'Rscript --slave '
	. "$in_file $out_temp_file "
	. '--args ' .  $input_files
	. ' ' . $output_files;

    my $job_args = {
	'cmd' => $cmd,
	'background_job' => $c->stash->{background_job},
	'config' => $config,
    };

    $c->stash->{cluster_r_job_args} = $job_args;

}


sub create_cluster_config {
    my ($self, $c, $args) = @_;

    my $config = {
	temp_base        => $args->{temp_dir},
	queue            => $c->config->{'web_cluster_queue'},
	max_cluster_jobs => 1_000_000_000,
	out_file         => $args->{out_file},
	err_file         => $args->{err_file},
	is_async         => 0,
	do_cleanup       => 0,
	sleep            => $args->{sleep}
    };

    if ($args->{cluster_host} =~ /localhost/ || !$c->config->{cluster_host})
    {
	$config->{backend} = 'Slurm';
	$config->{submit_host} = 'localhost';
    }
    else
    {
	$config->{backend} = $c->config->{backend};
	$config->{submit_host} = $c->config->{cluster_host};
    }

    return $config;
}


sub submit_job_cluster {
    my ($self, $c, $args) = @_;

    my $job;

    eval
    {
	$job = CXGN::Tools::Run->new($args->{config});
	$job->do_not_cleanup(1);

	if ($args->{background_job})
	{
	    $job->is_async(1);
	    $job->run_async($args->{cmd});

	    $c->stash->{r_job_tempdir} = $job->job_tempdir();
	    $c->stash->{r_job_id}      = $job->jobid();
	    $c->stash->{cluster_job_id} = $job->cluster_job_id();
	    $c->stash->{cluster_job}   = $job;
	}
	else
	{
	    $job->run_async($args->{cmd});
	    $job->wait();
	}
    };

    if ($@)
    {
	$c->stash->{Error} =  'Error occured submitting the job ' . $@ . "\nJob: " . $args->{cmd};
	$c->stash->{status} = 'Error occured submitting the job ' . $@ . "\nJob: " . $args->{cmd};
    }

    return $job;

}

# sub default :Path {
#     my ( $self, $c ) = @_;
#     $c->forward('search');
# }



=head2 end

Attempt to render a view, if needed.

=cut

#sub render : ActionClass('RenderView') {}
sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
