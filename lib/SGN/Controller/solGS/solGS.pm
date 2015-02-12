package SGN::Controller::solGS::solGS;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
#use CatalystX::GlobalContext ();
use Statistics::Descriptive;
use Math::Round::Var;
use Algorithm::Combinatorics qw /combinations/;
use Array::Utils qw(:all);
#use CXGN::Login;
#use CXGN::People::Person;
use CXGN::Tools::Run;
use JSON;

#use jQuery::File::Upload;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

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


sub details_form : Path('/solgs/form/population/details') Args(0) {
    my ($self, $c) = @_;

    $self->load_yaml_file($c, 'population/details.yml');
    my $form = $c->stash->{form}; 
   
    if ($form->submitted_and_valid ) 
    {
        $c->res->redirect('/solgs/form/population/phenotype');
    }
    else 
    {
        $c->stash(template => $self->template('/form/population/details.mas'),
                  form     => $form
            );
    }
}


sub phenotype_form : Path('/solgs/form/population/phenotype') Args(0) {
    my ($self, $c) = @_;
    
    $self->load_yaml_file($c, 'population/phenotype.yml');
    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) 
    {
      $c->res->redirect('/solgs/form/population/genotype');
    }        
    else
    {
        $c->stash(template => $self->template('/form/population/phenotype.mas'),
                  form     => $form
            );
    }

}


sub genotype_form : Path('/solgs/form/population/genotype') Args(0) {
    my ($self, $c) = @_;

    $self->load_yaml_file($c, 'population/genotype.yml');
    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) 
    {
      $c->res->redirect('/solgs/population/12');
    }        
    else
    {
        $c->stash(template => $self->template('/form/population/genotype.mas'),
                  form     => $form
            );
    }

}


sub search : Path('/solgs/search') Args() {
    my ($self, $c) = @_;

    $self->load_yaml_file($c, 'search/solgs.yml');
    my $form = $c->stash->{form};

    $self->gs_traits_index($c);
    my $gs_traits_index = $c->stash->{gs_traits_index};
        
    my $query;
    if ($form->submitted_and_valid) 
    {
        $query = $form->param_value('search.search_term');
        $c->res->redirect("/solgs/search/result/traits/$query");       
    }        
    else
    {
        $c->stash(template        => $self->template('/search/solgs.mas'),
                  form            => $form,
                  message         => $query,                 
                  gs_traits_index => $gs_traits_index,           
            );
    }

}


sub search_trials : Path('/solgs/search/trials') Args() {
    my ($self, $c) = @_;

    my $page = $c->req->param('page') || 1;

    my $project_rs = $c->model('solGS::solGS')->all_projects($page, 15);
   
    $self->projects_links($c, $project_rs);
    my $projects = $c->stash->{projects_pages};
    
    my $page_links =  sub {uri ( query => {  page => shift } ) };
    
    my $pager = $project_rs->pager; 
    $pager->change_entries_per_page(15);

    my $pagination;
    my $url = '/solgs/search/trials/';
   
    if ( $pager->previous_page || $pager->next_page )
    {
        $pagination =   '<div class = "paginate_nav">';
        
        if( $pager->previous_page ) 
        {
            $pagination .=  '<a class="paginate_nav" href="' . $url .  $page_links->($pager->previous_page) . '">&lt;</a>';
        }
        
        for my $c_page ( $pager->first_page .. $pager->last_page ) 
        {
            if( $pager->current_page == $c_page ) 
            {
                $pagination .=  '<span class="paginate_nav_currpage paginate_nav">' .  $c_page . '</span>';
            }
            else 
            {
                $pagination .=  '<a class="paginate_nav" href="' . $url.   $page_links->($c_page) . '">' . $c_page . '</a>';
            }
        }
        if( $pager->next_page ) 
        {
            $pagination .= '<a class="paginate_nav" href="' . $url . $page_links->($pager->next_page). '">&gt;</a>';
        }
        
        $pagination .= '</div>';
    }

    my $ret->{status} = 'failed';
    
    if (@$projects) 
    {            
        $ret->{status} = 'success';
        $ret->{pagination} = $pagination;
        $ret->{trials}   = $projects;
    } 
    else 
    { 
        if ($pager->current_page == $pager->last_page) 
        {
          $c->res->redirect("/solgs/search/trials/?page=1");  
        }
        else 
        {
            my $go_next = $pager->current_page + 1;
            $c->res->redirect("/solgs/search/trials/?page=$go_next");
        }
    } 
    
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
    

}


sub projects_links {
    my ($self, $c, $pr_rs) = @_;

    my $projects = $self->get_projects_details($c, $pr_rs);

    my @projects_pages;
   
    foreach my $pr_id (keys %$projects) 
    {
         my $pr_name     = $projects->{$pr_id}{project_name};
         my $pr_desc     = $projects->{$pr_id}{project_desc};
         my $pr_year     = $projects->{$pr_id}{project_year};
         my $pr_location = $projects->{$pr_id}{project_location};
  
         my $dummy_name = $pr_name =~ /test\w*/ig;
         my $dummy_desc = $pr_desc =~ /test\w*/ig;
       
         my ($has_genotype, $has_phenotype, $is_gs);
        
         unless ($dummy_name || $dummy_desc || !$pr_name )
         {   
	     $is_gs = $c->model("solGS::solGS")->get_project_type($pr_id);
	  
	     if (!$is_gs || $is_gs !~ /genomic selection/)
	     {
		 $has_phenotype = $c->model("solGS::solGS")->has_phenotype($pr_id);
	     }
	     else 
	     {
		 $has_phenotype = 'yes';
	     }
         }

         my $marker_count;
         if ($has_phenotype) 
         {
	     my $genotype_prop = $c->model("solGS::solGS")->get_project_genotypeprop($pr_id);
	     $marker_count = $genotype_prop->{'marker_count'};
	 }

	 if (!$marker_count && $has_phenotype) 
	 {
	     my $markers = $c->model("solGS::solGS")->get_genotyping_markers($pr_id);
	     
	     unless (!$markers) 
	      {
		 my @markers = split(/\t/, $markers);
		 $marker_count = scalar(@markers);
		  
		 my $genoprop = {'project_id' => $pr_id, 'marker_count' => $marker_count};
		 $c->model("solGS::solGS")->set_project_genotypeprop($genoprop);
	     }	    
	 }         
         
	 my $match_code;
	 if ($marker_count) 
	 {
	     $self->trial_compatibility_table($c, $marker_count);
	     $match_code = $c->stash->{trial_compatibility_code};
	 } 
         
	 if ($marker_count && $has_phenotype)
	 {
	     unless ($is_gs) 
	     {
		 my $pr_prop = {'project_id' => $pr_id, 
				'project_type' => 'genomic selection', 
		 };
		 
		 $c->model("solGS::solGS")->set_project_type($pr_prop);		 
		
	     }

	     my $pop_prop = {'project_id' => $pr_id, 
			     'population type' => 'training population', 
	     };
	   
	     $c->model("solGS::solGS")->set_population_type($pop_prop);
	     
             my $checkbox = qq |<form> <input type="checkbox" name="project" value="$pr_id" onclick="getPopIds()"/> </form> |;

             $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;

             push @projects_pages, [$checkbox, qq|<a href="/solgs/population/$pr_id" onclick="solGS.waitPage()">$pr_name</a>|, 
                                    $pr_desc, $pr_location, $pr_year, $match_code
             ];            
	 }
	 elsif ($marker_count && !$has_phenotype)	 
	 {
	     my $pop_prop = {'project_id' => $pr_id, 
			     'population type' => 'selection population', 
	     };

	     $c->model("solGS::solGS")->set_population_type($pop_prop);	      
	 }  
    }

    $c->stash->{projects_pages} = \@projects_pages;
}


sub search_trials_trait : Path('/solgs/search/trials/trait') Args(1) {
    my ($self, $c, $trait_id) = @_;
    
    my $trait_name = $c->model('solGS::solGS')->trait_name($trait_id);
    
    $c->stash->{template}   = $self->template('/search/trials/trait.mas');
    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;
}


sub show_search_result_pops : Path('/solgs/search/result/populations') Args(1) {
    my ($self, $c, $trait_id) = @_;
    
    my $combine = $c->req->param('combine');
    my $page = $c->req->param('page') || 1;

    my $projects_rs = $c->model('solGS::solGS')->search_populations($trait_id, $page);
    my $trait       = $c->model('solGS::solGS')->trait_name($trait_id);
   
    $self->get_projects_details($c, $projects_rs);
    my $projects = $c->stash->{projects_details};
      
    my @projects_list;
    my $marker_count;
       
    foreach my $pr_id (keys %$projects) 
    { 

	my $genotype_prop = $c->model("solGS::solGS")->get_project_genotypeprop($pr_id);
	$marker_count = $genotype_prop->{'marker_count'};
	
	if (!$marker_count) 
	{
	    my $markers = $c->model("solGS::solGS")->get_genotyping_markers($pr_id); 
	    my @markers = split(/\t/, $markers);
	    $marker_count = scalar(@markers);

	    my $genoprop = {'project_id' => $pr_id, 'marker_count' => $marker_count};
	    $c->model("solGS::solGS")->set_project_genotypeprop($genoprop);	     
	}         
	else
	{
	    my $is_gs = $c->model("solGS::solGS")->get_project_type($pr_id);

	    unless ($is_gs) 
	    {
		my $pr_prop = {'project_id' => $pr_id, 'project_type' => 'genomic selection'};
		$c->model("solGS::solGS")->set_project_type($pr_prop); 
	    }
		
	    $self->trial_compatibility_table($c, $marker_count);
	    my $match_code = $c->stash->{trial_compatibility_code};

	    my $pr_name     = $projects->{$pr_id}{project_name};
	    my $pr_desc     = $projects->{$pr_id}{project_desc};
	    my $pr_year     = $projects->{$pr_id}{project_year};
	    my $pr_location = $projects->{$pr_id}{project_location};

	    my $checkbox = qq |<form> <input  type="checkbox" name="project" value="$pr_id" onclick="getPopIds()"/> </form> |;
	    $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;

	    push @projects_list, [ $checkbox, qq|<a href="/solgs/trait/$trait_id/population/$pr_id" onclick="solGS.waitPage()">$pr_name</a>|, $pr_desc, $pr_location, $pr_year, $match_code
                ];
	}
   }     
    
    my $page_links =  sub {uri ( query => {  page => shift } ) };
    
    my $pager = $projects_rs->pager; 
    $pager->change_entries_per_page(15);

    my $pagination;
    my $url = "/solgs/search/result/populations/$trait_id";
   
    if ( $pager->previous_page || $pager->next_page )
    {
	$pagination =   '<div class = "paginate_nav">';
        
	if( $pager->previous_page ) 
	{
	    $pagination .=  '<a class="paginate_nav" href="' . $url .  $page_links->($pager->previous_page) . '">&lt;</a>';
	}
        
	for my $c_page ( $pager->first_page .. $pager->last_page ) 
	{
	    if( $pager->current_page == $c_page ) 
	    {
		$pagination .=  '<span class="paginate_nav_currpage paginate_nav">' .  $c_page . '</span>';
	    }
	    else 
		{
		    $pagination .=  '<a class="paginate_nav" href="' . $url.   $page_links->($c_page) . '">' . $c_page . '</a>';
		}
	}
	if( $pager->next_page ) 
	{
	    $pagination .= '<a class="paginate_nav" href="' . $url . $page_links->($pager->next_page). '">&gt;</a>';
	}
        
	$pagination .= '</div>';
    }

    my $ret->{status} = 'failed';
    
    if (@projects_list) 
    {            
	$ret->{status} = 'success';
	$ret->{pagination} = $pagination;
	$ret->{trials}   = \@projects_list;
    } 
    else 
    { 
	if ($pager->current_page == $pager->last_page) 
	{
	    $c->res->redirect("/solgs/search/result/populations/$trait_id/?page=1&trait=$trait");  
	}
	else 
	{
	    my $go_next = $pager->current_page + 1;
	    $c->res->redirect("/solgs/search/result/populations/$trait_id/?page=$go_next&trait=$trait");
	}
    } 
    
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
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
    my ($self,$c, $pr_rs) = @_;
 
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
 
        $projects_details{$pr_id}  = { 
                  project_name     => $pr_name, 
                  project_desc     => $pr_desc, 
                  project_year     => $year, 
                  project_location => $location,
        };
    }
        
    $c->stash->{projects_details} = \%projects_details;

}


sub show_search_result_traits : Path('/solgs/search/result/traits') Args(1) {
    my ($self, $c, $query) = @_;
      
    my $page = $c->req->param('page') || 1;
    my $result = $c->model('solGS::solGS')->search_trait($query, $page);
    
    my @rows;
    while (my $row = $result->next)
    {
        my $id   = $row->cvterm_id;
        my $name = $row->name;
        my $def  = $row->definition;
       
        my $checkbox;
        push @rows, [ qq |<a href="/solgs/search/trials/trait/$id"  onclick="solGS.waitPage()">$name</a>|, $def];      
    }

    if (@rows)
    {
       $c->stash(template   => $self->template('/search/result/traits.mas'),
                 result     => \@rows,
                 query      => $query,
                 pager      => $result->pager,
                 page_links => sub {uri ( query => { trait => $query, page => shift } ) }
           );
    }
    else
    {
        $self->gs_traits_index($c);
        my $gs_traits_index = $c->stash->{gs_traits_index};
        
        my $page = $c->req->param('page') || 1;
        my $project_rs = $c->model('solGS::solGS')->all_projects($page);
        $self->projects_links($c, $project_rs);
        my $projects = $c->stash->{projects_pages};
       
        $self->load_yaml_file($c, 'search/solgs.yml');
        my $form = $c->stash->{form};

        $c->stash(template        => $self->template('/search/solgs.mas'),
                  form            => $form,
                  message         => $query,
                  gs_traits_index => $gs_traits_index,
                  result          => $projects,
                  pager           => $project_rs->pager,
                  page_links      => sub {uri ( query => {  page => shift } ) }
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

        $self->select_traits($c);

        my $acronym = $self->get_acronym_pairs($c);
        $c->stash->{acronym} = $acronym;
    }
 
    my $pheno_data_file = $c->stash->{phenotype_file};
    
        if($uploaded_reference) 
        {
            my $ret->{status} = 'failed';
            if( !-s $pheno_data_file )
            {
                $ret->{status} = 'failed';
            
                $ret = to_json($ret);
                
                $c->res->content_type('application/json');
                $c->res->body($ret); 
            }
        }
} 


sub uploaded_population_summary {
    my ($self, $c) = @_;
    
    my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};
    my $user_name = $c->user->id;
    
    my $model_id = $c->stash->{model_id};
    my $selection_pop_id = $c->stash->{prediction_pop_id};
 
    if ($model_id) 
    {
        my $metadata_file_tr = catfile($tmp_dir, "metadata_${user_name}_${model_id}");
       
        my @metadata_tr = read_file($metadata_file_tr) if $model_id;
       
        my ($key, $list_name, $desc);
     
        ($desc)        = grep {/description/} @metadata_tr;       
        ($key, $desc)  = split(/\t/, $desc);
      
        ($list_name)       = grep {/list_name/} @metadata_tr;      
        ($key, $list_name) = split(/\t/, $list_name); 
   
        $c->stash(project_id          => $model_id,
                  project_name        => $list_name,
                  project_desc        => $desc,
                  owner               => $user_name,
            );  
    }

    if ($selection_pop_id =~ /uploaded/) 
    {
        my $metadata_file_sl = catfile($tmp_dir, "metadata_${user_name}_${selection_pop_id}");    
        my @metadata_sl = read_file($metadata_file_sl) if $selection_pop_id;
      
        my ($list_name_sl)       = grep {/list_name/} @metadata_sl;      
        my  ($key_sl, $list_name) = split(/\t/, $list_name_sl); 
   
        $c->stash->{prediction_pop_name} = $list_name;
    }
}


sub project_description {
    my ($self, $c, $pr_id) = @_;

    $c->stash->{uploaded_reference} = 1 if ($pr_id =~ /uploaded/);

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
        $self->uploaded_population_summary($c);
    }
    
    $self->genotype_file($c);
    my $geno_file  = $c->stash->{genotype_file};
    my @geno_lines = read_file($geno_file);
    my $markers_no = scalar(split ('\t', $geno_lines[0])) - 1;

    $self->trait_phenodata_file($c);
    my $trait_pheno_file  = $c->stash->{trait_phenodata_file};
    my @trait_pheno_lines = read_file($trait_pheno_file) if $trait_pheno_file;
 
    my $stocks_no = @trait_pheno_lines ? scalar(@trait_pheno_lines) - 1 : scalar(@geno_lines) - 1;
    
    $self->phenotype_file($c);
    my $pheno_file = $c->stash->{phenotype_file};
    my @phe_lines  = read_file($pheno_file);   
    my $traits     = $phe_lines[0];

    $self->filter_phenotype_header($c);
    my $filter_header = $c->stash->{filter_phenotype_header};
   
    $traits       =~ s/$filter_header//g;

    my @traits    =  split (/\t/, $traits);    
    my $traits_no = scalar(@traits);

    $c->stash(markers_no => $markers_no,
              traits_no  => $traits_no,
              stocks_no  => $stocks_no,
        );
}


sub select_traits   {
    my ($self, $c) = @_;

    $self->load_yaml_file($c, 'population/traits.yml');
    $c->stash->{traits_form} = $c->stash->{form};
}


sub selection_trait :Path('/solgs/selection/') Args(5) {
    my ($self, $c, $selection_pop_id, 
        $model_key, $model_id, 
        $trait_key, $trait_id) = @_;

    $c->stash->{pop_id}   = $model_id;
    $c->stash->{trait_id} = $trait_id;
    $c->stash->{prediction_pop_id} = $selection_pop_id;
    $c->stash->{template} = $self->template('/population/selection_trait.mas');
 
    $self->get_trait_name($c, $trait_id);
    
    my $page = $c->req->referer();

    if ($page =~ /solgs\/model\/combined\/populations/ || $page =~ /solgs\/models\/combined\/trials/  || $model_id =~ /combined/)
    {
        $model_id =~ s/combined_//g;
       
        $c->stash->{pop_id} = $model_id;
        $self->combined_pops_catalogue_file($c);
        my $combo_pops_catalogue_file = $c->stash->{combined_pops_catalogue_file};
    
        my @combos = read_file($combo_pops_catalogue_file);
    
        foreach (@combos)
        {
            if ($_ =~ m/$model_id/)
            {
                my ($combo_pops_id, $pops)  = split(/\t/, $_);
                $c->stash->{trait_combo_pops} = $pops;  
            }   
        } 

        $c->stash->{combo_pops_id} = $model_id;
        $self->combined_pops_summary($c);
        $c->stash->{combined_populations} = 1;
   
    } 
    elsif ($model_id =~ /uploaded/)
    {  
        $c->stash->{prediction_pop_id} = $selection_pop_id; 
        $c->stash->{prediction_pop_name} = $c->stash->{project_name};

        $c->stash->{model_id} = $model_id; 
        $self->uploaded_population_summary($c);

        $self->genotype_file($c);
        my $geno_file  = $c->stash->{genotype_file};
        my @geno_lines = read_file($geno_file);
        my $markers_no = scalar(split ('\t', $geno_lines[0])) - 1;

        $self->trait_phenodata_file($c);
        my $trait_pheno_file  = $c->stash->{trait_phenodata_file};
        my @trait_pheno_lines = read_file($trait_pheno_file) if $trait_pheno_file;

        my $stocks_no = @trait_pheno_lines ? scalar(@trait_pheno_lines) - 1 : scalar(@geno_lines) - 1;
   
        $self->phenotype_file($c);
        my $pheno_file = $c->stash->{phenotype_file};
        my @phe_lines  = read_file($pheno_file);   
        my $traits     = $phe_lines[0];

        $self->filter_phenotype_header($c);
        my $filter_header = $c->stash->{filter_phenotype_header};
   
        $traits       =~ s/$filter_header//g;

        my @traits    =  split (/\t/, $traits);    
        my $traits_no = scalar(@traits);

        $c->stash(markers_no => $markers_no,
                  traits_no  => $traits_no,
                  stocks_no  => $stocks_no,
            );

    } 
    else
    {
        $self->project_description($c, $model_id);      
        $self->get_project_owners($c, $model_id);       
        $c->stash->{owner} = $c->stash->{project_owners};        
    }
     
    if ($selection_pop_id =~ /uploaded/) 
    {
        $c->stash->{prediction_pop_id} = $selection_pop_id;
        $self->uploaded_population_summary($c);
    }
    else
    {
        my $pop_rs = $c->model("solGS::solGS")->project_details($selection_pop_id);    
        while (my $pop_row = $pop_rs->next) 
        {      
            $c->stash->{prediction_pop_name} = $pop_row->name;    
        }
    }
   
    my $identifier    = $model_id . '_' . $selection_pop_id;
 
    $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    my $gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    
    $self->top_blups($c, $gebvs_file);
 
    $c->stash->{blups_download_url} = qq | <a href="/solgs/download/prediction/model/$model_id/prediction/$selection_pop_id/$trait_id">Download all GEBVs</a>|; 

} 


sub trait :Path('/solgs/trait') Args(3) {
    my ($self, $c, $trait_id, $key, $pop_id) = @_;
   
    my $ajaxredirect = $c->req->param('source');
    $c->stash->{ajax_request} = $ajaxredirect;
   
    if ($pop_id && $trait_id)
    {    
        $c->stash->{pop_id} = $pop_id;       
       
        $self->get_trait_name($c, $trait_id);
        my $trait_name = $c->stash->{trait_name};

        $self->get_rrblup_output($c);

        $self->gs_files($c);

        unless ($ajaxredirect eq 'heritability') 
        {
            $self->project_description($c, $pop_id); 
            $self->trait_phenotype_stat($c);      
            $self->download_prediction_urls($c);     
            my $download_prediction = $c->stash->{download_prediction};
          
            $self->list_of_prediction_pops($c, $pop_id, $download_prediction);
             
            $self->get_project_owners($c, $pop_id);       
            $c->stash->{owner} = $c->stash->{project_owners};
           
            my $script_error = $c->stash->{script_error};
            if ($script_error) 
            {
                $c->stash->{message} = "$script_error can't create a prediction model for <b>$trait_name</b>. 
                                        There is a problem with the trait dataset.";

                $c->stash->{template} = "/generic_message.mas";   

            } 
            else 
            {
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
   
    my $pred_pop_id = $c->stash->{prediction_pop_id};
    my $prediction_population_file;

    if ($pred_pop_id) 
    {
        $self->prediction_population_file($c, $pred_pop_id);
        $prediction_population_file = $c->stash->{prediction_population_file};
    }

    my $pheno_file  = $c->stash->{phenotype_file};
    my $geno_file   = $c->stash->{genotype_file};
    my $traits_file = $c->stash->{selected_traits_file};
    my $trait_file  = $c->stash->{trait_file};
    my $pop_id      = $c->stash->{pop_id};
   
    no warnings 'uninitialized';

    my $input_files = join ("\t",
                            $pheno_file,
                            $geno_file,
                            $traits_file,
                            $trait_file,
                            $prediction_population_file
        );

    my $name = "input_files_${pop_id}"; 
    my $tempfile = $self->create_tempfile($c, $name); 
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
    $self->formatted_phenodata_file($c);
    $self->variance_components_file($c);

    my $prediction_id = $c->stash->{prediction_pop_id};
    if (!$pop_id) {$pop_id = $c->stash->{model_id};}

    no warnings 'uninitialized';
   
    $prediction_id = "uploaded_${prediction_id}" if $c->stash->{uploaded_prediction};

    my $identifier    = $pop_id . '_' . $prediction_id;
    
    my $pred_pop_gebvs_file;
    
    if ($prediction_id) 
    {
       
        $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        $pred_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    }

    my $file_list = join ("\t",
                          $c->stash->{gebv_kinship_file},
                          $c->stash->{gebv_marker_file},
                          $c->stash->{validation_file},
                          $c->stash->{trait_phenodata_file},
                          $c->stash->{formatted_phenodata_file},
                          $c->stash->{selected_traits_gebv_file},
                          $c->stash->{variance_components_file},
                          $pred_pop_gebvs_file
        );
                          
    my $name = "output_files_${trait}_$pop_id"; 
    my $tempfile = $self->create_tempfile($c, $name); 
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
   
    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
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


sub formatted_phenodata_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    $pop_id = $c->{stash}->{combo_pops_id} if !$pop_id;

    my $cache_data = { key       => 'formatted_phenotype_data_' . $pop_id, 
                       file      => 'formatted_phenotype_data_' . $pop_id,
                       stash_key => 'formatted_phenodata_file'
    };
    
    $self->cache_file($c, $cache_data);
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


sub blups_file {
    my ($self, $c) = @_;
    
    my $blups_file = $c->stash->{gebv_kinship_file};
    $self->top_blups($c, $blups_file);
}


sub download_blups :Path('/solgs/download/blups/pop') Args(3) {
    my ($self, $c, $pop_id, $trait, $trait_id) = @_;   
 
    $self->get_trait_name($c, $trait_id);
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
 
    $self->get_trait_name($c, $trait_id);
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
 
    $self->get_trait_name($c, $trait_id);
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

 
sub prediction_population :Path('/solgs/model') Args(3) {
    my ($self, $c, $model_id, $pop, $prediction_pop_id) = @_;

    my $referer = $c->req->referer;
    my $base    = $c->req->base;
    $referer    =~ s/$base//;
    my $path    = $c->req->path;
    $path       =~ s/$base//;
    my $page    = 'solgs/model/combined/populations/';
  
    if ($referer =~ /$page/)
    {   
        $model_id =~ s/combined_//;
        my ($combo_pops_id, $trait_id) = $referer =~ m/(\d+)/g;

        $c->stash->{data_set_type} = "combined populations"; 
        $c->stash->{combo_pops_id} = $model_id;
        $c->stash->{model_id}      = $model_id;                          
        $c->stash->{prediction_pop_id} = $prediction_pop_id;  
        
        $self->get_trait_name($c, $trait_id);
        my $trait_abbr = $c->stash->{trait_abbr};

        my $identifier = $combo_pops_id . '_' . $prediction_pop_id;
        $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        
        my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
      
        if (! -s $prediction_pop_gebvs_file)
        {
            my $dir = $c->stash->{solgs_cache_dir};
        
            my $exp = "phenotype_data_${model_id}_${trait_abbr}_combined"; 
            my $pheno_file = $self->grep_file($dir, $exp);

            $exp = "genotype_data_${model_id}_${trait_abbr}_combined"; 
            my $geno_file = $self->grep_file($dir, $exp);

            $c->stash->{trait_combined_pheno_file} = $pheno_file;
            $c->stash->{trait_combined_geno_file}  = $geno_file;
            $self->prediction_population_file($c, $prediction_pop_id);
  
            $c->forward('get_rrblup_output'); 
        }
        
        $self->combined_pops_summary($c);        
        $self->trait_phenotype_stat($c);
        $self->gs_files($c);
        
        $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);

        $self->download_prediction_urls($c, $combo_pops_id, $prediction_pop_id );
        my $download_prediction = $c->stash->{download_prediction};
      
        $self->list_of_prediction_pops($c, $combo_pops_id, $download_prediction);
      
        $c->res->redirect("/solgs/model/combined/populations/$model_id/trait/$trait_id"); 
        $c->detach();
    }
    elsif ($referer =~ /solgs\/trait\//) 
    {
        
        my ($trait_id, $pop_id) = $referer =~ m/(\d+)/g;
        if ($model_id =~ /uploaded/) {$pop_id = $model_id;}
       
        $c->stash->{data_set_type}     = "single population"; 
        $c->stash->{pop_id}            = $pop_id;
        $c->stash->{model_id}          = $model_id;                          
        $c->stash->{prediction_pop_id} = $prediction_pop_id;  
        
        $self->get_trait_name($c, $trait_id);
        my $trait_abbr = $c->stash->{trait_abbr};

        my $identifier = $pop_id . '_' . $prediction_pop_id;
        $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        
        my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
      
        if (! -s $prediction_pop_gebvs_file)
        {
            my $dir = $c->stash->{solgs_cache_dir};
        
            my $exp = "phenotype_data_${pop_id}"; 
            my $pheno_file = $self->grep_file($dir, $exp);

            $exp = "genotype_data_${pop_id}"; 
            my $geno_file = $self->grep_file($dir, $exp);

            $c->stash->{pheno_file} = $pheno_file;
            $c->stash->{geno_file}  = $geno_file;
            $self->prediction_population_file($c, $prediction_pop_id);
  
            $c->forward('get_rrblup_output'); 
        }
         $self->trait_phenotype_stat($c);
         $self->gs_files($c);
        
         $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);

         $self->download_prediction_urls($c, $pop_id, $prediction_pop_id );
         my $download_prediction = $c->stash->{download_prediction};
      
         $self->list_of_prediction_pops($c, $pop_id, $download_prediction);
 
         $c->res->redirect("/solgs/trait/$trait_id/population/$pop_id");
         $c->detach();
           
    }
    elsif ($referer =~ /solgs\/models\/combined\/trials/) 
    { 
        my ($model_id, $prediction_pop_id) = $path =~ m/(\d+)/g;

        $c->stash->{data_set_type}     = "combined populations"; 
        # $c->stash->{pop_id}            = $model_id;
        $c->stash->{model_id}          = $model_id;  
        $c->stash->{combo_pops_id}        = $model_id;
        $c->stash->{prediction_pop_id} = $prediction_pop_id;  
        
        $self->analyzed_traits($c);
        my @traits_ids = @{ $c->stash->{analyzed_traits_ids} };

        foreach my $trait_id (@traits_ids) 
        {            
            $self->get_trait_name($c, $trait_id);
            my $trait_abbr = $c->stash->{trait_abbr};

            my $identifier = $model_id . '_' . $prediction_pop_id;
            $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        
            my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
             
            if (! -s $prediction_pop_gebvs_file)
            {
                my $dir = $c->stash->{solgs_cache_dir};
                
                $self->cache_combined_pops_data($c);
 
                my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
                my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
             
                $c->stash->{pheno_file} = $combined_pops_pheno_file;
                $c->stash->{geno_file}  = $combined_pops_geno_file;

                $c->stash->{prediction_pop_id} = $prediction_pop_id;
                $self->prediction_population_file($c, $prediction_pop_id);
                
                $c->forward('get_rrblup_output'); 
               
             }
         }
            
        $c->res->redirect("/solgs/models/combined/trials/$model_id");
        $c->detach();
    }
    else 
    {
        $c->res->redirect("/solgs/analyze/traits/population/$model_id/$prediction_pop_id");
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
 
    $self->get_trait_name($c, $trait_id);
    $c->stash->{pop_id} = $pop_id;

    my $path = $c->req->path; my $referer= $c->req->referer;
   
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
  
    $prediction_pop_id = "uploaded_${prediction_pop_id}" if $prediction_is_uploaded;
 
    my  @files  =  grep { /prediction_pop_gebvs_${training_pop_id}_${prediction_pop_id}/ && -s "$dir/$_" } 
                 readdir($dh); 
   
    closedir $dh; 

    my @copy_files = @files;
   
    my @trait_ids = map { s/prediction_pop_gebvs_${training_pop_id}_${prediction_pop_id}_//g ? $_ : 0} @copy_files;

    my @traits = ();

    if(@trait_ids) 
    {
        foreach (@trait_ids)
        { 
            $self->get_trait_name($c, $_);
            push @traits, $c->stash->{trait_abbr};
        }
    }
   
    $c->stash->{prediction_pop_analyzed_traits} = \@traits;
    $c->stash->{prediction_pop_analyzed_traits_ids} = \@trait_ids;
    $c->stash->{prediction_pop_analyzed_traits_files} = \@files;
    
}


sub download_prediction_urls {
    my ($self, $c, $training_pop_id, $prediction_pop_id) = @_;
  
    my $trait_ids;
    my $page_trait_id = $c->stash->{trait_id};
    $page_trait_id = $c->stash->{page_trait_id} if $c->stash->{page_trait_id}; 
    my $page = $c->req->path;
   
    no warnings 'uninitialized';

    if ($prediction_pop_id)
    {
        $self->prediction_pop_analyzed_traits($c, $training_pop_id, $prediction_pop_id);
        $trait_ids = $c->stash->{prediction_pop_analyzed_traits_ids};   
    } 
     
   my ($trait_is_predicted) = grep {/$page_trait_id/ } @$trait_ids;

    my $download_url;# = $c->stash->{download_prediction};
  
    if ($page =~ /(solgs\/trait\/)|(solgs\/model\/combined\/populations\/)/ )
    { 
        $trait_ids = [$page_trait_id];
    }

    if ($page =~ /(\/uploaded\/prediction\/)/ && $c->req->referer !~ /(\/solgs\/traits\/all)/ )
    { 
        $trait_ids = [$page_trait_id];
    }

    foreach my $trait_id (@$trait_ids) 
    {
        $self->get_trait_name($c, $trait_id);
        my $trait_abbr = $c->stash->{trait_abbr};
        my $trait_name = $c->stash->{trait_name};
     
        if  ($c->stash->{uploaded_prediction}) 
        {  
            unless ($prediction_pop_id =~ /uploaded/) 
            {
                $prediction_pop_id = 'uploaded_' . $prediction_pop_id;
            }
        }

        $download_url   .= " | " if $download_url;        
        $download_url   .= qq | <a href="/solgs/selection/$prediction_pop_id/model/$training_pop_id/trait/$trait_id">$trait_abbr</a> | if $trait_id;
        
        $download_url = '' if (!$trait_is_predicted);
    }

    if ($download_url) 
    {    
        $c->stash->{download_prediction} = $download_url;
         
    }
    else
    {
        
        $c->stash->{download_prediction} = qq | <a href ="/solgs/model/$training_pop_id/prediction/$prediction_pop_id"  onclick="solGS.waitPage()">[ Predict ]</a> |;

         $c->stash->{download_prediction} = '' if $c->stash->{uploaded_prediction};
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


sub get_trait_name {
    my ($self, $c, $trait_id) = @_;

    my $trait_name = $c->model('solGS::solGS')->trait_name($trait_id);
  
    my $abbr = $self->abbreviate_term($c, $trait_name);
   
    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;
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

    if ($pred_pop_id) 
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
            $gebv_files .= "\t" unless (@analyzed_traits_files[-1] eq $tr_file);
        }
        
        my @analyzed_valid_traits_files = @{$c->stash->{analyzed_valid_traits_files}};

        foreach my $tr_file (@analyzed_valid_traits_files) 
        {
            $valid_gebv_files .= $tr_file;
            $valid_gebv_files .= "\t" unless (@analyzed_valid_traits_files[-1] eq $tr_file);
        }


    }
   
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id; 
    
    my $name = "gebv_files_of_traits_${pop_id}${pred_file_suffix}";
    my $file = $self->create_tempfile($c, $name);
   
    write_file($file, $gebv_files);
   
    $c->stash->{gebv_files_of_traits} = $file;

    my $name2 = "gebv_files_of_valid_traits_${pop_id}${pred_file_suffix}";
    my $file2 = $self->create_tempfile($c, $name2);
   
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
            $rel_wts .= "\n";#unless( (keys %$params)[-1] eq $tr);
        }
    }
  
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id; 
    
    my $name = "rel_weights_${pop_id}${pred_file_suffix}";
    my $file = $self->create_tempfile($c, $name);
    write_file($file, $rel_wts);
    
    $c->stash->{rel_weights_file} = $file;
    
}


sub ranked_genotypes_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id = $c->stash->{pop_id};
 
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;
  
    my $name = "ranked_genotypes_${pop_id}${pred_file_suffix}";
    my $file = $self->create_tempfile($c, $name);
    $c->stash->{ranked_genotypes_file} = $file;
   
}


sub selection_index_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id      = $c->stash->{pop_id};
   
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;

    my $name = "selection_index_${pop_id}${pred_file_suffix}";
    my $file = $self->create_tempfile($c, $name);
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
    my $output_file = $self->create_tempfile($c, $name);
    write_file($output_file, $output_files);
    
    
    $name = "input_rank_genotypes_${pop_id}${pred_file_suffix}";
    my $input_file = $self->create_tempfile($c, $name);
    write_file($input_file, $input_files);
    
    $c->stash->{output_files} = $output_file;
    $c->stash->{input_files}  = $input_file;   
    $c->stash->{r_temp_file}  = "rank-gebv-genotypes-${pop_id}${pred_file_suffix}";  
    $c->stash->{r_script}     = 'R/selection_index.r';
    
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
   
    shift(@data);
    
    return \@data;

}


sub trait_phenotype_file {
    my ($self, $c, $pop_id, $trait) = @_;

    my $dir = $c->stash->{solgs_cache_dir};
    my $exp = "phenotype_trait_${trait}_${pop_id}";
    my $file = $self->grep_file($dir, $exp);
   
    $c->stash->{trait_phenotype_file} = $file;

}

#retrieve from db prediction pops relevant to the
#training population
sub list_of_prediction_pops {
    my ($self, $c, $training_pop_id, $download_prediction) = @_;

    $self->list_of_prediction_pops_file($c, $training_pop_id);
    my $pred_pops_file = $c->stash->{list_of_prediction_pops_file};

    my @pred_pops_ids = split(/\n/, read_file($pred_pops_file));
    my $pop_ids;

    if(!@pred_pops_ids)
    {      
        @pred_pops_ids = @{$c->model('solGS::solGS')->prediction_pops($training_pop_id)};
    }
 
    my @pred_pops;

    if (@pred_pops_ids) {

        foreach my $prediction_pop_id (@pred_pops_ids)
        {
          $pop_ids .= $prediction_pop_id ."\n";        
          write_file($pred_pops_file, $pop_ids);

          my $pred_pop_rs = $c->model('solGS::solGS')->project_details($prediction_pop_id);
          my $pred_pop_link;

          while (my $row = $pred_pop_rs->next)
          {
              my $name = $row->name;
              my $desc = $row->description;
            
              unless ($name =~ /test/ || $desc =~ /test/)   
              {
                  my $id_pop_name->{id}    = $prediction_pop_id;
                  $id_pop_name->{name}     = $name;
                  $id_pop_name->{pop_type} = 'selection';
                  $id_pop_name             = to_json($id_pop_name);

                  $pred_pop_link = qq | <a href="/solgs/model/$training_pop_id/prediction/$prediction_pop_id" 
                                      onclick="solGS.waitPage()"><input type="hidden" value=\'$id_pop_name\'>$name</data> 
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
                
                  push @pred_pops,  ['', $pred_pop_link, $desc, 'NA', $project_yr, $download_prediction];
              }
          }
        }
    }
    
    $c->stash->{list_of_prediction_pops} = \@pred_pops;

}


sub list_of_prediction_pops_file {
    my ($self, $c, $training_pop_id)= @_;

    my $cache_data = {key       => 'list_of_prediction_pops' . $training_pop_id,
                      file      => 'list_of_prediction_pops_' . $training_pop_id,
                      stash_key => 'list_of_prediction_pops_file'
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
    $self->genotype_file($c, $pred_pop_id);
    my $pred_pop_file = $c->stash->{pred_genotype_file};

    $fh->print($pred_pop_file);
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
    
    my $file = $self->combined_pops_catalogue_file($c);
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
    
    my @combos = read_file($combo_pops_catalogue_file);
    
    foreach (@combos)
    {
        if ($_ =~ m/$combined_pops_id/)
        {
            my ($combo_pops_id, $pops)  = split(/\t/, $_);
            $c->stash->{combined_pops_list} = $pops; 
            $c->stash->{trait_combo_pops} = $pops;
        }   
    }     

}


sub traits_to_analyze :Regex('^solgs/analyze/traits/population/([\w|\d]+)(?:/([\d+]+))?') {
    my ($self, $c) = @_; 
   
    my ($pop_id, $prediction_id) = @{$c->req->captures};
   
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{prediction_pop_id} = $prediction_id;
  
    my @selected_traits = $c->req->param('trait_id');

    my $single_trait_id;
    if (!@selected_traits)
    {
        $c->stash->{model_id} = $pop_id; 
        
        $self->traits_with_valid_models($c);
        @selected_traits = @ {$c->stash->{traits_with_valid_models}};
    }

    if (!@selected_traits)
    {
        $c->res->redirect("/solgs/population/$pop_id/selecttraits");
        $c->detach(); 
    }
    elsif (scalar(@selected_traits) == 1)
    {
        $single_trait_id = $selected_traits[0];
        
        if (!$prediction_id)
        { 
              $c->res->redirect("/solgs/trait/$single_trait_id/population/$pop_id");
              $c->detach();              
        } 
        else
        {
            my $name  = "trait_info_${single_trait_id}_pop_${pop_id}";
            my $file2 = $self->create_tempfile($c, $name);
       
            $c->stash->{trait_file} = $file2;
            $c->stash->{trait_abbr} = $selected_traits[0];
           
            my $acronym_pairs = $self->get_acronym_pairs($c);                   
            if ($acronym_pairs)
            {
                foreach my $r (@$acronym_pairs) 
                {
                    if ($r->[0] eq $selected_traits[0]) 
                    {
                        my $trait_name =  $r->[1];
                        $trait_name    =~ s/\n//g;                                
                        my $trait_id   =  $c->model('solGS::solGS')->get_trait_id($trait_name);
                        $self->get_trait_name($c, $trait_id);
                    }
                }
            }
              
            $c->forward('get_rrblup_output');     
        }
    }
    elsif (scalar(@selected_traits) > 1) 
    {
        my ($traits, $trait_ids);    
        
        for (my $i = 0; $i <= $#selected_traits; $i++)
        {           
            if ($selected_traits[$i] =~ /\D/)
            {               
                my $acronym_pairs = $self->get_acronym_pairs($c);                   
                if ($acronym_pairs)
                {
                    foreach my $r (@$acronym_pairs) 
                    {
                        if ($r->[0] eq $selected_traits[$i]) 
                        {
                            my $trait_name =  $r->[1];
                            $trait_name    =~ s/\n//g;                                
                            my $trait_id   =  $c->model('solGS::solGS')->get_trait_id($trait_name);

                            $traits    .= $r->[0];
                            $traits    .= "\t" unless ($i == $#selected_traits);
                            $trait_ids .= $trait_id;                                                        
                        }
                    }
                }
            }
            else 
            {
                my $tr = $c->model('solGS::solGS')->trait_name($selected_traits[$i]);
   
                my $abbr = $self->abbreviate_term($c, $tr);
                $traits .= $abbr;
                $traits .= "\t" unless ($i == $#selected_traits); 

                    
                foreach (@selected_traits)
                {
                    $trait_ids .= $_; #$c->model('solGS')->get_trait_id($c, $_);
                }
            }                 
        } 

        my $identifier = crc($trait_ids);

        $self->combined_gebvs_file($c, $identifier);
        
        my $name = "selected_traits_pop_${pop_id}";
        my $file = $self->create_tempfile($c, $name);
        write_file($file, $traits);
        $c->stash->{selected_traits_file} = $file;

        $name = "trait_info_${single_trait_id}_pop_${pop_id}";
        my $file2 = $self->create_tempfile($c, $name);
       
        $c->stash->{trait_file} = $file2;
        $c->forward('get_rrblup_output');
  
    }
 
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

     $c->stash->{pop_id} = $pop_id;

     if ($pop_id =~ /uploaded/)
     {
         $self->list_predicted_selection_pops($c, $pop_id);

         my $predicted_selection_pops = $c->stash->{list_of_predicted_selection_pops};
     
         if (!$pred_pop_id)  
         {
             $pred_pop_id = $predicted_selection_pops->[0];
         }
     }                                      
     
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

         push @trait_pages,  [ qq | <a href="/solgs/trait/$trait_id/population/$pop_id" onclick="solGS.waitPage()">$trait_abbr</a>|, $accuracy_value, $heritability];
       
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
     
     $self->download_prediction_urls($c, $pop_id, $pred_pop_id);
     my $download_prediction = $c->stash->{download_prediction};
  
     $self->list_of_prediction_pops($c, $pop_id, $download_prediction);
        
     $self->list_predicted_selection_pops($c, $pop_id);

     my $predicted_selection_pops = $c->stash->{list_of_predicted_selection_pops};
    
     if(@$predicted_selection_pops)
     {
         $self->prediction_pop_analyzed_traits($c, $pop_id, $predicted_selection_pops->[0]);
     }
 
}


sub selection_index_form :Path('/solgs/selection/index/form') Args(0) {
    my ($self, $c) = @_;
    
    my $pred_pop_id = $c->req->param('pred_pop_id');
    my $training_pop_id = $c->req->param('training_pop_id');
   
    $c->stash->{model_id} = $training_pop_id;
    $c->stash->{prediction_pop_id} = $pred_pop_id;
   
    my @traits;
    if ( !$pred_pop_id) 
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
   
    my $pop_id = $c->stash->{pop_id};
    
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

    $c->stash->{traits_with_valid_models} = \@filtered_analyzed_traits;

}


sub calculate_selection_index :Path('/solgs/calculate/selection/index') Args(2) {
    my ($self, $c, $model_id, $pred_pop_id) = @_;
    
    $c->stash->{pop_id} = $model_id;

    if( $pred_pop_id =~ /\d+/ && $model_id != $pred_pop_id)
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
    
        my $markers     = $c->model("solGS::solGS")->get_genotyping_markers($pop_id);                   
        my @markers     = split(/\t/, $markers);
        my $markers_num = scalar(@markers);
       
        $self->trial_compatibility_table($c, $markers_num);
        my $match_code = $c->stash->{trial_compatibility_code};

        my $pop_rs       = $c->model('solGS::solGS')->project_details($pop_id);
       
	my $pop_details  = $self->get_projects_details($c, $pop_rs);
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

        $self->get_trait_name($c, $trait_id);
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

                $self->list_of_prediction_pops($c, $combo_pops_id);

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
        #run gs model based on a single population
        my $pop_id = $pop_ids[0];
        $ret->{redirect_url} = "/solgs/trait/$trait_id/population/$pop_id";
    }
       
    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub display_combined_pops_result :Path('/solgs/model/combined/populations/') Args(3){
    my ($self, $c,  $combo_pops_id, $trait_key,  $trait_id,) = @_;
    
    $c->stash->{data_set_type} = 'combined populations';
    $c->stash->{combo_pops_id} = $combo_pops_id;
    
    my $pops_ids = $c->req->param('combined_populations');
   
    if ($pops_ids)
    {
        $c->stash->{trait_combo_pops} = $pops_ids;
    }
    else
    {
        $self->get_combined_pops_list($c, $combo_pops_id);
        $pops_ids = $c->stash->{combined_pops_list};
        $c->stash->{trait_combo_pops} = $pops_ids; 
    }

    $self->get_trait_name($c, $trait_id);

    $self->trait_phenotype_stat($c);
    
    $self->validation_file($c);
    $self->model_accuracy($c);
    $self->gebv_kinship_file($c);
    $self->blups_file($c);
    $self->download_urls($c);
    $self->gebv_marker_file($c);
    $self->top_markers($c);
    $self->combined_pops_summary($c);
    $self->model_parameters($c);

    $self->download_prediction_urls($c);
    my $download_prediction = $c->stash->{download_prediction};

    $self->list_of_prediction_pops($c, $combo_pops_id, $download_prediction);

    $c->stash->{template} = $self->template('/model/combined/populations/trait.mas');
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
  my ($text, $accuracy_value)    = split(/\t/,  $row);
 
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
    
    my $pops_list = $c->stash->{trait_combo_pops};

    my @pops = split(/,/, $pops_list);
    
    my $desc = 'This training population is a combination of ';
    
    my $projects_owners;
    foreach (@pops)
    {  
        my $pr_rs = $c->model('solGS::solGS')->project_details($_);

        while (my $row = $pr_rs->next)
        {
         
            my $pr_id   = $row->id;
            my $pr_name = $row->name;
            $desc .= qq | <a href="/solgs/population/$pr_id">$pr_name </a>|; 
            $desc .= $_ == $pops[-1] ? '.' : ' and ';
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
    my $combo_pops_id = $c->stash->{combo_pops_id};

    my $dir = $c->{stash}->{solgs_cache_dir};

    my $geno_exp  = "genotype_data_${combo_pops_id}_${trait_abbr}_combined";
    my $geno_file = $self->grep_file($dir, $geno_exp);  
   
    my @geno_lines = read_file($geno_file);
    my $markers_no = scalar(split ('\t', $geno_lines[0])) - 1;

    my $pheno_exp = "phenotype_trait_${trait_abbr}_${combo_pops_id}_combined";
    my $trait_pheno_file = $self->grep_file($dir, $pheno_exp);  
    
    my @trait_pheno_lines = read_file($trait_pheno_file);
    my $stocks_no =  scalar(@trait_pheno_lines) - 1;

    my $training_pop = "Training population $combo_pops_id";

    $c->stash(markers_no   => $markers_no,
              stocks_no    => $stocks_no,
              project_desc => $desc,
              project_name => $training_pop,
              owner        => $projects_owners
        );

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
        open my $first_file, "<", $pair->[0] or die "cannot open genotype file:$!\n";
        my $first_markers = <$first_file>;
        $first_file->close;

       
        open my $sec_file, "<", $pair->[1] or die "cannot open genotype file:$!\n";
        my $sec_markers = <$sec_file>;
        $sec_file->close;

        my @first_geno_markers = split(/\t/, $first_markers);
        my @sec_geno_markers = split(/\t/, $sec_markers);
  
        my $f_cnt = scalar(@first_geno_markers);
        my $sec_cnt = scalar(@sec_geno_markers);
        
        $cnt++;
        my $common_markers = scalar(intersect(@first_geno_markers, @sec_geno_markers));
        my $similarity = $common_markers / scalar(@first_geno_markers);
        unless ($similarity > 0.5 )      
        {
            no warnings 'uninitialized';
            my $pop_id_1 = fileparse($pair->[0]);
            my $pop_id_2 = fileparse($pair->[1]);
          
            map { s/genotype_data_|\.txt//g } $pop_id_1, $pop_id_2;
           
            my $list_pop = $c->stash->{uploaded_prediction};
          
            if (!$list_pop) 
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
            else 
            {           
                $not_matching_pops = 'not_matching';
            }
        }           
    }

    $c->stash->{pops_with_no_genotype_match} = $not_matching_pops;
      
}


sub cache_combined_pops_data {
    my ($self, $c) = @_;

    my $trait_id   = $c->stash->{trait_id};
    my $trait_abbr = $c->stash->{trait_abbr};

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
            my $exp = "phenotype_data_${pop_id}\.txt";
            $files .= $self->grep_file($dir, $exp);          
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id);    
        }
        $c->stash->{multi_pops_pheno_files} = $files;

    }
    else 
    {
        my $exp = "phenotype_data_${pop_ids}\.txt";
        $files = $self->grep_file($dir, $exp);
    }

    if ($trait_id)
    {
        my $name = "trait_${trait_id}_multi_pheno_files";
        my $tempfile = $self->create_tempfile($c, $name);
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
            my $exp = "genotype_data_${pop_id}\.txt";
            $files .= $self->grep_file($dir, $exp);        
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id);    
        }
        $c->stash->{multi_pops_geno_files} = $files;
    }
    else 
    {
        my $exp = "genotype_data_${pop_ids}\.txt";
        $files = $self->grep_file($dir, $exp);
    }

    if($trait_id)
    {
        my $name = "trait_${trait_id}_multi_geno_files";
        my $tempfile = $self->create_tempfile($c, $name);
        write_file($tempfile, $files);
    }
    
}


sub create_tempfile {
    my ($self, $c, $name) = @_;

    my ($fh, $file) = tempfile("$name-XXXXX", 
                               DIR => $c->stash->{solgs_tempfiles_dir}
        );
    
    $fh->close; 
    
    return $file;

}


sub grep_file {
    my ($self, $dir, $exp) = @_;

    opendir my $dh, $dir 
        or die "can't open $dir: $!\n";

    my ($file)  = grep { /$exp/ && -f "$dir/$_" }  readdir($dh);
    close $dh;
   
    if ($file)    
    {
        $file = catfile($dir, $file);
    }

    return $file;
}


sub multi_pops_phenotype_data {
    my ($self, $c, $pop_ids) = @_;
    
    if (@$pop_ids)
    {
        foreach (@$pop_ids)        
        {
            $c->stash->{pop_id} = $_;
            $self->phenotype_file($c);
        }
    }
   
    $self->multi_pops_pheno_files($c, $pop_ids);
    

}


sub multi_pops_genotype_data {
    my ($self, $c, $pop_ids) = @_;
    
    if (@$pop_ids)
    {
        foreach (@$pop_ids)        
        {
            $c->stash->{pop_id} = $_;
            $self->genotype_file($c);
        }
    }

  $self->multi_pops_geno_files($c, $pop_ids);

}


sub phenotype_graph :Path('/solgs/phenotype/graph') Args(0) {
    my ($self, $c) = @_;

    my $pop_id        = $c->req->param('pop_id');
    my $trait_id      = $c->req->param('trait_id');
    my $combo_pops_id = $c->req->param('combo_pops_id');

    $self->get_trait_name($c, $trait_id);

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
  
    my @pheno_data;   
    foreach (@$trait_data) 
    {
        unless (!$_->[0]) {
	 
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

    my @desc_stat =  ( [ 'Total no. of genotypes', $cnt ],
		       [ 'Genotypes missing data', $na ],
                       [ 'Minimum', $min ], 
                       [ 'Maximum', $max ],
                       [ 'Arithmetic mean', $mean ],
                       [ 'Standard deviation', $std ],
                       [ 'Coefficient of variation', $cv ]
        );
   
    $c->stash->{descriptive_stat} = \@desc_stat;
    
}

#sends an array of trait gebv data to an ajax request
#with a population id and trait id parameters
sub gebv_graph :Path('/solgs/trait/gebv/graph') Args(0) {
    my ($self, $c) = @_;

    my $pop_id   = $c->req->param('pop_id');
    my $trait_id = $c->req->param('trait_id');
    my $combo_pops_id = $c->req->param('combo_pops_id');
    my $trait_combo_pops = $c->req->param('combined_populations');

    my $prediction_pop_id = $c->req->param('selection_pop_id');

    $c->stash->{pop_id} = $pop_id;
    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{trait_combo_pops} = $trait_combo_pops;
    $c->stash->{prediction_pop_id} = $prediction_pop_id;
   
    $self->get_trait_name($c, $trait_id);
  
    $c->stash->{data_set_type} = 'combined populations' if $combo_pops_id;
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


sub get_all_traits {
    my ($self, $c) = @_;
    
    my $pheno_file = $c->stash->{phenotype_file};
    
    $self->filter_phenotype_header($c);
    my $filter_header = $c->stash->{filter_phenotype_header};
    
    open my $ph, "<", $pheno_file or die "$pheno_file:$!\n";
    my $headers = <$ph>;
    $headers =~ s/$filter_header//g;
    $ph->close;

    $self->create_trait_data($c, $headers);
       
}


sub create_trait_data {
    my ($self, $c, $list) = @_;   
       
    $list =~ s/\n//;
    my @traits = split (/\t/, $list);
  
    my $table = 'trait_id' . "\t" . 'trait_name' . "\t" . 'acronym' . "\n"; 
 
    my $acronym_pairs = $self->get_acronym_pairs($c);
    foreach (@$acronym_pairs)
    {
        my $trait_name = $_->[1];
        $trait_name =~ s/\n//g;
        
        my $trait_id = $c->model('solGS::solGS')->get_trait_id($trait_name);
        $table .= $trait_id . "\t" . $trait_name . "\t" . $_->[0] . "\n";
       
    }

    $self->all_traits_file($c);
    my $traits_file =  $c->stash->{all_traits_file};
  
    write_file($traits_file, $table);

}


sub all_traits_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    my $cache_data = {key       => 'all_traits_pop' . $pop_id,
                      file      => 'all_traits_pop_' . $pop_id,
                      stash_key => 'all_traits_file'
    };

    $self->cache_file($c, $cache_data);

}


sub get_acronym_pairs {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    
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

    my $cache_data = {key       => 'traits_acronym_pop' . $pop_id,
                      file      => 'traits_acronym_pop_' . $pop_id,
                      stash_key => 'traits_acronym_file'
    };

    $self->cache_file($c, $cache_data);

}


sub analyzed_traits {
    my ($self, $c) = @_;
    
    my $model_id = $c->stash->{model_id}; 

    my $dir = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir or die "can't open $dir: $!\n";
    

    my @all_files =   grep { /gebv_kinship_[a-zA-Z0-9]/ && -f "$dir/$_" } 
                  readdir($dh); 
    closedir $dh;
   
    my @traits_files = map { catfile($dir, $_)} 
                       grep {/($model_id)/} 
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
            $trait =~ s/$model_id|_|combined_pops//g;
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
            
            $self->get_model_accuracy_value($c, $model_id, $trait);
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
    
    my $meta_headers = "uniquename\t|object_id\t|object_name\t|stock_id\t|stock_name\t|design\t|block\t|replicate\t";
    $c->stash->{filter_phenotype_header} = $meta_headers;

}


sub abbreviate_term {
    my ($self, $c, $term) = @_;
  
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
	    if ($word=~/^\D/)
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

    my $rs = $c->model('solGS::solGS')->all_gs_traits();
 
    my @all_traits;
    while (my $row = $rs->next)
    {
        my $trait_id = $row->id;
        my $trait    = $row->name;
        push @all_traits, $trait;
    }

    $c->stash->{all_gs_traits} = \@all_traits;
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

    my @traits_urls;
    foreach my $tr (@$traits)
    {
        push @traits_urls, [ qq | <a href="/solgs/search/result/traits/$tr">$tr</a> | ];
    }
    $c->stash->{traits_urls} = \@traits_urls;
}


sub gs_traits : Path('/solgs/traits') Args(1) {
    my ($self, $c, $index) = @_;
    
    if ($index =~ /^\w{1}$/) 
    {
        $self->traits_starting_with($c, $index);
        my $traits_gr = $c->stash->{trait_subgroup};
        
        $self->hyperlink_traits($c, $traits_gr);
        my $traits_urls = $c->stash->{traits_urls};
        
        $c->stash( template    => $self->template('/search/traits/list.mas'),
                   index       => $index,
                   traits_list => $traits_urls
            );
    }
    else 
    {
        $c->forward('search');
    }
}


sub phenotype_file {
    my ($self, $c) = @_;
    my $pop_id     = $c->stash->{pop_id};
   
    die "Population id must be provided to get the phenotype data set." if !$pop_id;
    $pop_id =~ s/combined_//;
    
    my $pheno_file;
 
    if ($c->stash->{uploaded_reference} || $pop_id =~ /uploaded/) {
        my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};     
        my $user_id = $c->user->id;

        $pheno_file = catfile ($tmp_dir, "phenotype_data_${user_id}_${pop_id}");
 
    }

    unless ($pheno_file) 
    {

        my $file_cache  = Cache::File->new(cache_root => $c->stash->{solgs_cache_dir});
        $file_cache->purge();
   
        my $key        = "phenotype_data_" . $pop_id;
        $pheno_file = $file_cache->get($key);
       
        unless ( -s $pheno_file)
        {  
            $pheno_file = catfile($c->stash->{solgs_cache_dir}, "phenotype_data_" . $pop_id . ".txt");
            my $data = $c->model('solGS::solGS')->phenotype_data($pop_id);
           # my $data = $c->stash->{phenotype_data};
        
            $data = $self->format_phenotype_dataset($c, $data);
            write_file($pheno_file, $data);

            $file_cache->set($key, $pheno_file, '30 days');
        }
    }
   
    $c->stash->{phenotype_file} = $pheno_file;   

}


sub format_phenotype_dataset {
    my ($self, $c, $data) = @_;
    
    my @rows = split (/\n/, $data);
    
    $rows[0] =~ s/SP:\d+\|//g;  
    $rows[0] =~ s/\w+:\w+\|//g;
   

    my @headers = split(/\t/, $rows[0]);
    
    my $header;   
    my %acronym_table;

    $self->filter_phenotype_header($c);
    my $filter_header = $c->stash->{filter_phenotype_header};
    $filter_header =~ s/\t//g;

    my $cnt = 0;
    foreach my $trait_name (@headers)
    {
        $cnt++;
        
        my $abbr = $self->abbreviate_term($c, $trait_name);
        $header .= $abbr;
     
        unless ($cnt == scalar(@headers))
        {
            $header .= "\t";
        }
        
        $abbr =~ s/$filter_header//g;
        $acronym_table{$abbr} = $trait_name if $abbr;
    }
    
    $rows[0] = $header;
    
    foreach (@rows)
    {
        $_ =~ s/\s+plot//g;
        $_ .= "\n";
    }
    
    $self->traits_acronym_table($c, \%acronym_table);

    return \@rows;
}


sub genotype_file  {
    my ($self, $c, $pred_pop_id) = @_;
    my $pop_id  = $c->stash->{pop_id};
    
    my $geno_file;

    if ($pred_pop_id) 
    {      
        $pop_id = $c->stash->{prediction_pop_id};      
        $geno_file = $c->stash->{user_selection_list_genotype_data_file};
      
    } 
    
    die "Population id must be provided to get the genotype data set." if !$pop_id;
  
    if ($c->stash->{uploaded_reference}) {
        my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};     
        my $user_id = $c->user->id;

        $geno_file = catfile ($tmp_dir, "genotype_data_${user_id}_${pop_id}");
 
    }

    if ($pop_id =~ /uploaded/) 
    {
        my $dir = $c->stash->{solgs_prediction_upload_dir};
        my $user_id = $c->user->id;
      
        my $exp = "genotype_data_${user_id}_${pop_id}"; 
        $geno_file = $self->grep_file($dir, $exp);    
      
    }

    unless($geno_file) 
    {
        my $file_cache  = Cache::File->new(cache_root => $c->stash->{solgs_cache_dir});
        $file_cache->purge();
   
        my $key        = "genotype_data_" . $pop_id;
        $geno_file = $file_cache->get($key);

        unless (-s $geno_file)
        {  
            $geno_file = catfile($c->stash->{solgs_cache_dir}, "genotype_data_" . $pop_id . ".txt");
            my $data = $c->model('solGS::solGS')->genotype_data($pop_id);
           
            write_file($geno_file, $data);

            $file_cache->set($key, $geno_file, '30 days');
        }
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


sub get_rrblup_output :Private{
    my ($self, $c) = @_;
    
    my $pop_id      = $c->stash->{pop_id};
    my $trait_abbr  = $c->stash->{trait_abbr};
    my $trait_name  = $c->stash->{trait_name};
    
    my $data_set_type = $c->stash->{data_set_type};

    my ($traits_file, @traits, @trait_pages);
    my $prediction_id = $c->stash->{prediction_pop_id};
   
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
 
    if($data_set_type !~ /combined populations/) 
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
       
        my $trait_info   = $trait_id . "\t" . $trait_abbr;     
        my $trait_file  = $self->create_tempfile($c, "trait_info_${trait_id}");
        write_file($trait_file, $trait_info);

        my $dataset_file  = $self->create_tempfile($c, "dataset_info_${trait_id}");
        write_file($dataset_file, $data_set_type);
 
        my $prediction_population_file = $c->stash->{prediction_population_file};
       
        my $input_files = join("\t",
                                   $c->stash->{trait_combined_pheno_file},
                                   $c->stash->{trait_combined_geno_file},
                                   $trait_file,
                                   $dataset_file,
                                   $prediction_population_file
            );

        my $input_file = $self->create_tempfile($c, "input_files_combo_${trait_abbr}");
        write_file($input_file, $input_files);

        if ($c->stash->{prediction_pop_id})
        {       
            $c->stash->{input_files} = $input_file;
            $self->output_files($c);
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
                $self->output_files($c);
                $self->run_rrblup($c); 
       
            }
        }        
    }
    else 
    {
        my $name  = "trait_info_${trait_id}_pop_${pop_id}"; 
    
        my $trait_info = $trait_id . "\t" . $trait_abbr;
        my $file = $self->create_tempfile($c, $name);    
        $c->stash->{trait_file} = $file;       
        write_file($file, $trait_info);

        my $prediction_id = $c->stash->{prediction_pop_id};

        $self->output_files($c);
        
        if ($prediction_id)
        { 
            $prediction_id = "uploaded_${prediction_id}" if $c->stash->{uploaded_prediction};
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
            $self->output_files($c);
        
            if (-s $c->stash->{gebv_kinship_file} == 0 ||
                -s $c->stash->{gebv_marker_file}  == 0 ||
                -s $c->stash->{validation_file}   == 0       
                )
            {  
                $self->input_files($c);            
                $self->output_files($c);
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
   
    $c->stash->{r_script}    = 'R/gs.r';
    $self->run_r_script($c);
}


sub r_combine_populations  {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id     = $c->stash->{trait_id};
    my $trait_abbr   = $c->stash->{trait_abbr};
    my $trait_info   = $trait_id . "\t" . $trait_abbr;
    
    my $trait_file  = $self->create_tempfile($c, "trait_info_${trait_id}");
    write_file($trait_file, $trait_info);

    my $pheno_files = $c->stash->{multi_pops_pheno_files};
    my $geno_files  = $c->stash->{multi_pops_geno_files};
        
    my $input_files = join ("\t",
                            $pheno_files,
                            $geno_files,
                            $trait_file,
   
        );

    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
    
    my $output_files = join ("\t", 
                             $combined_pops_pheno_file,
                             $combined_pops_geno_file,
        );
                             
     
    my $tempfile_input = $self->create_tempfile($c, "input_files_${trait_id}_combine"); 
    write_file($tempfile_input, $input_files);

    my $tempfile_output = $self->create_tempfile($c, "output_files_${trait_id}_combine"); 
    write_file($tempfile_output, $output_files);
        
    die "\nCan't call combine populations R script without a trait id." if !$trait_id;
    die "\nCan't call combine populations R script without input files." if !$input_files;
    die "\nCan't call combine populations R script without output files." if !$output_files;    
    
    $c->stash->{input_files}  = $tempfile_input;
    $c->stash->{output_files} = $tempfile_output;
    $c->stash->{r_temp_file}  = "combine-pops-${trait_id}";
    $c->stash->{r_script}     = 'R/combine_populations.r';
    
    $self->run_r_script($c);

}


sub run_r_script {
    my ($self, $c) = @_;
    
    my $r_script     = $c->stash->{r_script};
    my $input_files  = $c->stash->{input_files};
    my $output_files = $c->stash->{output_files};
    my $r_temp_file  = $c->stash->{r_temp_file};
    
    CXGN::Tools::Run->temp_base($c->stash->{solgs_tempfiles_dir});
    my ( $r_in_temp, $r_out_temp ) =
        map 
    {
        my ( undef, $filename ) =
            tempfile(
                catfile(
                    CXGN::Tools::Run->temp_base(),
                    "${r_temp_file}-$_-XXXXXX",
                ),
            );
        $filename
    } 
    qw / in out /;
    {
        my $r_cmd_file = $c->path_to($r_script);
        copy($r_cmd_file, $r_in_temp)
            or die "could not copy '$r_cmd_file' to '$r_in_temp'";
    }

    try 
    { 
        my $r_process = CXGN::Tools::Run->run_cluster(
            'R', 'CMD', 'BATCH',
            '--slave',
            "--args $input_files $output_files",
            $r_in_temp,
            $r_out_temp,
            {
                working_dir => $c->stash->{solgs_tempfiles_dir},
                max_cluster_jobs => 1_000_000_000,
            },
            );
      
        $r_process->wait; 
  
    }
    catch 
    {
        my $err = $_;
        $err =~ s/\n at .+//s; 
        try
        { 
            $err .= "\n=== R output ===\n".file($r_out_temp)->slurp."\n=== end R output ===\n" 
        };
            
        $c->stash->{script_error} = "$r_script";
    }

}
 
 
sub get_solgs_dirs {
    my ($self, $c) = @_;
   
    my $tmp_dir         = $c->config->{cluster_shared_tempdir};
    my $solgs_dir       = catdir($tmp_dir, "solgs");
    my $solgs_cache     = catdir($tmp_dir, 'solgs', 'cache'); 
    my $solgs_tempfiles = catdir($tmp_dir, 'solgs', 'tempfiles');  
    my $correlation_dir = catdir($tmp_dir, 'correlation', 'cache');   
    my $solgs_upload    = catdir($tmp_dir, 'solgs', 'tempfiles', 'prediction_upload');
    
    mkpath ([$solgs_dir, $solgs_cache, $solgs_tempfiles, $solgs_upload, $correlation_dir], 0, 0755);
   
    $c->stash(solgs_dir                   => $solgs_dir, 
              solgs_cache_dir             => $solgs_cache, 
              solgs_tempfiles_dir         => $solgs_tempfiles,
              solgs_prediction_upload_dir => $solgs_upload,
              correlation_dir             => $correlation_dir,
        );

}


sub cache_file {
    my ($self, $c, $cache_data) = @_;
  
    my $cache_dir = $c->stash->{cache_dir};
   
    unless ($cache_dir) 
    {
	$cache_dir = $c->stash->{solgs_cache_dir};
    }
   
    my $file_cache  = Cache::File->new(cache_root => $cache_dir);
    $file_cache->purge();

    my $file  = $file_cache->get($cache_data->{key});

    unless ($file)
    {      
        $file = catfile($cache_dir, $cache_data->{file});
        write_file($file);
        $file_cache->set($cache_data->{key}, $file, '30 days');
    }

    $c->stash->{$cache_data->{stash_key}} = $file;
}


sub load_yaml_file {
    my ($self, $c, $file) = @_;

    $file =~ s/\.\w+//;
    $file =~ s/(^\/)//;
   
    my $form = $self->form;
    my $yaml_dir = '/forms/solgs';
 
    $form->load_config_filestem($c->path_to(catfile($yaml_dir, $file)));
    $form->process;
    
    $c->stash->{form} = $form;
 
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
