package SGN::Controller::solGS::solGS;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file append_file/;
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

    $c->stash->{template} =  $self->template('/submit/intro.mas');
}


sub search : Path('/solgs/search') Args() {
    my ($self, $c) = @_;

    #$self->gs_traits_index($c);
    #my $gs_traits_index = $c->stash->{gs_traits_index};
          
    $c->stash(template        => $self->template('/search/solgs.mas'),               
	   #   gs_traits_index => $gs_traits_index,           
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
	   	    
	    my $checkbox = qq |<form> <input type="checkbox" name="project" value="$pr_id" onclick="getPopIds()"/> </form> |;

	    #$match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:30px">code</div> |;

	    push @projects_pages, [$checkbox, qq|<a href="/solgs/population/$pr_id" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|, 
				   $pr_desc, $pr_location, $pr_year
		];          

	  
	}

    }

    $c->stash->{projects_pages} = \@projects_pages;
}


sub search_trials_trait : Path('/solgs/search/trials/trait') Args(1) {
    my ($self, $c, $trait_id) = @_;
    
    $self->get_trait_details($c, $trait_id);
    
    $c->stash->{template} = $self->template('/search/trials/trait.mas');

}


sub show_search_result_pops : Path('/solgs/search/result/populations') Args(1) {
    my ($self, $c, $trait_id) = @_;
    
    my $combine = $c->req->param('combine');
    my $page = $c->req->param('page') || 1;

    my $projects_ids = $c->model('solGS::solGS')->search_trait_trials($trait_id);
        
    my $ret->{status} = 'failed';
    my $formatted_projects = [];

    if (@$projects_ids) 
    {
	my $projects_rs  = $c->model('solGS::solGS')->project_details($projects_ids);
	my $trait        = $c->model('solGS::solGS')->trait_name($trait_id);
   
	$self->get_projects_details($c, $projects_rs);
	my $projects = $c->stash->{projects_details};

	$self->format_trait_gs_projects($c, $trait_id, $projects);
	$formatted_projects = $c->stash->{formatted_gs_projects}; 
	
	$ret->{status} = 'success';        
    }
      
    $ret->{trials}   = $formatted_projects;
  
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub format_trait_gs_projects {
   my ($self, $c, $trait_id, $projects) = @_; 

   my @formatted_projects;

   foreach my $pr_id (keys %$projects) 
   { 
       my $pr_name     = $projects->{$pr_id}{project_name};
       my $pr_desc     = $projects->{$pr_id}{project_desc};
       my $pr_year     = $projects->{$pr_id}{project_year};
       my $pr_location = $projects->{$pr_id}{project_location};

       $c->stash->{pop_id} = $pr_id;
       $self->check_population_has_genotype($c);
       my $has_genotype = $c->stash->{population_has_genotype};

       if ($has_genotype) 
       {
	   my $trial_compatibility_file = $self->trial_compatibility_file($c);
	   
	   $self->trial_compatibility_table($c, $has_genotype);
	   my $match_code = $c->stash->{trial_compatibility_code};

	   my $checkbox = qq |<form> <input  type="checkbox" name="project" value="$pr_id" onclick="getPopIds()"/> </form> |;
	   $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;

	   push @formatted_projects, [ $checkbox, qq|<a href="/solgs/trait/$trait_id/population/$pr_id" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|, $pr_desc, $pr_location, $pr_year, $match_code];
       }
   }     

   $c->stash->{formatted_gs_projects} = \@formatted_projects;

}


sub format_gs_projects {
   my ($self, $c, $projects) = @_; 

   my @formatted_projects;

   foreach my $pr_id (keys %$projects) 
   { 
       my $pr_name     = $projects->{$pr_id}{project_name};
       my $pr_desc     = $projects->{$pr_id}{project_desc};
       my $pr_year     = $projects->{$pr_id}{project_year};
       my $pr_location = $projects->{$pr_id}{project_location};

      # $c->stash->{pop_id} = $pr_id;
      # $self->check_population_has_genotype($c);
      # my $has_genotype = $c->stash->{population_has_genotype};
       my $has_genotype = $c->config->{default_genotyping_protocol};

       if ($has_genotype) 
       {
	   my $trial_compatibility_file = $self->trial_compatibility_file($c);
	   
	   $self->trial_compatibility_table($c, $has_genotype);
	   my $match_code = $c->stash->{trial_compatibility_code};

	   my $checkbox = qq |<form> <input  type="checkbox" name="project" value="$pr_id" onclick="getPopIds()"/> </form> |;
	   $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;

	   push @formatted_projects, [ $checkbox, qq|<a href="/solgs/population/$pr_id" onclick="solGS.waitPage(this.href); return false;">$pr_name</a>|, $pr_desc, $pr_location, $pr_year, $match_code];
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
        my @line =  read_file($compatibility_file);     
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
        write_file($compatibility_file,{append => 1}, $color_code);
    }
}


sub trial_compatibility_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'trial_compatibility',
                      file      => 'trial_compatibility_codes',
                      stash_key => 'trial_compatibility_file'
    };

    $self->cache_file($c, $cache_data);

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


sub search_traits : Path('/solgs/search/traits/') Args(1) {
    my ($self, $c, $query) = @_;
     
    my $traits = $c->model('solGS::solGS')->search_trait($query); 
    my $result = $c->model('solGS::solGS')->trait_details($traits);
    
    my $ret->{status} = 0;
    if ($result->first)
    {
	$ret->{status} = 1;      
    }
  
    $ret = to_json($ret);
                
    $c->res->content_type('application/json');
    $c->res->body($ret); 

}


sub show_search_result_traits : Path('/solgs/search/result/traits') Args(1) {
    my ($self, $c, $query) = @_;
   
    my $traits = $c->model('solGS::solGS')->search_trait($query);
    my $result    = $c->model('solGS::solGS')->trait_details($traits);
    
    my @rows;
    while (my $row = $result->next)
    {
        my $id   = $row->cvterm_id;
        my $name = $row->name;
        my $def  = $row->definition;
       
        push @rows, [ qq |<a href="/solgs/search/trials/trait/$id"  onclick="solGS.waitPage()">$name</a>|, $def];      
    }
  
    if (@rows)
    {
	$c->stash(template   => $self->template('/search/result/traits.mas'),
		  result     => \@rows,
		  query      => $query,
	    );
    }

} 


sub population : Regex('^solgs/population/([\w|\d]+)(?:/([\w+]+))?') {
    my ($self, $c) = @_;
  
    my ($pop_id, $action) = @{$c->req->captures};
   
    my $uploaded_reference = $c->req->param('uploaded_reference');
    $c->stash->{uploaded_reference} = $uploaded_reference;

    if ($uploaded_reference) 
    {
        $pop_id = $c->req->param('model_id');

        $c->stash->{model_id}   = $c->req->param('model_id'),
        $c->stash->{list_name} = $c->req->param('list_name'),

    }

    if ($pop_id )
    {   
        if($pop_id =~ /uploaded/) 
        {
            $c->stash->{uploaded_reference} = 1;
            $uploaded_reference = 1;
        }

        $c->stash->{pop_id} = $pop_id; 
          
        $self->phenotype_file($c); 
        $self->genotype_file($c); 
        $self->get_all_traits($c);  
        $self->project_description($c, $pop_id);
 
        $c->stash->{template} = $self->template('/population.mas');
      
        if ($action && $action =~ /selecttraits/ ) {
            $c->stash->{no_traits_selected} = 'none';
        }
        else {
            $c->stash->{no_traits_selected} = 'some';
        }

        my $acronym = $self->get_acronym_pairs($c);
        $c->stash->{acronym} = $acronym;
    }
 
    my $pheno_data_file = $c->stash->{phenotype_file};
    
    if ($uploaded_reference) 
    {
	my $ret->{status} = 'failed';
	if ( !-s $pheno_data_file )
	{
	    $ret->{status} = 'failed';
            
	    $ret = to_json($ret);
                
	    $c->res->content_type('application/json');
	    $c->res->body($ret); 
	}
    }
} 


sub uploaded_population_summary {
    my ($self, $c, $list_pop_id) = @_;
    
    my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};
   
    if (!$c->user)
    {
	my $page = "/" . $c->req->path;
	$c->res->redirect("/solgs/list/login/message?page=$page");
	$c->detach;
    }
    else
    {
	my $user_name = $c->user->id;
    
	#my $model_id = $c->stash->{model_id};
	#my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
 
	my $protocol = $c->config->{default_genotyping_protocol};
	$protocol = 'N/A' if !$protocol;

	if ($list_pop_id) 
	{
	    my $metadata_file_tr = catfile($tmp_dir, "metadata_${user_name}_${list_pop_id}");
       
	    my @metadata_tr = read_file($metadata_file_tr) if $list_pop_id;
       
	    my ($key, $list_name, $desc);
     
	    ($desc)        = grep {/description/} @metadata_tr;       
	    ($key, $desc)  = split(/\t/, $desc);
      
	    ($list_name)       = grep {/list_name/} @metadata_tr;      
	    ($key, $list_name) = split(/\t/, $list_name); 
	   
	    $c->stash(project_id          => $list_pop_id,
		      project_name        => $list_name,
		      prediction_pop_name => $list_name,
		      project_desc        => $desc,
		      owner               => $user_name,
		      protocol            => $protocol,
		);  
	}

	# if ($selection_pop_id =~ /uploaded/) 
	# {
	#     my $metadata_file_sl = catfile($tmp_dir, "metadata_${user_name}_${selection_pop_id}");    
	#     my @metadata_sl = read_file($metadata_file_sl) if $selection_pop_id;
      
	#     my ($list_name_sl)       = grep {/list_name/} @metadata_sl;      
	#     my  ($key_sl, $list_name) = split(/\t/, $list_name_sl); 
   
	#     $c->stash->{prediction_pop_name} = $list_name;
	# }
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

    if ($pop_hash->{training_pop})
    {
	my $training_pop_id = $pop_hash->{training_pop_id};
	$c->stash->{pop_id} = $training_pop_id;
	$self->filtered_training_genotype_file($c);
	$filtered_geno_file  = $c->stash->{filtered_training_genotype_file};

	if (-s $filtered_geno_file) {
	    my @geno_lines = read_file($filtered_geno_file);
	    $markers_cnt = scalar(split('\t', $geno_lines[0])) - 1;
	} 
	else 
	{
	    $self->genotype_file_name($c, $training_pop_id);
	    my $geno_file  = $c->stash->{genotype_file_name};
	    my  @geno_lines = read_file($geno_file);
	    $markers_cnt= scalar(split ('\t', $geno_lines[0])) - 1;	
	}

    } 
    elsif ($pop_hash->{selection_pop})
    {
	my $selection_pop_id = $pop_hash->{selection_pop_id};
	$c->stash->{pop_id} = $selection_pop_id;
	$self->filtered_selection_genotype_file($c);
	$filtered_geno_file  = $c->stash->{filtered_selection_genotype_file};

	if (-s $filtered_geno_file) {
	    my @geno_lines = read_file($filtered_geno_file);
	    $markers_cnt = scalar(split('\t', $geno_lines[0])) - 1;
	} 
	else 
	{
	    $self->genotype_file_name($c, $selection_pop_id);
	    my $geno_file  = $c->stash->{genotype_file_name};
	    my @geno_lines = read_file($geno_file);
	    $markers_cnt= scalar(split ('\t', $geno_lines[0])) - 1;	
	}
    }

    return $markers_cnt;

}


sub project_description {
    my ($self, $c, $pr_id) = @_;

    $c->stash->{pop_id} = $pr_id;
    $c->stash->{uploaded_reference} = 1 if ($pr_id =~ /uploaded/);

    my $protocol = $c->config->{default_genotyping_protocol};
    $protocol = 'N/A' if !$protocol;

    if(!$c->stash->{uploaded_reference}) {
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
    else 
    {
        $c->stash->{model_id} = $pr_id;
        $self->uploaded_population_summary($c, $pr_id);
    }
    
    $self->filtered_training_genotype_file($c);
    my $filtered_geno_file  = $c->stash->{filtered_training_genotype_file};

    my $markers_no;
    my @geno_lines;

    if (-s $filtered_geno_file) {
	@geno_lines = read_file($filtered_geno_file);
	$markers_no = scalar(split('\t', $geno_lines[0])) - 1;
    } 
    else 
    {
	$self->genotype_file($c);
	my $geno_file  = $c->stash->{genotype_file};
	@geno_lines = read_file($geno_file);
	$markers_no = scalar(split ('\t', $geno_lines[0])) - 1;	
    }
   
    $self->trait_phenodata_file($c);
    my $trait_pheno_file  = $c->stash->{trait_phenodata_file};
    my @trait_pheno_lines = read_file($trait_pheno_file) if $trait_pheno_file;
 
    my $stocks_no = @trait_pheno_lines ? scalar(@trait_pheno_lines) - 1 : scalar(@geno_lines) - 1;
    
    $self->traits_acronym_file($c);
    my $traits_file = $c->stash->{traits_acronym_file};
    my @lines = read_file($traits_file);
    my $traits_no = scalar(@lines) - 1;
       
    $c->stash(markers_no => $markers_no,
              traits_no  => $traits_no,
              stocks_no  => $stocks_no,
	      protocol   => $protocol,
        );

}


sub selection_trait :Path('/solgs/selection/') Args(5) {
    my ($self, $c, $selection_pop_id, 
        $model_key, $training_pop_id, 
        $trait_key, $trait_id) = @_;

    $self->get_trait_details($c, $trait_id);
    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;
    $c->stash->{data_set_type} = 'single population';
    
    if ($training_pop_id =~ /uploaded/) 
    {
        $self->uploaded_population_summary($c, $training_pop_id);
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

    if ($selection_pop_id =~ /uploaded/) 
    {
        $self->uploaded_population_summary($c, $selection_pop_id);
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

    $c->stash->{training_markers_cnt} = $tr_pop_mr_cnt;
    $c->stash->{selection_markers_cnt} = $sel_pop_mr_cnt;

    my $protocol = $c->config->{default_genotyping_protocol};
    $protocol = 'N/A' if !$protocol;
    $c->stash->{protocol} = $protocol;

    my $identifier    = $training_pop_id . '_' . $selection_pop_id; 
    $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    my $gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    
    my @stock_rows = read_file($gebvs_file);
    $c->stash->{selection_stocks_cnt} = scalar(@stock_rows) - 1;

    $self->top_blups($c, $gebvs_file);
 
    $c->stash->{blups_download_url} = qq | <a href="/solgs/download/prediction/model/$training_pop_id/prediction/$selection_pop_id/$trait_id">Download all GEBVs</a>|; 

    $c->stash->{template} = $self->template('/population/selection_trait.mas');
    
} 


sub build_single_trait_model {
    my ($self, $c)  = @_;

    my $trait_id =  $c->stash->{trait_id};    
    $self->get_trait_details($c, $trait_id);
 
    $self->get_rrblup_output($c);
 
}


sub trait :Path('/solgs/trait') Args(3) {
    my ($self, $c, $trait_id, $key, $pop_id) = @_;
   
    my $ajaxredirect = $c->req->param('source');
    $c->stash->{ajax_request} = $ajaxredirect;
   
    if ($pop_id && $trait_id)
    {    
        $c->stash->{pop_id}   = $pop_id;       
	$c->stash->{trait_id} = $trait_id;
     
	$self->build_single_trait_model($c);
	
	$self->gs_files($c);

        unless ($ajaxredirect eq 'heritability') 
        {	    
            my $script_error = $c->stash->{script_error};
	             
	    if ($script_error) 
            {
		my $trait_name   = $c->stash->{trait_name};
                $c->stash->{message} = "$script_error can't create a prediction model for <b>$trait_name</b>. 
                                        There is a problem with the trait dataset.";

                $c->stash->{template} = "/generic_message.mas";   
            } 
            else 
	    {    
		$self->traits_acronym_file($c);
		my $acronym_file = $c->stash->{traits_acronym_file};
	
		if (!-e $acronym_file || !-s $acronym_file) 
		{
		    $self->get_all_traits($c);
		}

		$self->project_description($c, $pop_id); 

		$self->trait_phenotype_stat($c);  
 
		$self->get_project_owners($c, $pop_id);       
		$c->stash->{owner} = $c->stash->{project_owners};
                
		$c->stash->{template} = $self->template("/population/trait.mas");
	    }	  
	}
    }
 
    if ($ajaxredirect) 
    {
        my $trait_abbr = $c->stash->{trait_abbr};
        my $cache_dir  = $c->stash->{solgs_cache_dir};
        my $gebv_file  = "gebv_kinship_${trait_abbr}_${pop_id}";       
        $gebv_file     = $self->grep_file($cache_dir,  $gebv_file);

        my $ret->{status} = 'failed';
        
        if (-s $gebv_file) 
        {
            $ret->{status} = 'success';
        }
        
        $ret = to_json($ret);
        
        $c->res->content_type('application/json');
        $c->res->body($ret);
        
    }
    
}


sub gs_files {
    my ($self, $c) = @_;
    
    $self->output_files($c);
    #$self->input_files($c);
    $self->model_accuracy($c);
    $self->blups_file($c);
    $self->download_urls($c);
    $self->top_markers($c);
    $self->model_parameters($c);

}


sub input_files {
    my ($self, $c) = @_;
    
    $self->genotype_file($c);  
    $self->phenotype_file($c);
    $self->formatted_phenotype_file($c);

    my $pred_pop_id = $c->stash->{prediction_pop_id} ||$c->stash->{selection_pop_id} ;
    my ($prediction_population_file, $filtered_pred_geno_file);

    if ($pred_pop_id) 
    {
        $prediction_population_file = $c->stash->{prediction_population_file};
    }
  
    my $formatted_phenotype_file  = $c->stash->{formatted_phenotype_file};
   
    my $pheno_file  = $c->stash->{phenotype_file};
    my $geno_file   = $c->stash->{genotype_file};
    my $traits_file = $c->stash->{selected_traits_file};
    my $trait_file  = $c->stash->{trait_file};
    my $pop_id      = $c->stash->{pop_id};

    no warnings 'uninitialized';

    my $input_files = join ("\t",
                            $pheno_file,
			    $formatted_phenotype_file,
                            $geno_file,
                            $traits_file,
                            $trait_file,
                            $prediction_population_file,
        );

    my $name = "input_files_${pop_id}"; 
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $tempfile = $self->create_tempfile($temp_dir, $name); 
    write_file($tempfile, $input_files);
    $c->stash->{input_files} = $tempfile;
  
}


sub output_files {
    my ($self, $c) = @_;
    
    my $pop_id   = $c->stash->{pop_id};
    my $trait    = $c->stash->{trait_abbr}; 
    my $trait_id = $c->stash->{trait_id}; 
    
    $self->gebv_marker_file($c);  
    $self->gebv_kinship_file($c); 
    $self->validation_file($c);
    $self->trait_phenodata_file($c);
    $self->variance_components_file($c);
    $self->relationship_matrix_file($c);
    $self->filtered_training_genotype_file($c);

    $self->filtered_training_genotype_file($c);

    my $prediction_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    if (!$pop_id) {$pop_id = $c->stash->{model_id};}

    no warnings 'uninitialized';
   
    #$prediction_id = "uploaded_${prediction_id" if $c->stash->{uploaded_prediction};
    
    my $pred_pop_gebvs_file;
    
    if ($prediction_id) 
    {
	my $identifier    = $pop_id . '_' . $prediction_id;
        $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        $pred_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    }

    my $file_list = join ("\t",
                          $c->stash->{gebv_kinship_file},
                          $c->stash->{gebv_marker_file},
                          $c->stash->{validation_file},
                          $c->stash->{trait_phenodata_file},                         
                          $c->stash->{selected_traits_gebv_file},
                          $c->stash->{variance_components_file},
			  $c->stash->{relationship_matrix_file},
			  $c->stash->{filtered_training_genotype_file},
                          $pred_pop_gebvs_file
        );
                          
    my $name = "output_files_${trait}_$pop_id"; 
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $tempfile = $self->create_tempfile($temp_dir, $name); 
    write_file($tempfile, $file_list);
    
    $c->stash->{output_files} = $tempfile;

}


sub gebv_marker_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
    no warnings 'uninitialized';

    my $data_set_type = $c->stash->{data_set_type};
       
    my $cache_data;

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id}; 
       
        $cache_data = {key       => 'gebv_marker_combined_pops_'.  $trait . '_' . $combo_identifier,
                       file      => 'gebv_marker_'. $trait . '_' . $combo_identifier . '_combined_pops',
                       stash_key => 'gebv_marker_file'
        };
    }
    else
    {
    
       $cache_data = {key       => 'gebv_marker_' . $pop_id . '_'.  $trait,
                      file      => 'gebv_marker_' . $trait . '_' . $pop_id,
                      stash_key => 'gebv_marker_file'
       };
    }

    $self->cache_file($c, $cache_data);

}


sub variance_components_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
    my $data_set_type = $c->stash->{data_set_type};
    
    my $cache_data;

    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id}; 

        $cache_data = {key       => 'variance_components_combined_pops_'.  $trait . "_". $combo_identifier,
                       file      => 'variance_components_'. $trait . '_' . $combo_identifier. '_combined_pops',
                       stash_key => 'variance_components_file'
        };
    }
    else 
    {
        $cache_data = {key       => 'variance_components_' . $pop_id . '_'.  $trait,
                       file      => 'variance_components_' . $trait . '_' . $pop_id,
                       stash_key => 'variance_components_file'
        };
    }

    $self->cache_file($c, $cache_data);
}


sub trait_phenodata_file {
    my ($self, $c) = @_;
   
    my $pop_id        = $c->stash->{pop_id};
    my $trait         = $c->stash->{trait_abbr};    
    my $data_set_type = $c->stash->{data_set_type};
   
    my $cache_data;

    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id}; 
        $cache_data = {key       => 'phenotype_trait_combined_pops_'.  $trait . "_". $combo_identifier,
                       file      => 'phenotype_trait_'. $trait . '_' . $combo_identifier. '_combined_pops',
                       stash_key => 'trait_phenodata_file'
        };
    }
    else 
    {
        $cache_data = {key       => 'phenotype_' . $pop_id . '_'.  $trait,
                       file      => 'phenotype_trait_' . $trait . '_' . $pop_id,
                       stash_key => 'trait_phenodata_file'
        };
    }

    $self->cache_file($c, $cache_data);
}


sub filtered_training_genotype_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    $pop_id = $c->{stash}->{combo_pops_id} if !$pop_id;

    my $cache_data = { key       => 'filtered_genotype_data_' . $pop_id, 
                       file      => 'filtered_genotype_data_' . $pop_id . '.txt',
                       stash_key => 'filtered_training_genotype_file'
    };
    
    $self->cache_file($c, $cache_data);
}


sub filtered_selection_genotype_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    
    my $cache_data = { key       => 'filtered_genotype_data_' . $pop_id, 
                       file      => 'filtered_genotype_data_' . $pop_id . '.txt',
                       stash_key => 'filtered_selection_genotype_file'
    };
    
    $self->cache_file($c, $cache_data);
}


sub formatted_phenotype_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    $pop_id = $c->{stash}->{combo_pops_id} if !$pop_id;

    my $cache_data = { key       => 'formatted_phenotype_data_' . $pop_id, 
                       file      => 'formatted_phenotype_data_' . $pop_id,
                       stash_key => 'formatted_phenotype_file'
    };
    
    $self->cache_file($c, $cache_data);
}


sub phenotype_file_name {
    my ($self, $c, $pop_id) = @_;
   
    #my $pop_id = $c->stash->{pop_id};
    #$pop_id = $c->{stash}->{combo_pops_id} if !$pop_id;

    if ($pop_id =~ /uploaded/) 
    {
	my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};
	my $file = catfile($tmp_dir, 'phenotype_data_' . $pop_id . '.txt');
	$c->stash->{phenotype_file_name} = $file;
    }
    else
    {

	my $cache_data = { key       => 'phenotype_data_' . $pop_id, 
			   file      => 'phenotype_data_' . $pop_id . '.txt',
			   stash_key => 'phenotype_file_name'
	};
    
	$self->cache_file($c, $cache_data);
    }
}


sub genotype_file_name {
    my ($self, $c, $pop_id) = @_;
   
    # my $pop_id = $c->stash->{pop_id};
    # $pop_id = $c->stash->{combo_pops_id} if !$pop_id;
    # my $pred_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id} ; 
   
    if ($pop_id =~ /uploaded/) 
    {
	my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};
	my $file = catfile($tmp_dir, 'genotype_data_' . $pop_id . '.txt');
	$c->stash->{genotype_file_name} = $file;
    }
    else
    {
	my $cache_data = { key   => 'genotype_data_' . $pop_id, 
                       file      => 'genotype_data_' . $pop_id . '.txt',
                       stash_key => 'genotype_file_name'
	};
    
	$self->cache_file($c, $cache_data);
    }
}


sub gebv_kinship_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    my $data_set_type = $c->stash->{data_set_type};
        
    my $cache_data;
    
    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id};
        $cache_data = {key       => 'gebv_kinship_combined_pops_'.  $combo_identifier . "_" . $trait,
                       file      => 'gebv_kinship_'. $trait . '_'  . $combo_identifier. '_combined_pops',
                       stash_key => 'gebv_kinship_file'

        };
    }
    else 
    {
    
        $cache_data = {key       => 'gebv_kinship_' . $pop_id . '_'.  $trait,
                       file      => 'gebv_kinship_' . $trait . '_' . $pop_id,
                       stash_key => 'gebv_kinship_file'
        };
    }

    $self->cache_file($c, $cache_data);

}


sub relationship_matrix_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $data_set_type = $c->stash->{data_set_type};
        
    my $cache_data;
    
    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id};
        $cache_data = {key       => 'relationship_matrix_combined_pops_'.  $combo_identifier,
                       file      => 'relationship_matrix_combined_pops_' . $combo_identifier,
                       stash_key => 'relationship_matrix_file'

        };
    }
    else 
    {
    
        $cache_data = {key       => 'relationship_matrix_' . $pop_id,
                       file      => 'relationship_matrix_' . $pop_id,
                       stash_key => 'relationship_matrix_file'
        };
    }

    $self->cache_file($c, $cache_data);

}


sub blups_file {
    my ($self, $c) = @_;
    
    my $blups_file = $c->stash->{gebv_kinship_file};
    $self->top_blups($c, $blups_file);
}


sub download_blups :Path('/solgs/download/blups/pop') Args(3) {
    my ($self, $c, $pop_id, $trait, $trait_id) = @_;   
 
    $self->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};
   
    my $dir = $c->stash->{solgs_cache_dir};
    my $blup_exp = "gebv_kinship_${trait_abbr}_${pop_id}";
    my $blups_file = $self->grep_file($dir, $blup_exp);

    unless (!-e $blups_file || -s $blups_file == 0) 
    {
        my @blups =  map { [ split(/\t/) ] }  read_file($blups_file);
      
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @blups);
    } 

}


sub download_marker_effects :Path('/solgs/download/marker/pop') Args(3) {
    my ($self, $c, $pop_id, $trait, $trait_id) = @_;   
 
    $self->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};
  
    my $dir = $c->stash->{solgs_cache_dir};
    my $marker_exp = "gebv_marker_${trait_abbr}_${pop_id}";
    my $markers_file = $self->grep_file($dir, $marker_exp);

    unless (!-e $markers_file || -s $markers_file == 0) 
    {
        my @effects =  map { [ split(/\t/) ] }  read_file($markers_file);
    
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @effects);
    } 

}


sub download_urls {
    my ($self, $c) = @_;
    my $data_set_type = $c->stash->{data_set_type};
    my $pop_id;

    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        $pop_id         = $c->stash->{combo_pops_id};
    }
    else 
    {
        $pop_id         = $c->stash->{pop_id}; 
    }
    
    my $trait_id          = $c->stash->{trait_id};
    my $ranked_genos_file = $c->stash->{selection_index_file};

    if ($ranked_genos_file) 
    {
        ($ranked_genos_file) = fileparse($ranked_genos_file);
    }
    
    my $blups_url      = qq | <a href="/solgs/download/blups/pop/$pop_id/trait/$trait_id">Download all GEBVs</a> |;
    my $marker_url     = qq | <a href="/solgs/download/marker/pop/$pop_id/trait/$trait_id">Download all marker effects</a> |;
    my $validation_url = qq | <a href="/solgs/download/validation/pop/$pop_id/trait/$trait_id">Download model accuracy report</a> |;
    my $ranked_genotypes_url = qq | <a href="/solgs/download/ranked/genotypes/pop/$pop_id/$ranked_genos_file">Download selection indices</a> |;
   
    $c->stash(blups_download_url            => $blups_url,
              marker_effects_download_url   => $marker_url,
              validation_download_url       => $validation_url,
              ranked_genotypes_download_url => $ranked_genotypes_url,
        );
}


sub top_blups {
    my ($self, $c, $blups_file) = @_;
      
    my $blups = $self->convert_to_arrayref_of_arrays($c, $blups_file);
   
    my @top_blups = @$blups[0..9];
 
    $c->stash->{top_blups} = \@top_blups;
}


sub top_markers {
    my ($self, $c) = @_;
    
    my $markers_file = $c->stash->{gebv_marker_file};

    my $markers = $self->convert_to_arrayref_of_arrays($c, $markers_file);
    
    my @top_markers = @$markers[0..9];

    $c->stash->{top_marker_effects} = \@top_markers;
}


sub validation_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
     
    my $data_set_type = $c->stash->{data_set_type};
       
    my $cache_data;

    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/) 
    {
        my $combo_identifier = $c->stash->{combo_pops_id};
        $cache_data = {key       => 'cross_validation_combined_pops_'.  $trait . "_${combo_identifier}",
                       file      => 'cross_validation_'. $trait . '_' . $combo_identifier . '_combined_pops' ,
                       stash_key => 'validation_file'
        };
    }
    else
    {

        $cache_data = {key       => 'cross_validation_' . $pop_id . '_' . $trait, 
                       file      => 'cross_validation_' . $trait . '_' . $pop_id,
                       stash_key => 'validation_file'
        };
    }

    $self->cache_file($c, $cache_data);
}


sub combined_gebvs_file {
    my ($self, $c, $identifier) = @_;

    my $pop_id = $c->stash->{pop_id};
     
    my $cache_data = {key       => 'selected_traits_gebv_' . $pop_id . '_' . $identifier, 
                      file      => 'selected_traits_gebv_' . $pop_id . '_' . $identifier,
                      stash_key => 'selected_traits_gebv_file'
    };

    $self->cache_file($c, $cache_data);

}


sub download_validation :Path('/solgs/download/validation/pop') Args(3) {
    my ($self, $c, $pop_id, $trait, $trait_id) = @_;   
 
    $self->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    my $dir = $c->stash->{solgs_cache_dir};
    my $val_exp = "cross_validation_${trait_abbr}_${pop_id}";
    my $validation_file = $self->grep_file($dir, $val_exp);

    unless (!-e $validation_file || -s $validation_file == 0) 
    {
        my @validation =  map { [ split(/\t/) ] }  read_file($validation_file);
    
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @validation);  
    } 

}


sub predict_selection_pop_single_trait {
    my ($self, $c) = @_;
    
    if ($c->stash->{data_set_type} =~ /single population/)
    {
	$self->predict_selection_pop_single_pop_model($c)
    }
    else
    {  
	$self->predict_selection_pop_combined_pops_model($c);
    }


}


sub predict_selection_pop_multi_traits {
    my ($self, $c) = @_;
    
    my $data_set_type    = $c->stash->{data_set_type};
    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
  
    $c->stash->{pop_id} = $training_pop_id;    
    $self->traits_with_valid_models($c);
    my @traits_with_valid_models = @{$c->stash->{traits_with_valid_models}};

    foreach my $trait_abbr (@traits_with_valid_models) 
    {
	$c->stash->{trait_abbr} = $trait_abbr;
	$self->get_trait_details_of_trait_abbr($c);
	$self->predict_selection_pop_single_trait($c);
    }
    
}


sub predict_selection_pop_single_pop_model {
    my ($self, $c) = @_;

    my $trait_id          = $c->stash->{trait_id};
    my $training_pop_id   = $c->stash->{training_pop_id};
    my $prediction_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
 
    $self->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    my $identifier = $training_pop_id . '_' . $prediction_pop_id;
    $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    
    my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    
    if (!-s $prediction_pop_gebvs_file)
    {
	my $dir = $c->stash->{solgs_cache_dir};
        
	my $exp = "phenotype_data_${training_pop_id}"; 
	my $pheno_file = $self->grep_file($dir, $exp);

	$exp = "genotype_data_${training_pop_id}"; 
	my $geno_file = $self->grep_file($dir, $exp);

	$c->stash->{pheno_file} = $pheno_file;
	$c->stash->{geno_file}  = $geno_file;
	
	$self->prediction_population_file($c, $prediction_pop_id);
	$self->get_rrblup_output($c); 
    }   

}


sub predict_selection_pop_combined_pops_model {
    my ($self, $c) = @_;
         
    my $data_set_type     = $c->stash->{data_set_type}; 
    my $combo_pops_id     = $c->stash->{combo_pops_id};
    my $model_id          = $c->stash->{model_id};                          
    my $prediction_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    my $trait_id          = $c->stash->{trait_id};
        
    $self->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    my $identifier = $combo_pops_id . '_' . $prediction_pop_id;
    $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        
    my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
     
    if (!-s $prediction_pop_gebvs_file)
    {    
	$self->cache_combined_pops_data($c);
 
	$self->prediction_population_file($c, $prediction_pop_id);
  
	$self->get_rrblup_output($c); 
    }

}


sub selection_prediction :Path('/solgs/model') Args(3) {
    my ($self, $c, $training_pop_id, $pop, $selection_pop_id) = @_;
   
    my $referer = $c->req->referer;    
    my $path    = $c->req->path;
    my $base    = $c->req->base;
    $referer    =~ s/$base//;

    $c->stash->{training_pop_id}   = $training_pop_id;
    $c->stash->{model_id}          = $training_pop_id;
    $c->stash->{pop_id}            = $training_pop_id;
    $c->stash->{prediction_pop_id} = $selection_pop_id; 
    $c->stash->{selection_pop_id}  = $selection_pop_id; 

    if ($referer =~ /solgs\/model\/combined\/populations\//)
    {   
        my ($combo_pops_id, $trait_id) = $referer =~ m/(\d+)/g;

        $c->stash->{data_set_type}     = "combined populations"; 
        $c->stash->{combo_pops_id}     = $combo_pops_id;                            
        $c->stash->{trait_id}          = $trait_id;
       
	$self->predict_selection_pop_combined_pops_model($c);
        
        $self->combined_pops_summary($c);        
        $self->trait_phenotype_stat($c);
        $self->gs_files($c);
	
        $c->res->redirect("/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id"); 
        $c->detach();
    }
    elsif ($referer =~ /solgs\/trait\//) 
    {
        my ($trait_id, $pop_id) = $referer =~ m/(\d+)/g;
              
        $c->stash->{data_set_type} = "single population"; 
        $c->stash->{trait_id}      = $trait_id;
 
	$self->predict_selection_pop_single_pop_model($c);

	$self->trait_phenotype_stat($c);
        $self->gs_files($c);

	$c->res->redirect("/solgs/trait/$trait_id/population/$training_pop_id");
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
	    $self->predict_selection_pop_combined_pops_model($c);                        
         }
            
        $c->res->redirect("/solgs/models/combined/trials/$training_pop_id");
        $c->detach();
    }
    elsif ($referer =~ /solgs\/traits\/all\/population\//) 
    {	
	$c->stash->{data_set_type}  = "single population"; 

	$self->predict_selection_pop_multi_traits($c);

        $c->res->redirect("/solgs/traits/all/population/$training_pop_id");
        $c->detach();
    }
 
}


sub prediction_pop_gebvs_file {    
    my ($self, $c, $identifier, $trait_id) = @_;

    my $cache_data = {key       => 'prediction_pop_gebvs_' . $identifier . '_' . $trait_id, 
                      file      => 'prediction_pop_gebvs_' . $identifier . '_' . $trait_id,
                      stash_key => 'prediction_pop_gebvs_file'
    };

    $self->cache_file($c, $cache_data);

}


sub list_predicted_selection_pops {
    my ($self, $c, $model_id) = @_;

    my $dir = $c->stash->{solgs_cache_dir};
   
    opendir my $dh, $dir or die "can't open $dir: $!\n";
   
    my  @files  =  grep { /prediction_pop_gebvs_${model_id}_/ && -f "$dir/$_" } 
    readdir($dh); 
   
    closedir $dh; 
    
    my @pred_pops;
    
    foreach (@files) 
    { 
       
        unless ($_ =~ /uploaded/) {
            my ($model_id2, $pred_pop_id, $trait_id) = $_ =~ m/\d+/g;
            
            push @pred_pops, $pred_pop_id;  
        }
    }

    @pred_pops = uniq(@pred_pops);

    $c->stash->{list_of_predicted_selection_pops} = \@pred_pops;

}


sub download_prediction_GEBVs :Path('/solgs/download/prediction/model') Args(4) {
    my ($self, $c, $pop_id, $prediction, $prediction_id, $trait_id) = @_;   
 
    $self->get_trait_details($c, $trait_id);
    $c->stash->{pop_id} = $pop_id;
   
    my $identifier = $pop_id . "_" . $prediction_id;
    $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    my $prediction_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    
    unless (!-e $prediction_gebvs_file || -s $prediction_gebvs_file == 0) 
    {
        my @prediction_gebvs =  map { [ split(/\t/) ] }  read_file($prediction_gebvs_file);
    
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @prediction_gebvs);
    }
 
}


sub prediction_pop_analyzed_traits {
    my ($self, $c, $training_pop_id, $prediction_pop_id) = @_;
           
    my $dir = $c->stash->{solgs_cache_dir};
    my @pred_files;
   
    opendir my $dh, $dir or die "can't open $dir: $!\n";
   
    no warnings 'uninitialized';
  
    my $prediction_is_uploaded = $c->stash->{uploaded_prediction};
  
    #$prediction_pop_id = "uploaded_${prediction_pop_id}" if $prediction_is_uploaded;
 
    if ($training_pop_id !~ /$prediction_pop_id/) 
    {
	my  @files  =  grep { /prediction_pop_gebvs_${training_pop_id}_${prediction_pop_id}/ && -s "$dir/$_" > 0 } 
                 readdir($dh); 
   
	closedir $dh; 
 
	my @trait_ids;

	if ($files[0]) 
	{
	    my @copy_files = @files;
   
	    @trait_ids = map { s/prediction_pop_gebvs_${training_pop_id}_${prediction_pop_id}_//g ? $_ : 0} @copy_files;
 
	    my @traits = ();
	    if(@trait_ids) 
	    {
		foreach my $trait_id (@trait_ids)
		{ 
		    $trait_id =~ s/s+//g;
		    $self->get_trait_details($c, $trait_id);
		    push @traits, $c->stash->{trait_abbr};
		}
	    }
   
	    $c->stash->{prediction_pop_analyzed_traits}       = \@traits;
	    $c->stash->{prediction_pop_analyzed_traits_ids}   = \@trait_ids;
	    $c->stash->{prediction_pop_analyzed_traits_files} = \@files;
	} 
    }
    
}


sub download_prediction_urls {
    my ($self, $c, $training_pop_id, $prediction_pop_id) = @_;
 
    my $selection_traits_ids;
    my $selection_traits_files;
    my $download_url;# = $c->stash->{download_prediction};
    my $model_tr_id = $c->stash->{trait_id};
   
    my $page = $c->req->referer;
    my $base = $c->req->base;
   
    my $data_set_type = 'combined populations' if $page =~ /combined/;

    if ( $base !~ /localhost/)
    {
	$base =~ s/:\d+//; 
	$base =~ s/http\w?/https/;
    }
 
    $page    =~ s/$base//;

    no warnings 'uninitialized';

    if ($prediction_pop_id)
    {
        $self->prediction_pop_analyzed_traits($c, $training_pop_id, $prediction_pop_id);
        $selection_traits_ids = $c->stash->{prediction_pop_analyzed_traits_ids};
	$selection_traits_files = $c->stash->{prediction_pop_analyzed_traits_files};
    } 

    if ($page =~ /solgs\/model\/combined\/populations\// )
    { 
	($model_tr_id) = $page =~ /(\d+)$/;
	$model_tr_id   =~ s/s+//g;
    }

    if ($page =~ /solgs\/trait\// )
    { 
	$model_tr_id = (split '/', $page)[2];
    }

    if ($page =~ /(\/uploaded\/prediction\/)/ && $page !~ /(\solgs\/traits\/all)/)
    { 
	($model_tr_id) = $page =~ /(\d+)$/;
	$model_tr_id =~ s/s+//g;	
    }
     
    my ($trait_is_predicted) = grep {/$model_tr_id/ } @$selection_traits_ids;
    my @selection_traits_ids = uniq(@$selection_traits_ids);

    foreach my $trait_id (@selection_traits_ids) 
    {
	$trait_id =~ s/s+//g;
        $self->get_trait_details($c, $trait_id);

        my $trait_abbr = $c->stash->{trait_abbr};
        my $trait_name = $c->stash->{trait_name};
	

	if ($page =~ /solgs\/traits\/all\/|solgs\/models\/combined\//)
	{
	    $model_tr_id   = $trait_id;
	    $download_url .= " | " if $download_url;     
	}

	if ($selection_traits_files->[0] =~ $prediction_pop_id && $trait_id == $model_tr_id)
	{
	    if ($data_set_type =~ /combined populations/)
	    {
		$download_url .= qq |<a href="/solgs/selection/$prediction_pop_id/model/combined/$training_pop_id/trait/$trait_id">$trait_abbr</a> |;
	    }
	    else 
	    {
		$download_url .= qq |<a href="/solgs/selection/$prediction_pop_id/model/$training_pop_id/trait/$trait_id">$trait_abbr</a> |;
	    }	      
	}        
    }

    if ($download_url) 
    {    
        $c->stash->{download_prediction} = $download_url;         
    }
    else
    {        
        $c->stash->{download_prediction} = qq | <a href ="/solgs/model/$training_pop_id/prediction/$prediction_pop_id"  onclick="solGS.waitPage(this.href); return false;">[ Predict ]</a> |;

	$c->stash->{download_prediction} = undef if $c->stash->{uploaded_prediction};
    }
  
}
    

sub model_accuracy {
    my ($self, $c) = @_;
    my $file = $c->stash->{validation_file};
    my @report =();

    if ( !-e $file) { @report = (["Validation file doesn't exist.", "None"]);}
    if ( -s $file == 0) { @report = (["There is no cross-validation output report.", "None"]);}
    
    if (!@report) 
    {
        @report =  map  { [ split(/\t/, $_) ]}  read_file($file);
    }

    shift(@report); #add condition

    $c->stash->{accuracy_report} = \@report;
 
}


sub model_parameters {
    my ($self, $c) = @_;

    $self->variance_components_file($c);
    my $file = $c->stash->{variance_components_file};
   
    my @params =  map  { [ split(/\t/, $_) ]}  read_file($file);

    shift(@params); #add condition

    $c->stash->{model_parameters} = \@params;
   
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
	    $trait_abbr = $self->abbreviate_term($trait_name);
	}	
    } 
   
    my $abbr = $self->abbreviate_term($trait_name);
       
    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;
    $c->stash->{trait_def}  = $trait_def;
    $c->stash->{trait_abbr} = $abbr;

}

#creates and writes a list of GEBV files of 
#traits selected for ranking genotypes.
sub get_gebv_files_of_traits {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};
    $c->stash->{model_id} = $pop_id;
    my $pred_pop_id = $c->stash->{prediction_pop_id};
   
    my $dir = $c->stash->{solgs_cache_dir};
    
    my $gebv_files;
    my $valid_gebv_files;
    my $pred_gebv_files;
   
    if ($pred_pop_id && $pred_pop_id != $pop_id) 
    {
        $self->prediction_pop_analyzed_traits($c, $pop_id, $pred_pop_id);
        $pred_gebv_files = $c->stash->{prediction_pop_analyzed_traits_files};
        
        foreach (@$pred_gebv_files)
        {
	    my$gebv_file = catfile($dir, $_);
	    $gebv_files .= $gebv_file;
            $gebv_files .= "\t" unless (@$pred_gebv_files[-1] eq $_);
        }     
    } 
    else
    {
        $self->analyzed_traits($c);
        my @analyzed_traits_files = @{$c->stash->{analyzed_traits_files}};

        foreach my $tr_file (@analyzed_traits_files) 
        {
            $gebv_files .= $tr_file;
            $gebv_files .= "\t" unless ($analyzed_traits_files[-1] eq $tr_file);
        }
        
        my @analyzed_valid_traits_files = @{$c->stash->{analyzed_valid_traits_files}};

        foreach my $tr_file (@analyzed_valid_traits_files) 
        {
            $valid_gebv_files .= $tr_file;
            $valid_gebv_files .= "\t" unless ($analyzed_valid_traits_files[-1] eq $tr_file);
        }


    }
   
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id; 
    
    my $name = "gebv_files_of_traits_${pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $self->create_tempfile($temp_dir, $name);
   
    write_file($file, $gebv_files);
   
    $c->stash->{gebv_files_of_traits} = $file;

    my $name2 = "gebv_files_of_valid_traits_${pop_id}${pred_file_suffix}";
    my $file2 = $self->create_tempfile($temp_dir, $name2);
   
    write_file($file2, $valid_gebv_files);
   
    $c->stash->{gebv_files_of_valid_traits} = $file2;

}


sub gebv_rel_weights {
    my ($self, $c, $params, $pred_pop_id) = @_;
    
    my $pop_id      = $c->stash->{pop_id};
  
    my $rel_wts = "trait" . "\t" . 'relative_weight' . "\n";
    foreach my $tr (keys %$params)
    {      
        my $wt = $params->{$tr};
        unless ($tr eq 'rank')
        {
            $rel_wts .= $tr . "\t" . $wt;
            $rel_wts .= "\n";
        }
    }
  
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id; 
    
    my $name = "rel_weights_${pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $self->create_tempfile($temp_dir, $name);
    write_file($file, $rel_wts);
    
    $c->stash->{rel_weights_file} = $file;
    
}


sub ranked_genotypes_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id = $c->stash->{pop_id};
 
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;
  
    my $name = "ranked_genotypes_${pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $self->create_tempfile($temp_dir, $name);
    $c->stash->{ranked_genotypes_file} = $file;
   
}


sub selection_index_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id      = $c->stash->{pop_id};
   
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;

    my $name = "selection_index_${pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $self->create_tempfile($temp_dir, $name);
    $c->stash->{selection_index_file} = $file;
   
}


sub download_ranked_genotypes :Path('/solgs/download/ranked/genotypes/pop') Args(2) {
    my ($self, $c, $pop_id, $genotypes_file) = @_;   
 
    $c->stash->{pop_id} = $pop_id;
  
    $genotypes_file = catfile($c->stash->{solgs_tempfiles_dir}, $genotypes_file);
  
    unless (!-e $genotypes_file || -s $genotypes_file == 0) 
    {
        my @ranks =  map { [ split(/\t/) ] }  read_file($genotypes_file);
    
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @ranks);
    } 

}


sub rank_genotypes : Private {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id      = $c->stash->{pop_id};
    $c->stash->{prediction_pop_id} = $pred_pop_id;

    my $input_files = join("\t", 
                           $c->stash->{rel_weights_file},
                           $c->stash->{gebv_files_of_traits}
        );
   
    $self->ranked_genotypes_file($c, $pred_pop_id);
    $self->selection_index_file($c, $pred_pop_id);

    my $output_files = join("\t",
                            $c->stash->{ranked_genotypes_file},
                            $c->stash->{selection_index_file}
        );
    
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;
    
    my $name = "output_rank_genotypes_${pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $output_file = $self->create_tempfile($temp_dir, $name);
    write_file($output_file, $output_files);
       
    $name = "input_rank_genotypes_${pop_id}${pred_file_suffix}";
    my $input_file = $self->create_tempfile($temp_dir, $name);
    write_file($input_file, $input_files);
    
    $c->stash->{output_files} = $output_file;
    $c->stash->{input_files}  = $input_file;   
    $c->stash->{r_temp_file}  = "rank-gebv-genotypes-${pop_id}${pred_file_suffix}";  
    $c->stash->{r_script}     = 'R/solGS/selection_index.r';
    
    $self->run_r_script($c);
    $self->download_urls($c);
    $self->get_top_10_selection_indices($c);
}


sub get_top_10_selection_indices {
    my ($self, $c) = @_;
    
    my $si_file = $c->stash->{selection_index_file};
  
    my $si_data = $self->convert_to_arrayref_of_arrays($c, $si_file);
    my @top_genotypes = @$si_data[0..9];
    
    $c->stash->{top_10_selection_indices} = \@top_genotypes;
}


sub convert_to_arrayref_of_arrays {
    my ($self, $c, $file) = @_;

    open my $fh, $file or die "couldnot open $file: $!";    
    
    my @data;   
    while (<$fh>)
    {
        push @data,  map { [ split(/\t/) ]  } $_ if $_;
    }
   
    if (@data) 
    {
	shift(@data);
	return \@data;
    } else 
    {
	return;
    }    
}


sub trait_phenotype_file {
    my ($self, $c, $pop_id, $trait) = @_;

    my $dir = $c->stash->{solgs_cache_dir};
    my $exp = "phenotype_trait_${trait}_${pop_id}";
    my $file = $self->grep_file($dir, $exp);
   
    $c->stash->{trait_phenotype_file} = $file;

}


sub check_selection_pops_list :Path('/solgs/check/selection/populations') Args(1) {
    my ($self, $c, $tr_pop_id) = @_;

    $c->stash->{training_pop_id} = $tr_pop_id;

    $self->list_of_prediction_pops_file($c, $tr_pop_id);
    my $pred_pops_file = $c->stash->{list_of_prediction_pops_file};
   
    my $ret->{result} = 0;
   
    if (-s $pred_pops_file) 
    {  
	$self->list_of_prediction_pops($c, $tr_pop_id);
	$ret->{data} =  $c->stash->{list_of_prediction_pops};                
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
    while (my $row = $rs->next) {  
        $pop_id =  $row->id;
    }
  
    my $ret->{population_id} = $pop_id;    
    $ret = to_json($ret);     
   
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub check_training_population :Path('/solgs/check/training/population/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;

    $self->check_population_is_training_population($c);
    my $is_training_pop = $c->stash->{is_training_population};

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
    my ($self, $c) = @_;

    my $pr_id = $c->stash->{pop_id};
    my $is_gs = $c->model("solGS::solGS")->get_project_type($pr_id);

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
	$c->stash->{is_training_population} = 1;
    }
 
}


sub check_population_has_phenotype {
    my ($self, $c) = @_;

    my $pr_id = $c->stash->{pop_id};
    my $is_gs = $c->model("solGS::solGS")->get_project_type($pr_id);
    my $has_phenotype = 1 if $is_gs;

    if ($is_gs !~ /genomic selection/)
    {
	my $cache_dir  = $c->stash->{solgs_cache_dir};
	my $pheno_file = $self->grep_file($cache_dir, "phenotype_data_${pr_id}.txt");		 		 

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

    my $has_genotype;
   
    my $geno_file;
    if ($pop_id =~ /upload/) 
    {	  	
	my $dir       = $c->stash->{solgs_prediction_upload_dir};
	my $user_id   = $c->user->id;
	my $file_name = "genotype_data_${pop_id}";
	$geno_file    = $self->grep_file($dir,  $file_name);
	$has_genotype = 1 if -s $geno_file;  	
    }

    unless ($has_genotype) 
    {
	$has_genotype = $c->model('solGS::solGS')->has_genotype($pop_id);
    }	
  
    $c->stash->{population_has_genotype} = $has_genotype;

}


sub check_selection_population_relevance :Path('/solgs/check/selection/population/relevance') Args() {
    my ($self, $c) = @_;

    my $data_set_type      = $c->req->param('data_set_type');  
    my $training_pop_id    = $c->req->param('training_pop_id');
    my $selection_pop_name = $c->req->param('selection_pop_name');
    my $trait_id           = $c->req->param('trait_id');    
    
    $c->stash->{data_set_type} = $data_set_type;

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
	    $self->check_population_has_genotype($c);
	    $has_genotype = $c->stash->{population_has_genotype};
	}  

	my $similarity;
	if ($has_genotype)
	{
	    $c->stash->{pop_id} = $selection_pop_id;

	    $self->first_stock_genotype_data($c, $selection_pop_id);
	    my $selection_pop_geno_file = $c->stash->{first_stock_genotype_file};

	    my $training_pop_geno_file;
	
	    if ($training_pop_id =~ /upload/) 
	    {	  	
		my $dir = $c->stash->{solgs_prediction_upload_dir};
		my $user_id = $c->user->id;
		my $tr_geno_file = "genotype_data_${training_pop_id}";
		$training_pop_geno_file = $self->grep_file($dir,  $tr_geno_file);  	
	    }
	    else 
	    {
		my $dir = $c->stash->{solgs_cache_dir}; 
		my $tr_geno_file;
	
		if ($data_set_type =~ /combined populations/) 
		{
		    $self->get_trait_details($c, $trait_id);
		    my $trait_abbr = $c->stash->{trait_abbr}; 
		    $tr_geno_file  = "genotype_data_${training_pop_id}_${trait_abbr}";
		}
		else
		{
		    $tr_geno_file = "genotype_data_${training_pop_id}";
		}
		
		$training_pop_geno_file = $self->grep_file($dir,  $tr_geno_file); 
	    }

	    $similarity = $self->compare_marker_set_similarity([$selection_pop_geno_file, $training_pop_geno_file]);
	} 

	my $selection_pop_data;
	if ($similarity >= 0.5 ) 
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

    $self->list_of_prediction_pops_file($c, $training_pop_id);
    my $selection_pops_file = $c->stash->{list_of_prediction_pops_file};

    my @existing_pops_ids = split(/\n/, read_file($selection_pops_file));
   
    my @uniq_ids = unique(@existing_pops_ids, @$selection_pop_id);
    my $formatted_ids = join("\n", @uniq_ids);
       
    write_file($selection_pops_file, $formatted_ids);

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

    $self->list_of_prediction_pops_file($c, $training_pop_id);
    my $pred_pops_file = $c->stash->{list_of_prediction_pops_file};
  
    my @pred_pops_ids = split(/\n/, read_file($pred_pops_file));
 
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

                  $pred_pop_link = qq | <a href="/solgs/model/$training_pop_id/prediction/$prediction_pop_id" 
                                      onclick="solGS.waitPage(this.href); return false;"><input type="hidden" value=\'$id_pop_name\'>$name</data> 
                                      </a> 
                                    |;

                  my $pr_yr_rs = $c->model('solGS::solGS')->project_year($prediction_pop_id);
                  my $project_yr;

                  while ( my $yr_r = $pr_yr_rs->next )
                  {
                      $project_yr = $yr_r->value;
                  }
		 
                  $self->download_prediction_urls($c, $training_pop_id, $prediction_pop_id);
                  my $download_prediction = $c->stash->{download_prediction};

                  push @data,  [$pred_pop_link, $desc, $project_yr, $download_prediction];
             # }
          }
        }
    }

    $c->stash->{selection_pops_list} = \@data;

}


sub list_of_prediction_pops_file {
    my ($self, $c, $training_pop_id)= @_;

    my $cache_data = {key       => 'list_of_prediction_pops' . $training_pop_id,
                      file      => 'list_of_prediction_pops_' . $training_pop_id,
                      stash_key => 'list_of_prediction_pops_file'
    };

    $self->cache_file($c, $cache_data);

}


sub first_stock_genotype_file {
    my ($self, $c, $pop_id) = @_;
    
    my $cache_data = {key       => 'first_stock_genotype_file'. $pop_id,
                      file      => 'first_stock_genotype_file_' . $pop_id . '.txt',
                      stash_key => 'first_stock_genotype_file'
    };

    $self->cache_file($c, $cache_data);

}


sub prediction_population_file {
    my ($self, $c, $pred_pop_id) = @_;
    
    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};

    my ($fh, $tempfile) = tempfile("prediction_population_${pred_pop_id}-XXXXX", 
                                   DIR => $tmp_dir
        );

    $c->stash->{prediction_pop_id} = $pred_pop_id;

    $self->filtered_selection_genotype_file($c);
    my $filtered_geno_file = $c->stash->{filtered_selection_genotype_file};

    my $geno_files = $filtered_geno_file;  
  
    $self->genotype_file($c, $pred_pop_id);
    $geno_files .= "\t" . $c->stash->{pred_genotype_file};   
  
    $fh->print($geno_files);
    $fh->close; 

    $c->stash->{prediction_population_file} = $tempfile;
  
}


sub combined_pops_catalogue_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'combined_pops_catalogue_file',
                      file      => 'combined_pops_catalogue_file',
                      stash_key => 'combined_pops_catalogue_file'
    };

    $self->cache_file($c, $cache_data);

}


sub catalogue_combined_pops {
    my ($self, $c, $entry) = @_;
    
    $self->combined_pops_catalogue_file($c);
    my $file = $c->stash->{combined_pops_catalogue_file};
  
    if (! -s $file) 
    {
        my $header = 'combo_pops_id' . "\t" . 'population_ids';
        write_file($file, ($header, $entry));    
    }
    else 
    {
        $entry =~ s/\n//;
        my @combo = ($entry);
       
        my (@entries) = map{ $_ =~ s/\n// ? $_ : undef } read_file($file);
        my @intersect = intersect(@combo, @entries);
        unless( @intersect ) 
        {
            write_file($file, {append => 1}, "\n" . "$entry");
        }
    }
    
}


sub get_combined_pops_list {
    my ($self, $c, $combined_pops_id) = @_;

    $self->combined_pops_catalogue_file($c);
    my $combo_pops_catalogue_file = $c->stash->{combined_pops_catalogue_file};
    
    my @combos = uniq(read_file($combo_pops_catalogue_file));
    
    foreach my $entry (@combos)
    {
        if ($entry =~ m/$combined_pops_id/)
        {
	    chomp($entry);
            my ($combo_pops_id, $pops)  = split(/\t/, $entry);
	    my @pops_list = split(',', $pops);
	    $c->stash->{combined_pops_list} = \@pops_list;
            $c->stash->{trait_combo_pops} = \@pops_list;
        }   
    }     

}


sub get_trait_details_of_trait_abbr {
    my ($self, $c) = @_;
    
    my $trait_abbr = $c->stash->{trait_abbr};
   
    if (!$c->stash->{pop_id}) 
    {	
	$c->stash->{pop_id} = $c->stash->{training_pop_id} || $c->stash->{combo_pops_id}; 
    }

    my $trait_id;
   
    my $acronym_pairs = $self->get_acronym_pairs($c);                   
    
    if ($acronym_pairs)
    {
	foreach my $r (@$acronym_pairs) 
	{	    
	    if ($r->[0] eq $trait_abbr) 
	    {
		my $trait_name =  $r->[1];
		$trait_name    =~ s/^\s+|\s+$//g;                                
		
		$trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);
		$self->get_trait_details($c, $trait_id);
	    }
	}
    }

}


sub build_multiple_traits_models {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $prediction_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
  
    my @selected_traits = $c->req->param('trait_id[]');
 
    if (!@selected_traits && $c->stash->{background_job}) 
    { 
	@selected_traits =  @{$c->stash->{selected_traits}};
    }
	#$pop_id = $c->stash->{training_pop_id};

    # 	my $params = $c->stash->{analysis_profile};
    # 	my $args = $params->{arguments};

    # 	my $json = JSON->new();
    # 	$args = $json->decode($args);

    # 	if (keys %{$args}) 
    # 	{     
    # 	    foreach my $k ( keys %{$args} ) 
    # 	    {
    # 		if ($k eq 'trait_id') 
    # 		{
    # 		    @selected_traits = @{ $args->{$k} };
    # 		} 

    # 		if (!$pop_id) 
    # 		{
    # 		    if ($k eq 'population_id') 
    # 		    {
    # 			my @pop_ids = @{ $args->{$k} };
    # 			$c->stash->{pop_id} = $pop_ids[0];
    # 		    }
    # 		}
		
    # 		if ($k eq 'selection_pop_id') 
    # 		{
    # 		    $prediction_id = $args->{$k};
    # 		}
    # 	    }	    
    # 	} 
    # }       
     
    if (!@selected_traits)
    {
	if ($prediction_id) 
	{
	    $c->stash->{model_id} = $pop_id; 
	    
	    $self->traits_with_valid_models($c);
	    @selected_traits = @ {$c->stash->{traits_with_valid_models}};
	}
	else 
	{
	    $c->res->redirect("/solgs/population/$pop_id/selecttraits");
	    $c->detach(); 
	}
    }
    else 
    {  
	my $single_trait_id;
   
	if (scalar(@selected_traits) == 1)
	{
	    $single_trait_id = $selected_traits[0];
	    if ($single_trait_id =~ /\D/)
	    {
		$c->stash->{trait_abbr} = $single_trait_id;
		$self->get_trait_details_of_trait_abbr($c);
		$single_trait_id = $c->stash->{trait_id};
	    }
  
	    if (!$prediction_id)
	    { 
		$c->res->redirect("/solgs/trait/$single_trait_id/population/$pop_id");
		$c->detach();              
	    } 
	    else
	    {
		my $name  = "trait_info_${single_trait_id}_pop_${pop_id}";
		my $temp_dir = $c->stash->{solgs_tempfiles_dir};
		my $file2 = $self->create_tempfile($temp_dir, $name);
		
		$c->stash->{trait_file} = $file2;
		$c->stash->{trait_abbr} = $selected_traits[0];
		$self->get_trait_details_of_trait_abbr($c);
 
		$self->get_rrblup_output($c); 
	    }
	}
	else 
	{
	    my ($traits, $trait_ids);    
        
	    for (my $i = 0; $i <= $#selected_traits; $i++)
	    {  
		if ($selected_traits[$i] =~ /\D/)
		{  
		    $c->stash->{trait_abbr} = $selected_traits[$i];
		    $self->get_trait_details_of_trait_abbr($c);
		    $traits    .= $c->stash->{trait_abbr};
		    $traits    .= "\t" unless ($i == $#selected_traits);
		    $trait_ids .= $c->stash->{trait_id};
		}
		else 
		{
		    my $tr   = $c->model('solGS::solGS')->trait_name($selected_traits[$i]);
		    my $abbr = $self->abbreviate_term($tr);
		    $traits .= $abbr;
		    $traits .= "\t" unless ($i == $#selected_traits); 
                
		    foreach my $tr_id (@selected_traits)
		    {
			$trait_ids .= $tr_id;
		    }
		}                 
	    } 
    
	    if ($c->stash->{data_set_type} =~ /combined populations/)
	    {
		my $identifier = crc($trait_ids);
		$self->combined_gebvs_file($c, $identifier);
	    }  
	    
	    my $name = "selected_traits_pop_${pop_id}";
	    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	    my $file = $self->create_tempfile($temp_dir, $name);
	    
	    write_file($file, $traits);
	    $c->stash->{selected_traits_file} = $file;

	    $name     = "trait_info_${single_trait_id}_pop_${pop_id}";
	    my $file2 = $self->create_tempfile($temp_dir, $name);
	    
	    $c->stash->{trait_file} = $file2;
	    $self->get_rrblup_output($c); 
	}
    }

}


sub traits_to_analyze :Regex('^solgs/analyze/traits/population/([\w|\d]+)(?:/([\d+]+))?') {
    my ($self, $c) = @_; 
   
    my ($pop_id, $prediction_id) = @{$c->req->captures};
 
    my $req = $c->req->param('source');
    
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{prediction_pop_id} = $prediction_id;
   
    $self->build_multiple_traits_models($c);
  
    my $referer    = $c->req->referer;   
    my $base       = $c->req->base;
    $referer       =~ s/$base//;
    my ($tr_id)    = $referer =~ /(\d+)/;
    my $trait_page = "solgs/trait/$tr_id/population/$pop_id";

    my $error = $c->stash->{script_error};
  
    if ($error) 
    {
        $c->stash->{message} = "$error can't create prediction models for the selected traits. 
                                 There are problems with the datasets of the traits.
                                 <p><a href=\"/solgs/population/$pop_id\">[ Go back ]</a></p>";

        $c->stash->{template} = "/generic_message.mas"; 
    } 
    elsif ($req =~ /AJAX/)
    {     
    	my $ret->{status} = 'success';
  
        $ret = to_json($ret);
        
        $c->res->content_type('application/json');
        $c->res->body($ret);       
    }
     else
    {
        if ($referer =~ m/$trait_page/) 
        { 
            $c->res->redirect("/solgs/trait/$tr_id/population/$pop_id");
            $c->detach(); 
        }
        else 
        {
            $c->res->redirect("/solgs/traits/all/population/$pop_id/$prediction_id");
            $c->detach(); 
        }
    }

}


sub all_traits_output :Regex('^solgs/traits/all/population/([\w|\d]+)(?:/([\d+]+))?') {
     my ($self, $c) = @_;
         
     my ($pop_id, $pred_pop_id) = @{$c->req->captures};

     my @traits = $c->req->param; 
     @traits    = grep {$_ ne 'rank'} @traits;
     $c->stash->{training_pop_id} = $pop_id;
     $c->stash->{pop_id} = $pop_id;
          
     if ($pred_pop_id)
     {
         $c->stash->{prediction_pop_id} = $pred_pop_id;
         $c->stash->{population_is} = 'prediction population';
         $self->prediction_population_file($c, $pred_pop_id);
        
         my $pr_rs = $c->model('solGS::solGS')->project_details($pred_pop_id);
         
         while (my $row = $pr_rs->next) 
         {
             $c->stash->{prediction_pop_name} = $row->name;
         }
     }
     else
     {
         $c->stash->{prediction_pop_id} = undef;
         $c->stash->{population_is} = 'training population';
     }
    
     $c->stash->{model_id} = $pop_id; 
     $self->analyzed_traits($c);

     my @analyzed_traits = @{$c->stash->{analyzed_traits}};
    
     if (!@analyzed_traits) 
     { 
         $c->res->redirect("/solgs/population/$pop_id/selecttraits/");
         $c->detach(); 
     }
   
     my @trait_pages;
     foreach my $tr (@analyzed_traits)
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
                 
	 my $trait_id   = $c->model('solGS::solGS')->get_trait_id($trait_name);
         my $trait_abbr = $c->stash->{trait_abbr}; 
        
         $self->get_model_accuracy_value($c, $pop_id, $trait_abbr);        
         my $accuracy_value = $c->stash->{accuracy_value};

         $c->controller("solGS::Heritability")->get_heritability($c);
         my $heritability = $c->stash->{heritability};

         push @trait_pages,  [ qq | <a href="/solgs/trait/$trait_id/population/$pop_id">$trait_abbr</a>|, $accuracy_value, $heritability];
       
     }
  
     $self->project_description($c, $pop_id);
     my $project_name = $c->stash->{project_name};
     my $project_desc = $c->stash->{project_desc};
   
     my @model_desc = ([qq | <a href="/solgs/population/$pop_id">$project_name</a> |, $project_desc, \@trait_pages]);
     
     $c->stash->{template}    = $self->template('/population/multiple_traits_output.mas');
     $c->stash->{trait_pages} = \@trait_pages;
     $c->stash->{model_data}  = \@model_desc;
    
     my $acronym = $self->get_acronym_pairs($c);
     $c->stash->{acronym} = $acronym;
 
}


sub selection_index_form :Path('/solgs/selection/index/form') Args(0) {
    my ($self, $c) = @_;
    
    my $pred_pop_id = $c->req->param('pred_pop_id');
    my $training_pop_id = $c->req->param('training_pop_id');
   
    $c->stash->{model_id} = $training_pop_id;
    $c->stash->{prediction_pop_id} = $pred_pop_id;
   
    my @traits;
    if (!$pred_pop_id) 
    {    
        $self->analyzed_traits($c);
        @traits = @{ $c->stash->{selection_index_traits} }; 
    }
    else  
    {
        $self->prediction_pop_analyzed_traits($c, $training_pop_id, $pred_pop_id);
        @traits = @{ $c->stash->{prediction_pop_analyzed_traits} };
    }

    my $ret->{status} = 'success';
    $ret->{traits} = \@traits;
     
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
    
}


sub traits_with_valid_models {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
 
    $self->analyzed_traits($c);
    
    my @analyzed_traits = @{$c->stash->{analyzed_traits}};  
    my @filtered_analyzed_traits;

    foreach my $analyzed_trait (@analyzed_traits) 
    {   
        $self->get_model_accuracy_value($c, $pop_id, $analyzed_trait);        
        my $accuracy_value = $c->stash->{accuracy_value};            
        if ($accuracy_value > 0)
        { 
            push @filtered_analyzed_traits, $analyzed_trait;
        }     
    }

    @filtered_analyzed_traits = uniq(@filtered_analyzed_traits);
    $c->stash->{traits_with_valid_models} = \@filtered_analyzed_traits;

}


sub calculate_selection_index :Path('/solgs/calculate/selection/index') Args(2) {
    my ($self, $c, $model_id, $pred_pop_id) = @_;
    
    $c->stash->{pop_id} = $model_id;

    if ($pred_pop_id =~ /\d+/ && $model_id != $pred_pop_id)
    {
        $c->stash->{prediction_pop_id} = $pred_pop_id;       
    }
    else
    {
        $pred_pop_id = undef;
        $c->stash->{prediction_pop_id} = $pred_pop_id;
    }

    my @traits = $c->req->param; 
    @traits    = grep {$_ ne 'rank'} @traits;
   
    my @values;
    foreach (@traits)
    {
        push @values, $c->req->param($_);
    }
      
    if (@values) 
    {
        $self->get_gebv_files_of_traits($c);
      
        my $params = $c->req->params;
        $self->gebv_rel_weights($c, $params, $pred_pop_id);
         
        $c->forward('rank_genotypes', [$pred_pop_id]);
         
        my $geno = $self->tohtml_genotypes($c);
        
        my $link         = $c->stash->{ranked_genotypes_download_url};             
        my $ranked_genos = $c->stash->{top_10_selection_indices};
        my $index_file   = $c->stash->{selection_index_file};
       
        my $ret->{status} = 'No GEBV values to rank.';

        if (@$ranked_genos) 
        {
            $ret->{status}     = 'success';
            $ret->{genotypes}  = $geno;
            $ret->{link}       = $link;
            $ret->{index_file} = $index_file;
        }
               
        $ret = to_json($ret);
        
        $c->res->content_type('application/json');
        $c->res->body($ret);
    }     
}


sub combine_populations_confrim  :Path('/solgs/combine/populations/trait/confirm') Args(1) {
    my ($self, $c, $trait_id) = @_;
  
    my (@pop_ids, $ids);
   
    if ($trait_id =~ /\d+/)
    {
        $ids = $c->req->param('confirm_populations');
        @pop_ids = split(/,/, $ids);        
        if (!@pop_ids) {@pop_ids = $ids;}

        $c->stash->{trait_id} = $trait_id;
    } 

    my $pop_links;
    my @selected_pops_details;

    foreach my $pop_id (@pop_ids) 
    {
        my $markers     = $c->model("solGS::solGS")->get_project_genotyping_markers($pop_id);                   
        my @markers     = split(/\t/, $markers);
        my $markers_num = scalar(@markers);
       
        $self->trial_compatibility_table($c, $markers_num);
        my $match_code = $c->stash->{trial_compatibility_code};

        my $pop_rs = $c->model('solGS::solGS')->project_details($pop_id);
       
	$self->get_projects_details($c, $pop_rs);
	#my $pop_details  = $self->get_projects_details($c, $pop_rs);
	my $pop_details  = $c->stash->{projects_details};
        my $pop_name     = $pop_details->{$pop_id}{project_name};
        my $pop_desc     = $pop_details->{$pop_id}{project_desc};
        my $pop_year     = $pop_details->{$pop_id}{project_year};
        my $pop_location = $pop_details->{$pop_id}{project_location};
               
        my $checkbox = qq |<form> <input style="background-color: $match_code;" type="checkbox" checked="checked" name="project" value="$pop_id" /> </form> |;
        
        $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;
    push @selected_pops_details, [$checkbox,  qq|<a href="/solgs/trait/$trait_id/population/$pop_id" onclick="solGS.waitPage()">$pop_name</a>|, 
                               $pop_desc, $pop_location, $pop_year, $match_code
        ];
  
    }
    
    $c->stash->{selected_pops_details} = \@selected_pops_details;    
    $c->stash->{template} = $self->template('/search/result/confirm/populations.mas');

}


sub combine_populations :Path('/solgs/combine/populations/trait') Args(1) {
    my ($self, $c, $trait_id) = @_;
   
    my (@pop_ids, $ids);
  
    if ($trait_id =~ /\d+/)
    {
        $ids = $c->req->param($trait_id);
        @pop_ids = split(/,/, $ids);

        $self->get_trait_details($c, $trait_id);
    } 
   
    my $combo_pops_id;
    my $ret->{status} = 0;

    if (scalar(@pop_ids) > 1 )
    {  
        $combo_pops_id =  crc(join('', @pop_ids));
        $c->stash->{combo_pops_id} = $combo_pops_id;
        $c->stash->{trait_combo_pops} = $ids;
    
        $c->stash->{trait_combine_populations} = \@pop_ids;

        $self->multi_pops_phenotype_data($c, \@pop_ids);
        $self->multi_pops_genotype_data($c, \@pop_ids);
	$self->multi_pops_geno_files($c, \@pop_ids);
	$self->multi_pops_pheno_files($c, \@pop_ids);

        my $geno_files = $c->stash->{multi_pops_geno_files};
        my @g_files = split(/\t/, $geno_files);

        $self->compare_genotyping_platforms($c, \@g_files);
        my $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};
     
        if (!$not_matching_pops) 
        {
            $self->cache_combined_pops_data($c);

            my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
            my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
             
            unless (-s $combined_pops_geno_file  && -s $combined_pops_pheno_file ) 
            {
                $self->r_combine_populations($c);
                
                $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
                $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
            }
                       
            if (-s $combined_pops_pheno_file > 1 && -s $combined_pops_geno_file > 1) 
            {
                my $tr_abbr = $c->stash->{trait_abbr};  
                $c->stash->{data_set_type} = 'combined populations';                
                $self->get_rrblup_output($c); 
                my $analysis_result = $c->stash->{combo_pops_analysis_result};
                  
                $ret->{pop_ids}       = $ids;
                $ret->{combo_pops_id} = $combo_pops_id; 
                $ret->{status}        = $analysis_result;
	  
                my $entry = "\n" . $combo_pops_id . "\t" . $ids;
                $self->catalogue_combined_pops($c, $entry);
              }           
        }
        else 
        {
            $ret->{not_matching_pops} = $not_matching_pops;
        }
    }
    else 
    {
        my $pop_id = $pop_ids[0];
        $ret->{redirect_url} = "/solgs/trait/$trait_id/population/$pop_id";
    }
       
    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub get_model_accuracy_value {
    my ($self, $c, $model_id, $trait_abbr) = @_;
 
    my $dir = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir or die "can't open $dir: $!\n";
    
    my ($validation_file)  = grep { /cross_validation_${trait_abbr}_${model_id}/ && -f "$dir/$_" } 
    readdir($dh);  
 
    closedir $dh; 
        
    $validation_file = catfile($dir, $validation_file);
       
    my ($row) = grep {/Average/} read_file($validation_file);
    my ($text, $accuracy_value) = split(/\t/,  $row);
 
    $c->stash->{accuracy_value} = $accuracy_value;
  
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


sub combined_pops_summary {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
 
    $self->get_combined_pops_list($c, $combo_pops_id);
    my @pops_ids = @{$c->stash->{trait_combo_pops}};
  
    my $desc = 'This training population is a combination of ';    
    my $projects_owners;

    foreach my $pop_id (@pops_ids)
    {  
        my $pr_rs = $c->model('solGS::solGS')->project_details($pop_id);

        while (my $row = $pr_rs->next)
        {
         
            my $pr_id   = $row->id;
            my $pr_name = $row->name;
            $desc .= qq | <a href="/solgs/population/$pr_id">$pr_name </a>|; 
            $desc .= $pop_id == $pops_ids[-1] ? '.' : ' and ';
        } 

        $self->get_project_owners($c, $_);
        my $project_owners = $c->stash->{project_owners};

        unless (!$project_owners)
        {
             $projects_owners.= $projects_owners ? ', ' . $project_owners : $project_owners;
        }
    }
   
    my $trait_abbr = $c->stash->{trait_abbr};
    my $trait_id = $c->stash->{trait_id};
  
    $self->filtered_training_genotype_file($c);
    my $filtered_geno_file  = $c->stash->{filtered_training_genotype_file};

    $self->cache_combined_pops_data($c);
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
    my @unfiltered_geno_rows = read_file($combined_pops_geno_file);
 
    my $markers_no;
    my @geno_lines;

    if (-s $filtered_geno_file) {
	my @rows = read_file($filtered_geno_file);
	$markers_no = scalar(split('\t', $rows[0])) - 1;
    } 
    else 
    {
	$markers_no = scalar(split ('\t', $unfiltered_geno_rows[0])) - 1;	
    }

    my $stocks_no   =  scalar(@unfiltered_geno_rows) - 1;
    my $training_pop = "Training population $combo_pops_id";
    
    my $protocol = $c->config->{default_genotyping_protocol};
    $protocol = 'N/A' if !$protocol;

    $c->stash(markers_no   => $markers_no,
              stocks_no    => $stocks_no,
              project_desc => $desc,
              project_name => $training_pop,
              owner        => $projects_owners,
	      protocol     => $protocol,
        );

}


sub compare_marker_set_similarity {
    my ($self, $marker_file_pair) = @_;

    my $file_1 = $marker_file_pair->[0];
    my $file_2 = $marker_file_pair->[1];

    my $first_markers = (read_file($marker_file_pair->[0]))[0];
    my $sec_markers   = (read_file($marker_file_pair->[1]))[0];
 
    my @first_geno_markers = split(/\t/, $first_markers);
    my @sec_geno_markers   = split(/\t/, $sec_markers);

    if ( @first_geno_markers && @first_geno_markers) 
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
           
            my $list_type_pop = $c->stash->{uploaded_prediction};
          
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
    $self->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};
   
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;
 

 
    # if ($dependency && $background_job) 
    # {
    # 	my $dependent_job_script  = $self->create_tempfile($c, "compare_trials_job", "pl");

    # 	my $cmd = '#!/usr/bin/env perl;' . "\n";
    # 	$cmd   .= 'use strict;' . "\n";
    # 	$cmd   .= 'use warnings;' . "\n\n\n";
    # 	$cmd   .= 'system("Rscript --slave ' 
    # 	    . $in_file_temp 
    # 	    . ' --args ' . $input_files . ' ' . $output_files 
    # 	    . ' | qsub -W ' .  $dependency . '");';

    # 	write_file($dependent_job_script, $cmd);
    # 	chmod 0755, $dependent_job_script;
	
    # 	$r_job = CXGN::Tools::Run->run_cluster('perl', 
    #         $dependent_job_script,
    #         $out_file_temp,
    #         {
    #             working_dir => $c->stash->{solgs_tempfiles_dir},
    #             max_cluster_jobs => 1_000_000_000,
    #         },
    #         );
    # } 


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


sub cache_combined_pops_data {
    my ($self, $c) = @_;

    my $trait_id      = $c->stash->{trait_id};
    my $trait_abbr    = $c->stash->{trait_abbr};
    my $combo_pops_id = $c->stash->{combo_pops_id};

    my  $cache_pheno_data = {key       => "phenotype_data_trait_${trait_id}_${combo_pops_id}_combined",
                             file      => "phenotype_data_${combo_pops_id}_${trait_abbr}_combined",
                             stash_key => 'trait_combined_pheno_file'
    };
      
    my  $cache_geno_data = {key       => "genotype_data_trait_${trait_abbr}_${combo_pops_id}_combined",
                            file      => "genotype_data_${combo_pops_id}_${trait_abbr}_combined",
                            stash_key => 'trait_combined_geno_file'
    };

    
    $self->cache_file($c, $cache_pheno_data);
    $self->cache_file($c, $cache_geno_data);

}


sub multi_pops_pheno_files {
    my ($self, $c, $pop_ids) = @_;
 
    my $trait_id = $c->stash->{trait_id};
    my $dir = $c->stash->{solgs_cache_dir};
    my $files;
   
    if (defined reftype($pop_ids) && reftype($pop_ids) eq 'ARRAY')
    {
        foreach my $pop_id (@$pop_ids) 
        {
	    my $exp = 'phenotype_data_' . $pop_id . '.txt';
            $files .= catfile($dir, $exp);
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id); 		
        }

        $c->stash->{multi_pops_pheno_files} = $files;

    }
    else 
    {
        my $exp = 'phenotype_data_' . ${pop_ids} . '.txt';
        $files = catfile($dir, $exp);
    }

    if ($trait_id)
    {
        my $name = "trait_${trait_id}_multi_pheno_files";
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $tempfile = $self->create_tempfile($temp_dir, $name);
        write_file($tempfile, $files);
    }
 
}


sub multi_pops_geno_files {
    my ($self, $c, $pop_ids) = @_;
 
    my $trait_id = $c->stash->{trait_id};
    my $dir = $c->stash->{solgs_cache_dir};
    my $files;
    
    if (defined reftype($pop_ids) && reftype($pop_ids) eq 'ARRAY')
    {
        foreach my $pop_id (@$pop_ids) 
        {
            my $exp = 'genotype_data_' . $pop_id . '.txt';
            $files .= catfile($dir, $exp);        
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id);    
        }
        $c->stash->{multi_pops_geno_files} = $files;
    }
    else 
    {
        my $exp = 'genotype_data_' . ${pop_ids} . '.txt';
        $files = catfile($dir, $exp);
    }

    if ($trait_id)
    {
        my $name = "trait_${trait_id}_multi_geno_files";
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $tempfile = $self->create_tempfile($temp_dir, $name);
        write_file($tempfile, $files);
    }
    
}


sub create_tempfile {
    my ($self, $dir, $name, $ext) = @_;
    
    $ext = '.' . $ext if $ext;
    
    my ($fh, $file) = tempfile($name . "-XXXXX", 
			       SUFFIX => $ext,
                               DIR => $dir,
        );
    
    $fh->close; 
    
    return $file;

}


sub grep_file {
    my ($self, $dir, $exp) = @_;

    opendir my $dh, $dir 
        or die "can't open $dir: $!\n";

    my ($file)  = grep { /^$exp/ && -f "$dir/$_" }  readdir($dh);
    close $dh;
   
    if ($file)    
    {
        $file = catfile($dir, $file);
    }
 
    return $file;
}


sub multi_pops_phenotype_data {
    my ($self, $c, $pop_ids) = @_;
   
    no warnings 'uninitialized';
    my @job_ids;
    if (@$pop_ids)
    {
        foreach my $pop_id (@$pop_ids)        
        { 
            $c->stash->{pop_id} = $pop_id;
            $self->phenotype_file($c);
	    push @job_ids, $c->stash->{r_job_id};
        }
	
	if (@job_ids)
	{
	    @job_ids = uniq(@job_ids);
	    $c->stash->{multi_pops_pheno_jobs_ids} = \@job_ids;
	}
    }
    
   
  #  $self->multi_pops_pheno_files($c, $pop_ids);
    
}


sub multi_pops_genotype_data {
    my ($self, $c, $pop_ids) = @_;
   
    no warnings 'uninitialized';
    my @job_ids;
    if (@$pop_ids)
    {
        foreach my $pop_id (@$pop_ids)        
        {
            $c->stash->{pop_id} = $pop_id;
            $self->genotype_file($c);	    
	    push @job_ids, $c->stash->{r_job_id};
        }

	if (@job_ids) 
	{
	    @job_ids = uniq(@job_ids);
	    $c->stash->{multi_pops_geno_jobs_ids} = \@job_ids;
	}
    }    
#  $self->multi_pops_geno_files($c, $pop_ids);
 
}


sub phenotype_graph :Path('/solgs/phenotype/graph') Args(0) {
    my ($self, $c) = @_;

    my $pop_id        = $c->req->param('pop_id');
    my $trait_id      = $c->req->param('trait_id');
    my $combo_pops_id = $c->req->param('combo_pops_id');

    $self->get_trait_details($c, $trait_id);

    $c->stash->{pop_id}        = $pop_id;
    $c->stash->{combo_pops_id} = $combo_pops_id;

    $c->stash->{data_set_type} = 'combined populations' if $combo_pops_id;
  
    $self->trait_phenodata_file($c);

    my $trait_pheno_file = $c->{stash}->{trait_phenodata_file};
    my $trait_data = $self->convert_to_arrayref_of_arrays($c, $trait_pheno_file);

    my $ret->{status} = 'failed';
    
    if (@$trait_data) 
    {            
        $ret->{status} = 'success';
        $ret->{trait_data} = $trait_data;
    } 
    
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


#generates descriptive stat for a trait phenotype data
sub trait_phenotype_stat {
    my ($self, $c) = @_; 
    
    $self->trait_phenodata_file($c);

    my $trait_pheno_file = $c->{stash}->{trait_phenodata_file};

    my $trait_data = $self->convert_to_arrayref_of_arrays($c, $trait_pheno_file);
    
    my @desc_stat;
    my $background_job = $c->stash->{background_job};
   
    if ($trait_data && !$background_job)
    {
	my @pheno_data;   
	foreach (@$trait_data) 
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
	my $cnt  = scalar(@$trait_data);
	my $cv   = ($std / $mean) * 100;
	my $na   = scalar(@$trait_data) - scalar(@pheno_data);

	if ($na == 0) { $na = '--'; }

	my $round = Math::Round::Var->new(0.01);
	$std  = $round->round($std);
	$mean = $round->round($mean);
	$cv   = $round->round($cv);
	$cv   = $cv . '%';

	@desc_stat =  ( [ 'Total no. of genotypes', $cnt ],
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

    my $pop_id            = $c->req->param('pop_id');
    my $trait_id          = $c->req->param('trait_id');
    my $prediction_pop_id = $c->req->param('selection_pop_id');
    my $combo_pops_id     = $c->req->param('combo_pops_id');
    
    if ($combo_pops_id)
    {
	$self->get_combined_pops_list($c, $combo_pops_id);
	$c->stash->{data_set_type} = 'combined populations';
	$pop_id = $combo_pops_id;
    }

   

    $c->stash->{pop_id} = $pop_id;
    $c->stash->{combo_pops_id} = $combo_pops_id; 
    $c->stash->{prediction_pop_id} = $prediction_pop_id;
   
    $self->get_trait_details($c, $trait_id);
    
    my $page = $c->req->referer();
    my $gebv_file;

    if ($page =~ /solgs\/selection\//) 
    {   	
        my $identifier =  $pop_id . '_' . $prediction_pop_id;
        $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
   
        $gebv_file = $c->stash->{prediction_pop_gebvs_file}; 
    }
    else
    { 
        $self->gebv_kinship_file($c);
        $gebv_file = $c->stash->{gebv_kinship_file};
       
    }

    my $gebv_data = $self->convert_to_arrayref_of_arrays($c, $gebv_file);

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


sub tohtml_genotypes {
    my ($self, $c) = @_;
  
    my $genotypes = $c->stash->{top_10_selection_indices};
    my %geno = ();

    foreach (@$genotypes)
    {
        $geno{$_->[0]} = $_->[1];
    }
    return \%geno;
}


sub get_single_trial_traits {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    $self->traits_list_file($c);
    my $traits_file = $c->stash->{traits_list_file};
    
    if (!-s $traits_file)
    {
	my $traits_rs = $c->model('solGS::solGS')->project_traits($pop_id);
	
	my @traits_list;
	
	while (my $row = $traits_rs->next)
	{
	    push @traits_list, $row->name;	    
	}
	
	my $traits = join("\t", @traits_list);
	write_file($traits_file, $traits);
    }

}


sub get_all_traits {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};
    
    $self->traits_list_file($c);
    my $traits_file = $c->stash->{traits_list_file};
    
    if (!-s $traits_file)
    {
	my $page = $c->req->path;    

	if ($page =~ /solgs\/population\//)
	{
	    $self->get_single_trial_traits($c);
	}
    }  
    
    my $traits = read_file($traits_file);
    
    $self->traits_acronym_file($c);
    my $acronym_file = $c->stash->{traits_acronym_file};
   
    unless (-s $acronym_file)
    {
	my @filtered_traits = split(/\t/, $traits);
	my $count = scalar(@filtered_traits);

	my $acronymized_traits = $self->acronymize_traits(\@filtered_traits);    
	my $acronym_table = $acronymized_traits->{acronym_table};

	$self->traits_acronym_table($c, $acronym_table);
    }
	
    $self->create_trait_data($c);       
}


sub create_trait_data {
    my ($self, $c) = @_;   
       
    my $table = 'trait_id' . "\t" . 'trait_name' . "\t" . 'acronym' . "\n"; 
   
    my $acronym_pairs = $self->get_acronym_pairs($c);
    
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

    $self->all_traits_file($c);
    my $traits_file =  $c->stash->{all_traits_file};
    write_file($traits_file, $table);
}


sub all_traits_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    #$pop_id = $c->stash->{combo_pops_id} if !$pop_id;

    my $cache_data = {key       => 'all_traits_pop' . $pop_id,
                      file      => 'all_traits_pop_' . $pop_id,
                      stash_key => 'all_traits_file'
    };

    $self->cache_file($c, $cache_data);

}


sub traits_list_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
   # $pop_id = $c->stash->{combo_pops_id} if !$pop_id;

    my $cache_data = {key       => 'traits_list_pop' . $pop_id,
                      file      => 'traits_list_pop_' . $pop_id,
                      stash_key => 'traits_list_file'
    };

    $self->cache_file($c, $cache_data);

}


sub get_acronym_pairs {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
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
        @acronym_pairs =  map { [ split(/\t/) ] }  read_file($acronyms_file);   
        shift(@acronym_pairs); # remove header;
    }

    @acronym_pairs = sort {uc $a->[0] cmp uc $b->[0] } @acronym_pairs;

    $c->stash->{acronym} = \@acronym_pairs;
    
    return \@acronym_pairs;
    
}


sub traits_acronym_table {
    my ($self, $c, $acronym_table) = @_;
    
    my $table = 'Acronym' . "\t" . 'Trait name' . "\n"; 

    foreach (keys %$acronym_table)
    {
        $table .= $_ . "\t" . $acronym_table->{$_} . "\n";
    }

    $self->traits_acronym_file($c);
    my $acronym_file =  $c->stash->{traits_acronym_file};
    
    write_file($acronym_file, $table);

}


sub traits_acronym_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    #$pop_id = $c->stash->{combo_pops_id} if !$pop_id;

    my $cache_data = {key       => 'traits_acronym_pop' . $pop_id,
                      file      => 'traits_acronym_pop_' . $pop_id,
                      stash_key => 'traits_acronym_file'
    };

    $self->cache_file($c, $cache_data);

}


sub analyzed_traits {
    my ($self, $c) = @_;
    
    my $training_pop_id = $c->stash->{model_id} || $c->stash->{training_pop_id}; 

    my $dir = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir or die "can't open $dir: $!\n";
    
    my @all_files = grep { /gebv_kinship_[a-zA-Z0-9]/ && -f "$dir/$_" } 
    readdir($dh); 

    closedir $dh;
   
    my @traits_files = map { catfile($dir, $_)} 
                       grep {/($training_pop_id)/} 
                       @all_files;
    
    my @traits;
    my @traits_ids;
    my @si_traits;
    my @valid_traits_files;
 
    foreach my $trait_file  (@traits_files) 
    {  
        if (-s $trait_file > 1) 
        { 
            my $trait = $trait_file;
            $trait =~ s/gebv_kinship_//;
            $trait =~ s/$training_pop_id|_|combined_pops//g;
            $trait =~ s/$dir|\///g;

            my $acronym_pairs = $self->get_acronym_pairs($c);                   
            if ($acronym_pairs)
            {
                foreach my $r (@$acronym_pairs) 
                {                    
                    if ($r->[0] eq $trait) 
                    {
                        my $trait_name =  $r->[1];
                        $trait_name    =~ s/\n//g;                                                       
                        my $trait_id   =  $c->model('solGS::solGS')->get_trait_id($trait_name);
                       
                        push @traits_ids, $trait_id;                                               
                    }
                }
            }
            
            $self->get_model_accuracy_value($c, $training_pop_id, $trait);
            my $av = $c->stash->{accuracy_value};
                      
            if ($av && $av =~ m/\d+/ && $av > 0) 
            { 
              push @si_traits, $trait;
              push @valid_traits_files, $trait_file;
            }
                           
            push @traits, $trait;
        }      
        else 
        {
            @traits_files = grep { $_ ne $trait_file } @traits_files;
        }
    }
        
    $c->stash->{analyzed_traits}        = \@traits;
    $c->stash->{analyzed_traits_ids}    = \@traits_ids;
    $c->stash->{analyzed_traits_files}  = \@traits_files;
    $c->stash->{selection_index_traits} = \@si_traits;
    $c->stash->{analyzed_valid_traits_files}  = \@valid_traits_files;
   
}


sub filter_phenotype_header {
    my ($self, $c) = @_;
       
    my @headers = ( 'studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber' );

    my $meta_headers = join("\t", @headers);
    if ($c) 
    {
	$c->stash->{filter_phenotype_header} = $meta_headers;
    }
    else 
    {    	
	return $meta_headers;
    }

}


sub abbreviate_term {
    my ($self, $term) = @_;
  
    my @words = split(/\s/, $term);
    
    my $acronym;
	
    if (scalar(@words) == 1) 
    {
	$acronym = shift(@words);
    }  
    else 
    {
	foreach my $word (@words) 
        {
	    if ($word =~ /^\D/)
            {
		my $l = substr($word,0,1,q{}); 
		$acronym .= $l;
	    } 
            else 
            {
                $acronym .= $word;
            }

	    $acronym = uc($acronym);
	    $acronym =~/(\w+)/;
	    $acronym = $1; 
	}	   
    }
  
    return $acronym;

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
       
	$c->stash( template    => $self->template('/search/traits/list.mas'),
                   index       => $index,
                   traits_list => \@traits_list
            );
    }
    else 
    {
        $c->forward('search');
    }
}


sub submit_cluster_phenotype_query {
    my ($self, $c, $args) = @_;

    $c->stash->{r_temp_file} = 'phenotype-data-query';
    $self->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};
   
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;
 
    try 
    { 
        my $pheno_job = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["SGN::Controller::solGS::solGS" => "prep_phenotype_file"],
    	    args          => [$args],
    	    load_packages => ['SGN::Controller::solGS::solGS', 'SGN::Context', 'SGN::Model::solGS::solGS'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },
	    
         });

	$c->stash->{r_job_tempdir} = $pheno_job->tempdir();
	$c->stash->{r_job_id} = $pheno_job->job_id();
	$c->stash->{cluster_job} = $pheno_job;

	unless ($background_job)
	{ 
	    $pheno_job->wait();
	}	
    }
    catch 
    {
	$status = $_;
	$status =~ s/\n at .+//s;           
    };
 

}


sub submit_cluster_genotype_query {
    my ($self, $c, $args) = @_;

    $c->stash->{r_temp_file} = 'genotype-data-query';
    $self->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};
   
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;
 
    try 
    { 
        my $geno_job = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["SGN::Controller::solGS::solGS" => "prep_genotype_file"],
    	    args          => [$args],
    	    load_packages => ['SGN::Controller::solGS::solGS', 'SGN::Context', 'SGN::Model::solGS::solGS'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },
	    
         });

	$c->stash->{r_job_tempdir} = $geno_job->tempdir();
	$c->stash->{r_job_id} = $geno_job->job_id();
	$c->stash->{cluster_job} = $geno_job;

	unless ($background_job)
	{
	    $geno_job->wait();
	}
	
    }
    catch 
    {
	$status = $_;
	$status =~ s/\n at .+//s;           
    }; 

}


sub prep_phenotype_file {
    my ($self,$args) = @_;
    
    my $pheno_file  = $args->{phenotype_file};
    my $pop_id      = $args->{population_id};
    my $traits_file = $args->{traits_list_file};
 
    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});
   
    my $pheno_data = $model->phenotype_data($pop_id);

    if ($pheno_data)
    {
	my $pheno_data = SGN::Controller::solGS::solGS->format_phenotype_dataset($pheno_data, $traits_file);
	write_file($pheno_file, $pheno_data);
    }
    
}


sub first_stock_genotype_data {
    my ($self, $c, $pr_id) = @_;
 
    $self->first_stock_genotype_file($c, $pr_id);
    my $geno_file  = $c->stash->{first_stock_genotype_file};
 
    my $geno_data = $c->model('solGS::solGS')->first_stock_genotype_data($pr_id);

    if ($geno_data)
    {
	write_file($geno_file, $geno_data);
    }
}


sub prep_genotype_file {
    my ($self, $args) = @_;
    
    my $geno_file  = $args->{genotype_file}; 
    my $pop_id     = ($args->{prediction_id} ? $args->{prediction_id} : $args->{population_id});
 
    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});
 
    my $geno_data = $model->genotype_data($args);
   
    if ($geno_data)
    {
	write_file($geno_file, $geno_data);
    }
    
}


sub phenotype_file {
    my ($self, $c) = @_;
    my $pop_id     = $c->stash->{pop_id} || $c->stash->{training_pop_id};
   
    die "Population id must be provided to get the phenotype data set." if !$pop_id;
    $pop_id =~ s/combined_//;
    
    if ($c->stash->{uploaded_reference} || $pop_id =~ /uploaded/) {	
	if (!$c->user) {
	    
	    my $page = "/" . $c->req->path;
	 
	    $c->res->redirect("/solgs/list/login/message?page=$page");
	    $c->detach;   

	}	
    }
 
    $self->phenotype_file_name($c, $pop_id);
    my $pheno_file = $c->stash->{phenotype_file_name};

    no warnings 'uninitialized';
    
    unless ( -s $pheno_file)
    {  	   	    
	$self->traits_list_file($c);
	my $traits_file =  $c->stash->{traits_list_file};
	
	my $args = {
	    'population_id'    => $pop_id,
	    'phenotype_file'   => $pheno_file,
	    'traits_list_file' => $traits_file,
	};
	   
	if (!$c->stash->{uploaded_reference}) 
	{
	    $self->submit_cluster_phenotype_query($c, $args);
	}	    
    }

   
    $c->stash->{phenotype_file} = $pheno_file;   

}


sub format_phenotype_dataset {
    my ($self, $data_ref, $traits_file) = @_;
   
    my $data = $$data_ref;
    my @rows = split (/\n/, $data);
   
    my $formatted_headers = $self->format_phenotype_dataset_headers($rows[0], $traits_file);   
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
    my ($self, $raw_headers, $traits_file) = @_;

    $raw_headers =~ s/\|\w+:\d+//g;
    $raw_headers =~ s/\n//g; 
    
    my $traits = $raw_headers;
  
    my $meta_headers=  $self->filter_phenotype_header();
    my @mh = split("\t", $meta_headers);
    foreach my $mh (@mh) {
       $traits =~ s/($mh)//g;
    }

    $traits =~ s/^\s+|\s+$//g;

    write_file($traits_file, $traits) if $traits_file;   
    my  @filtered_traits = split(/\t/, $traits);

    $raw_headers =~ s/$traits//g;
    my $acronymized_traits = $self->acronymize_traits(\@filtered_traits);
    my $formatted_headers = $raw_headers . $acronymized_traits->{acronymized_traits}; 
   
    return $formatted_headers;
    
}


sub acronymize_traits {
    my ($self, $traits) = @_;
  
    my $acronym_table = {};  
    my $cnt = 0;
    my $acronymized_traits;

    foreach my $trait_name (@$traits)
    {
	$cnt++;
        my $abbr = $self->abbreviate_term($trait_name);

	$abbr = $abbr . '.2' if $cnt > 1 && $acronym_table->{$abbr};  

        $acronymized_traits .= $abbr;
	$acronymized_traits .= "\t" unless $cnt == scalar(@$traits);
	
        $acronym_table->{$abbr} = $trait_name if $abbr;
	my $tr_h = $acronym_table->{$abbr};
    }
 
    my $acronym_data = {
	'acronymized_traits' => $acronymized_traits,
	'acronym_table'      => $acronym_table
    };

    return $acronym_data;
}


sub genotype_file  {
    my ($self, $c, $pred_pop_id) = @_;
   
    my $pop_id  = $c->stash->{pop_id};
    my $geno_file;

    if ($pred_pop_id) 
    {      
        $pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id}; 
        $geno_file = $c->stash->{user_selection_list_genotype_data_file}; 
    } 
    
    die "Population id must be provided to get the genotype data set." if !$pop_id;
  
    if ($c->stash->{uploaded_reference} || $pop_id =~ /uploaded/) 
    {
  	if (!$c->user)
	{
	    my $path = "/" . $c->req->path;
	    $c->res->redirect("/solgs/list/login/message?page=$path");
	    $c->detach;
	}
    }

    unless ($geno_file)
    {
	$self->genotype_file_name($c, $pop_id);
	$geno_file = $c->stash->{genotype_file_name};
    }

    no warnings 'uninitialized';

    unless (-s $geno_file)
    {  
	my $model_id = $c->stash->{model_id};
	
	my $dir = ($model_id =~ /uploaded/) 
	    ? $c->stash->{solgs_prediction_upload_dir} 
	    : $c->stash->{solgs_cache_dir};

	my $trait_abbr = $c->stash->{trait_abbr};

	my $tr_file = ($c->stash->{data_set_type} =~ /combined/) 
	    ? "genotype_data_${model_id}_${trait_abbr}_combined" 
	    : "genotype_data_${model_id}.txt";
	
	my $tr_geno_file = catfile($dir, $tr_file);

	my $args = {
	    'population_id' => $pop_id,
	    'prediction_id' => $pred_pop_id,
	    'model_id'      => $model_id,
	    'tr_geno_file'  => $tr_geno_file,
	    'genotype_file' => $geno_file,
	    'cache_dir'     => $c->stash->{solgs_cache_dir},
	};

	$self->submit_cluster_genotype_query($c, $args);
    }
   
    if ($pred_pop_id) 
    {
        $c->stash->{pred_genotype_file} = $geno_file;
    }
    else 
    {
        $c->stash->{genotype_file} = $geno_file; 
    }
 
}


sub get_rrblup_output {
    my ($self, $c) = @_;
       
    $c->stash->{pop_id} = $c->stash->{combo_pops_id} if $c->stash->{combo_pops_id};
  
    my $pop_id        = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $trait_abbr    = $c->stash->{trait_abbr};
    my $trait_name    = $c->stash->{trait_name};
    my $data_set_type = $c->stash->{data_set_type};  
    my $prediction_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
 
    my ($traits_file, @traits, @trait_pages);  

    if ($trait_abbr)     
    {
        $self->run_rrblup_trait($c, $trait_abbr);
    }
    else 
    {    
        $traits_file = $c->stash->{selected_traits_file};
        my $content  = read_file($traits_file);
     
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
           
            $self->run_rrblup_trait($c, $tr);
           
            my $trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);
            push @trait_pages, [ qq | <a href="/solgs/trait/$trait_id/population/$pop_id" onclick="solGS.waitPage()">$tr</a>| ];
        }    
    }

    $c->stash->{combo_pops_analysis_result} = 0;

    no warnings 'uninitialized';
 
    if ($data_set_type !~ /combined populations/) 
    {
        if (scalar(@traits) == 1) 
        {
            $self->gs_files($c);
            $c->stash->{template} = $self->template('population/trait.mas');
        }
        
        if (scalar(@traits) > 1)    
        {
            $c->stash->{model_id} = $pop_id;
            $self->analyzed_traits($c);
            $c->stash->{template}    = $self->template('/population/multiple_traits_output.mas'); 
            $c->stash->{trait_pages} = \@trait_pages;
        }
    }
    else 
    {
        $c->stash->{combo_pops_analysis_result} = 1;
    }

}


sub run_rrblup_trait {
    my ($self, $c, $trait_abbr) = @_;
    
    my $pop_id        = $c->stash->{pop_id};
    my $trait_name    = $c->stash->{trait_name};
    my $data_set_type = $c->stash->{data_set_type};

    my $trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);
    $c->stash->{trait_id} = $trait_id; 
    
    no warnings 'uninitialized';
    
    if ($data_set_type =~ /combined populations/i) 
    {
        my $prediction_id = $c->stash->{prediction_pop_id};

        $self->output_files($c);

        my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
        my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
	
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $trait_info   = $trait_id . "\t" . $trait_abbr;     
        my $trait_file  = $self->create_tempfile($temp_dir, "trait_info_${trait_id}");
        write_file($trait_file, $trait_info);

        my $dataset_file  = $self->create_tempfile($temp_dir, "dataset_info_${trait_id}");
        write_file($dataset_file, $data_set_type);
 
        my $prediction_population_file = $c->stash->{prediction_population_file};
        	
	my $input_files = join("\t",
                                   $c->stash->{trait_combined_pheno_file},
                                   $c->stash->{trait_combined_geno_file},
                                   $trait_file,
                                   $dataset_file,
                                   $prediction_population_file,
            );

        my $input_file = $self->create_tempfile($temp_dir, "input_files_combo_${trait_abbr}");
        write_file($input_file, $input_files);

        if ($c->stash->{prediction_pop_id})
        {       
            $c->stash->{input_files} = $input_file;
            $self->run_rrblup($c); 
        }
        else
        {       
            if (-s $c->stash->{gebv_kinship_file} == 0 ||
                -s $c->stash->{gebv_marker_file}  == 0 ||
                -s $c->stash->{validation_file}   == 0       
                )
            {  
                $c->stash->{input_files} = $input_file;
               # $self->output_files($c);
                $self->run_rrblup($c);        
            }
        }        
    }
    else 
    {
        my $name  = "trait_info_${trait_id}_pop_${pop_id}"; 
    	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $trait_info = $trait_id . "\t" . $trait_abbr;
        my $file = $self->create_tempfile($temp_dir, $name);    
        $c->stash->{trait_file} = $file;       
        write_file($file, $trait_info);

        my $prediction_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
        $self->output_files($c);
        
        if ($prediction_id)
        { 
            #$prediction_id = "prediction_id} if $c->stash->{uploaded_prediction};
            my $identifier =  $pop_id . '_' . $prediction_id;

            $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
            my $pred_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};

            unless (-s $pred_pop_gebvs_file != 0) 
            { 
                $self->input_files($c); 
                $self->run_rrblup($c); 
            }
        }
        else
        {   
            if (-s $c->stash->{gebv_kinship_file} == 0 ||
                -s $c->stash->{gebv_marker_file}  == 0 ||
                -s $c->stash->{validation_file}   == 0       
                )
            {  
                $self->input_files($c);            
                $self->run_rrblup($c);        
            }
        }
    }
    
}


sub run_rrblup  {
    my ($self, $c) = @_;
   
    #get all input files & arguments for rrblup, 
    #run rrblup and save output in solgs user dir
    my $pop_id        = $c->stash->{pop_id};
    my $trait_id      = $c->stash->{trait_id};
    my $input_files   = $c->stash->{input_files};
    my $output_files  = $c->stash->{output_files};
    my $data_set_type = $c->stash->{data_set_type};
    
    if ($data_set_type !~ /combined populations/)
    {
        die "\nCan't run rrblup without a population id." if !$pop_id;   

    }

    die "\nCan't run rrblup without a trait id." if !$trait_id;
   
    die "\nCan't run rrblup without input files." if !$input_files;
    die "\nCan't run rrblup without output files." if !$output_files;    
    
    if ($data_set_type !~ /combined populations/)
    {
       
        $c->stash->{r_temp_file} = "gs-rrblup-${trait_id}-${pop_id}";
    }
    else
    {
        my $combo_pops = $c->stash->{trait_combo_pops};
        $combo_pops    = join('', split(/,/, $combo_pops));
        my $combo_identifier = crc($combo_pops);

        $c->stash->{r_temp_file} = "gs-rrblup-combo-${trait_id}-${combo_identifier}"; 
    }
   
    $c->stash->{r_script}    = 'R/solGS/gs.r';
    $self->run_r_script($c);

}


sub r_combine_populations  {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id      = $c->stash->{trait_id};
    my $trait_abbr    = $c->stash->{trait_abbr};
 
    my $combo_pops_list = $c->stash->{combined_pops_list};
    my $pheno_files = $c->stash->{multi_pops_pheno_files};  
    my $geno_files  = $c->stash->{multi_pops_geno_files};
    
    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
    
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $trait_info  = $trait_id . "\t" . $trait_abbr;
    my $trait_file  = $self->create_tempfile($temp_dir, "trait_info_${trait_id}");
    write_file($trait_file, $trait_info); 
  
    my $input_files = join ("\t",
                            $pheno_files,
                            $geno_files,
                            $trait_file,   
        );
    
    my $output_files = join ("\t", 
                             $combined_pops_pheno_file,
                             $combined_pops_geno_file,
        );
                             
    my $tempfile_input = $self->create_tempfile($temp_dir, "input_files_${trait_id}_combine"); 
    write_file($tempfile_input, $input_files);

    my $tempfile_output = $self->create_tempfile($temp_dir, "output_files_${trait_id}_combine"); 
    write_file($tempfile_output, $output_files);
        
    die "\nCan't call combine populations R script without a trait id." if !$trait_id;
    die "\nCan't call combine populations R script without input files." if !$input_files;
    die "\nCan't call combine populations R script without output files." if !$output_files;    
    
    $c->stash->{input_files}  = $tempfile_input;
    $c->stash->{output_files} = $tempfile_output;
    $c->stash->{r_temp_file}  = "combine-pops-${trait_id}";
    $c->stash->{r_script}     = 'R/solGS/combine_populations.r';
    
    $self->run_r_script($c);
  
}


sub create_cluster_acccesible_tmp_files {
    my ($self, $c) = @_;

    my $temp_file_template = $c->stash->{r_temp_file};

    CXGN::Tools::Run->temp_base($c->stash->{solgs_tempfiles_dir});
    my ( $in_file_temp, $out_file_temp, $err_file_temp) =
        map 
    {
        my ( undef, $filename ) =
            tempfile(
                catfile(
                    CXGN::Tools::Run->temp_base(),
                    "${temp_file_template}-$_-XXXXXX",
                ),
            );
        $filename
    } 
    qw / in out err/;

    $c->stash( 
	in_file_temp  => $in_file_temp,
	out_file_temp => $out_file_temp,
	err_file_temp => $err_file_temp,
	);

}


sub run_async {
    my ($self, $c) = @_;    

    my $dependency          = $c->stash->{dependency};
    my $dependency_type     = $c->stash->{dependency_type};
    my $background_job      = $c->stash->{background_job};
    my $dependent_job       = $c->stash->{dependent_job};
    my $temp_file_template  = $c->stash->{r_temp_file};  
    my $job_type            = $c->stash->{job_type};
    my $model_file          = $c->stash->{gs_model_args_file};
    my $combine_pops_job_id = $c->stash->{combine_pops_job_id};
    my $solgs_tmp_dir       = "'" . $c->stash->{solgs_tempfiles_dir} . "'";
  
    my $r_script      = $c->stash->{r_commands_file};
    my $r_script_args =  $c->stash->{r_script_args};

    if ($combine_pops_job_id) 
    {
	$dependency = $combine_pops_job_id;       
    }
  
    $dependency =~ s/^://;

    my $script_args;
    foreach my $arg (@$r_script_args) 
    {     
	$script_args .= $arg;
	$script_args .= ' --script_args ' unless ($r_script_args->[-1] eq $arg);
    }
    
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $report_file = $self->create_tempfile($temp_dir, 'analysis_report_args');
    $c->stash->{report_file} = $report_file;

    my $cmd = 'mx-run solGS::DependentJob'
	. ' --dependency_jobs '           . $dependency
    	. ' --dependency_type '           . $dependency_type
	. ' --temp_dir '                  . $solgs_tmp_dir
    	. ' --temp_file_template '        . $temp_file_template
    	. ' --analysis_report_args_file ' . $report_file
	. ' --dependent_type '            . $job_type;

     if ($r_script) 
     {
	 $cmd .= ' --r_script '          . $r_script 
	     .  ' --script_args '        . $script_args 
	     .  ' --gs_model_args_file ' . $model_file;	
     }

    $c->stash->{r_temp_file} = 'run-async';
    $self->create_cluster_acccesible_tmp_files($c);

    my $err_file_temp = $c->stash->{err_file_temp};
    my $out_file_temp = $c->stash->{out_file_temp};

    my $async =  CXGN::Tools::Run->run_async($cmd,
			     {
				 working_dir      => $c->stash->{solgs_tempfiles_dir},
				 temp_base        => $c->stash->{solgs_tempfiles_dir},
				 max_cluster_jobs => 1_000_000_000,
				 out_file         => $out_file_temp,
				 err_file         => $err_file_temp,
			     }
     );
 
    #my $async_pid = $async->pid();
   
    #$c->stash->{async_pid}        = $async_pid;
    #$c->stash->{r_job_tempdir}    = $async->tempdir();
    #$c->stash->{r_job_id}         = $async->job_id();
 
   # if ($c->stash->{r_script} =~ /combine_populations/)
   # {
    # 	$c->stash->{combine_pops_job_id} = $async->job_id(); 
    #   #$c->stash->{r_job_tempdir}    = $async->tempdir();
    #   #$c->stash->{r_job_id}         = $async->job_id();
    #  # $c->stash->{cluster_job} = $r_job;
  #  }
 
}


sub run_r_script {
    my ($self, $c) = @_;
    
    my $r_script     = $c->stash->{r_script};
    my $input_files  = $c->stash->{input_files};
    my $output_files = $c->stash->{output_files};
  
    $self->create_cluster_acccesible_tmp_files($c);
    my $in_file_temp   = $c->stash->{in_file_temp};
    my $out_file_temp  = $c->stash->{out_file_temp};
    my $err_file_temp  = $c->stash->{err_file_temp};

    my $dependency      = $c->stash->{dependency};
    my $dependency_type = $c->stash->{dependency_type};
    my $background_job  = $c->stash->{background_job};
  
    {
        my $r_cmd_file = $c->path_to($r_script);
        copy($r_cmd_file, $in_file_temp)
            or die "could not copy '$r_cmd_file' to '$in_file_temp'";
    }
  
    if ($dependency && $background_job) 
    {
	$c->stash->{r_commands_file}    = $in_file_temp;
	$c->stash->{r_script_args}      = [$input_files, $output_files];

	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	$c->stash->{gs_model_args_file} = $self->create_tempfile($temp_dir, 'gs_model_args');
	
	if ($r_script =~ /combine_populations/) 
	{	    
	    $c->stash->{job_type} = 'combine_populations'; 	      
	    $self->run_async($c);
	}
	elsif ($r_script =~ /gs/)
	{
	    $c->stash->{job_type} = 'model';

	    my $model_job = {
		'r_command_file' => $in_file_temp,
		'input_files'    => $input_files,
		'output_files'   => $output_files,
		'r_output_file'  => $out_file_temp,
		'err_temp_file'  => $err_file_temp,
	    };

	    my $model_file = $c->stash->{gs_model_args_file};
	   
	    nstore $model_job, $model_file 
		or croak "gs r script: $! serializing model details to '$model_file'";
	    
	    if ($dependency_type =~ /combine_populations|download_data/)
	    {
	     	$self->run_async($c);
	    }
	}
    } 
    else 
    {   
	my $r_job = CXGN::Tools::Run->run_cluster('R', 'CMD', 'BATCH',
						  '--slave',
						  "--args $input_files $output_files",
						  $in_file_temp,
						  $out_file_temp,
						  {
						      working_dir => $c->stash->{solgs_tempfiles_dir},
						      max_cluster_jobs => 1_000_000_000,
						  });
	try 
	{ 
	    $c->stash->{r_job_tempdir} = $r_job->tempdir();
	    $c->stash->{r_job_id} = $r_job->job_id();
	   # $c->stash->{cluster_job} = $r_job;

	    if ($r_script =~ /combine_populations/) 
	    {	    
		#$c->stash->{job_type} = 'combine_populations'; 	   
		$c->stash->{combine_pops_job_id} = $r_job->job_id();
		
		my $temp_dir = $c->stash->{solgs_tempfiles_dir};
		$c->stash->{gs_model_args_file} = $self->create_tempfile($temp_dir, 'gs_model_args');
		#$self->run_async($c);
	    }

	    unless ($background_job)
	    {
		$r_job->wait();
	    }
	}
	catch 
	{
	    my $err = $_;
	    $err =~ s/\n at .+//s; 
        
	    try
	    { 
		$err .= "\n=== R output ===\n"
		    .file($out_file_temp)->slurp
		    ."\n=== end R output ===\n"; 
	    };
            
	    $c->stash->{script_error} = "$r_script";
	};  
    }
   
}
 
 
sub get_solgs_dirs {
    my ($self, $c) = @_;
        
    my $geno_version    = $c->config->{default_genotyping_protocol};    
    $geno_version       =~ s/\s+//g;
    my $tmp_dir         = $c->site_cluster_shared_dir;    
    $tmp_dir            = catdir($tmp_dir, $geno_version);
    my $solgs_dir       = catdir($tmp_dir, "solgs");
    my $solgs_cache     = catdir($tmp_dir, 'solgs', 'cache'); 
    my $solgs_tempfiles = catdir($tmp_dir, 'solgs', 'tempfiles');  
    my $correlation_dir = catdir($tmp_dir, 'correlation', 'cache');   
    my $solgs_upload    = catdir($tmp_dir, 'solgs', 'tempfiles', 'prediction_upload');
    my $pca_dir         = catdir($tmp_dir, 'pca', 'cache');
    my $histogram_dir   = catdir($tmp_dir, 'histogram', 'cache');
    my $log_dir         = catdir($tmp_dir, 'log', 'cache');

    mkpath (
	[
	 $solgs_dir, $solgs_cache, $solgs_tempfiles, $solgs_upload, 
	 $correlation_dir, $pca_dir, $histogram_dir, $log_dir
	], 
	0, 0755
	);
   
    $c->stash(solgs_dir                   => $solgs_dir, 
              solgs_cache_dir             => $solgs_cache, 
              solgs_tempfiles_dir         => $solgs_tempfiles,
              solgs_prediction_upload_dir => $solgs_upload,
              correlation_dir             => $correlation_dir,
	      pca_dir                     => $pca_dir,
	      histogram_dir               => $histogram_dir,
	      analysis_log_dir            => $log_dir
        );

}


sub cache_file {
    my ($self, $c, $cache_data) = @_;
  
    my $cache_dir = $c->stash->{cache_dir};
   
    unless ($cache_dir) 
    {
	$cache_dir = $c->stash->{solgs_cache_dir};
    }
   
    my $file_cache  = Cache::File->new(cache_root => $cache_dir, 
				       lock_level => Cache::File::LOCK_NFS()
	);

    $file_cache->purge();

    my $file  = $file_cache->get($cache_data->{key});
    
    no warnings 'uninitialized';
    
    unless (-s $file > 1)
    {      
        $file = catfile($cache_dir, $cache_data->{file});
        write_file($file);
        $file_cache->set($cache_data->{key}, $file, '30 days');
    }

    $c->stash->{$cache_data->{stash_key}} = $file;
    $c->stash->{cache_dir} = $c->stash->{solgs_cache_dir};
}


sub template {
    my ($self, $file) = @_;

    $file =~ s/(^\/)//; 
    my $dir = '/solgs';
 
    return  catfile($dir, $file);

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

    $self->get_solgs_dirs($c);
  
}


# sub end : Private {
#     my ( $self, $c ) = @_;

#     return if @{$c->error};

#     # don't try to render a default view if this was handled by a CGI
#     $c->forward('render') unless $c->req->path =~ /\.pl$/;

#     # enforce a default texest/html content type regardless of whether
#     # we tried to render a default view
#     $c->res->content_type('text/html') unless $c->res->content_type;

#     # insert our javascript packages into the rendered view
#     if( $c->res->content_type eq 'text/html' ) {
#         $c->forward('/js/insert_js_pack_html');
#         $c->res->headers->push_header('Vary', 'Cookie');
#     } else {
#         $c->log->debug("skipping JS pack insertion for page with content type ".$c->res->content_type)
#             if $c->debug;
#     }

# }

=head2 auto

Run for every request to the site.

=cut

# sub auto : Private {
#     my ($self, $c) = @_;
#     CatalystX::GlobalContext->set_context( $c );
#     $c->stash->{c} = $c;
#     weaken $c->stash->{c};

#     $self->get_solgs_dirs($c);
#     # gluecode for logins
#     #
# #  #   unless( $c->config->{'disable_login'} ) {
#    #      my $dbh = $c->dbc->dbh;
#    #      if ( my $sp_person_id = CXGN::Login->new( $dbh )->has_session ) {

#    #          my $sp_person = CXGN::People::Person->new( $dbh, $sp_person_id);

#    #          $c->authenticate({
#    #              username => $sp_person->get_username(),
#    #              password => $sp_person->get_password(),
#    #          });
#    #      }
#    # }

#     return 1;
# }




=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
