package solGS::Controller::Root;

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
use Scalar::Util 'weaken';
use CatalystX::GlobalContext ();
use Statistics::Descriptive;
use Math::Round::Var;
#use CXGN::Login;
#use CXGN::People::Person;
use CXGN::Tools::Run;
use JSON;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#

__PACKAGE__->config(namespace => '');

=head1 NAME

solGS::Controller::Root - Root Controller for solGS

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut


sub index :Path :Args(0) {
    my ($self, $c) = @_;     
    $c->forward('search');
}


sub submit :Path('/submit/intro') :Args(0) {
    my ($self, $c) = @_;
    $c->stash(template=>'/submit/intro.mas');
}


sub details_form : Path('/form/population/details') Args(0) FormConfig('population/details.yml')  {
    my ($self, $c) = @_;
    my $form = $c->stash->{form}; 
   
    if ($form->submitted_and_valid ) 
    {
        $c->res->redirect('/form/population/phenotype');
    }
    else 
    {
        $c->stash(template =>'/form/population/details.mas',
                  form     => $form
            );
    }
}

sub phenotype_form : Path('/form/population/phenotype') Args(0) FormConfig('population/phenotype.yml') {
    my ($self, $c) = @_;
    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) 
    {
      $c->res->redirect('/form/population/genotype');
    }        
    else
    {
        $c->stash(template => '/form/population/phenotype.mas',
                  form     => $form
            );
    }

}


sub genotype_form : Path('/form/population/genotype') Args(0) FormConfig('population/genotype.yml') {
    my ($self, $c) = @_;
    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) 
    {
      $c->res->redirect('/population/12');
    }        
    else
    {
        $c->stash(template => '/form/population/genotype.mas',
                  form     => $form
            );
    }

}


sub search : Path('/search/solgs') Args() FormConfig('search/solgs.yml') {
    my ($self, $c) = @_;
    my $form = $c->stash->{form};

    $self->gs_traits_index($c);
    my $gs_traits_index = $c->stash->{gs_traits_index};
    
    my $project_rs = $c->model('solGS')->all_projects($c);
    $self->projects_links($c, $project_rs);
    my $projects = $c->stash->{projects_pages};

    my $query;
    if ($form->submitted_and_valid) 
    {
        $query = $form->param_value('search.search_term');
        $c->res->redirect("/search/result/traits/$query");       
    }        
    else
    {
        $c->stash(template        => '/search/solgs.mas',
                  form            => $form,
                  message         => $query,
                  gs_traits_index => $gs_traits_index,
                  result          => $projects,
                  pager           => $project_rs->pager,
                  page_links      => sub {uri ( query => {  page => shift } ) }
            );
    }

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
        
        my $checkbox;
       # my $checkbox = qq |<form> <input type="checkbox" name="project" value="$pr_id" /> </form> |;
        push @projects_pages, [ $checkbox, qq|<a href="/population/$pr_id" onclick="solGS.waitPage()">$pr_name</a>|, 
                               $pr_desc, $pr_location, $pr_year
        ];
    }

    $c->stash->{projects_pages} = \@projects_pages;

}


sub show_search_result_pops : Path('/search/result/populations') Args(1) {
    my ($self, $c, $trait_id) = @_;
     
    my $projects_rs = $c->model('solGS')->search_populations($c, $trait_id);
    my $trait       = $c->model('solGS')->trait_name($c, $trait_id);
    
    $self->get_projects_details($c, $projects_rs);
    my $projects = $c->stash->{projects_details};
     
    my @projects_list;
   
    foreach my $pr_id (keys %$projects) 
    {
        my $pr_name     = $projects->{$pr_id}{project_name};
        my $pr_desc     = $projects->{$pr_id}{project_desc};
        my $pr_year     = $projects->{$pr_id}{project_year};
        my $pr_location = $projects->{$pr_id}{project_location};
        my $checkbox;
       # my $checkbox = qq |<form> <input type="checkbox" name="project" value="$pr_id" /> </form> |;
        push @projects_list, [ $checkbox, qq|<a href="/trait/$trait_id/population/$pr_id" onclick="solGS.waitPage()">$pr_name</a>|, 
                               $pr_desc, $pr_location, $pr_year
        ];
    }

    my $form;
    if ($projects_rs)
    {
        $self->get_trait_name($c, $trait_id);
       
        $c->stash(template   => '/search/result/populations.mas',
                  result     => \@projects_list,
                  form       => $form,
                  trait_id   => $trait_id,
                  query      => $trait,
                  pager      => $projects_rs->pager,
                  page_links => sub {uri ( query => { trait => $trait, page => shift } ) }
            );
    }
    else
    {
        $c->res->redirect('/search/solgs');     
    }

}


sub get_projects_details {
    my ($self,$c, $pr_rs) = @_;
 
    my ($year, $location, $pr_id, $pr_name, $pr_desc);
    my %projects_details = ();

    while (my $pr = $pr_rs->next) 
    {
       
        $pr_id   = $pr->project_id;
        $pr_name = $pr->name;
        $pr_desc = $pr->description;
       
        my $pr_yr_rs = $c->model('solGS')->project_year($c, $pr_id);
        
        while (my $pr = $pr_yr_rs->next) 
        {
            $year = $pr->value;
        }

        my $pr_loc_rs = $c->model('solGS')->project_location($c, $pr_id);
    
        while (my $pr = $pr_loc_rs->next) 
        {
            $location = $pr->description;          
        } 

        $projects_details{$pr_id}  = { 
                  project_name     => $pr_name, 
                  project_desc     => $pr_desc, 
                  project_year     => $year, 
                  project_location => $location,
        };
    }
        
    $c->stash->{projects_details} = \%projects_details;

}


sub show_search_result_traits : Path('/search/result/traits') Args(1)  FormConfig('search/solgs.yml'){
    my ($self, $c, $query) = @_;
  
    my @rows;
    my $result = $c->model('solGS')->search_trait($c, $query);
   
    while (my $row = $result->next)
    {
        my $id   = $row->cvterm_id;
        my $name = $row->name;
        my $def  = $row->definition;
        #my $checkbox = qq |<form> <input type="checkbox" name="trait" value="$name" /> </form> |;
        my $checkbox;
        push @rows, [ $checkbox, qq |<a href="/search/result/populations/$id">$name</a>|, $def];      
    }

    if (@rows)
    {
       $c->stash(template   => '/search/result/traits.mas',
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
        
        my $project_rs = $c->model('solGS')->all_projects($c);
        $self->projects_links($c, $project_rs);
        my $projects = $c->stash->{projects_pages};
        
        my $form = $c->stash->{form};
        $c->stash(template        => '/search/solgs.mas',
                  form            => $form,
                  message         => $query,
                  gs_traits_index => $gs_traits_index,
                  result          => $projects,
                  pager           => $project_rs->pager,
                  page_links      => sub {uri ( query => {  page => shift } ) }
            );
    }

} 


sub population : Regex('^population/([\d]+)(?:/([\w+]+))?'){
    my ($self, $c) = @_;
   
    my ($pop_id, $action) = @{$c->req->captures};

    if ($pop_id )
    {   
        $c->stash->{pop_id} = $pop_id;  
        $self->phenotype_file($c);
        $self->genotype_file($c);
        $self->get_all_traits($c);
        $self->project_description($c, $pop_id);

        $c->stash->{template} = '/population.mas';
      
        if ($action && $action =~ /selecttraits/ ) {
            $c->stash->{no_traits_selected} = 'none';
        }
        else {
            $c->stash->{no_traits_selected} = 'some';
        }

        $self->select_traits($c);
    }
    else 
    {
        $c->throw(public_message =>"Required population id is missing.", 
                  is_client_error => 1, 
            );
    }
} 


sub project_description {
    my ($self, $c, $pr_id) = @_;

    my $pr_rs = $c->model('solGS')->project_details($c, $pr_id);

    while (my $row = $pr_rs->next)
    {
        $c->stash(project_id   => $row->id,
                  project_name => $row->name,
                  project_desc => $row->description
            );
    }
    
    $self->genotype_file($c);
    my $geno_file  = $c->stash->{genotype_file};
    my @geno_lines = read_file($geno_file);
    my $stocks_no  = scalar(@geno_lines) - 1;
    my $markers_no = scalar(split ('\t', $geno_lines[0])) - 1;

    $self->phenotype_file($c);
    my $pheno_file = $c->stash->{phenotype_file};
    my @phe_lines  = read_file($pheno_file);   
    my $traits     = $phe_lines[0];

    $self->filter_phenotype_header($c);
    my $filter_header = $c->stash->{filter_phenotype_header};
   
    $traits       =~ s/$filter_header//g;

    my @traits    =  split (/\t/, $traits);    
    my $traits_no = scalar(uniq(@traits));

    $c->stash(markers_no => $markers_no,
              traits_no  => $traits_no,
              stocks_no  => $stocks_no
        );
}


sub select_traits   {
    my ($self, $c) = @_;
    my $traits_form = $self->form;
    $traits_form->load_config_file('population/traits.yml');
    
    $c->stash->{traits_form} = $traits_form;
 
}


sub trait :Path('/trait') Args(3) {
    my ($self, $c, $trait_id, $key, $pop_id) = @_;
   
    if ($pop_id && $trait_id)
    {   
        $self->get_trait_name($c, $trait_id);
        $c->stash->{pop_id} = $pop_id;
        $self->project_description($c, $pop_id);
                            
        $self->get_rrblup_output($c);
        $self->gs_files($c);

        $self->get_trait_name($c, $trait_id);
        $self->trait_phenotype_stat($c);
        
        $c->stash->{template} = "/population/trait.mas";
    }
    else 
    {
        $c->throw(public_message =>"Required population id or/and trait id are missing.", 
                  is_client_error => 1, 
            );
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

}


sub input_files {
    my ($self, $c) = @_;
    
    $self->genotype_file($c);
    $self->phenotype_file($c);
   
    my $prediction_population_file = 'cap123geno_prediction.csv';
  
    my $pheno_file  = $c->stash->{phenotype_file};
    my $geno_file   = $c->stash->{genotype_file};
    my $traits_file = $c->stash->{selected_traits_file};
    my $trait_file  = $c->stash->{trait_file};
    my $pop_id      = $c->stash->{pop_id};
   
    my $input_files = join ("\t",
                            $pheno_file,
                            $geno_file,
                            $traits_file,
                            $trait_file,
                            $prediction_population_file
        );

    my $tmp_dir         = $c->stash->{solgs_tempfiles_dir};
    my ($fh, $tempfile) = tempfile("input_files_${pop_id}-XXXXX", 
                                   DIR => $tmp_dir
        );

    $fh->print($input_files);
   
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

    my $prediction_id = $c->stash->{prediction_pop_id};
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
                          $c->stash->{selected_traits_gebv_file},
                          $pred_pop_gebvs_file
        );
                          
    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};

    my ($fh, $tempfile) = tempfile("output_files_${trait}_$pop_id-XXXXX", 
                                   DIR => $tmp_dir
        );

    $fh->print($file_list);
    
    $c->stash->{output_files} = $tempfile;

}


sub gebv_marker_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
    my $cache_data = {key       => 'gebv_marker_' . $pop_id . '_'.  $trait,
                      file      => 'gebv_marker_' . $trait . '_' . $pop_id,
                      stash_key => 'gebv_marker_file'
    };

    $self->cache_file($c, $cache_data);

}


sub trait_phenodata_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
    my $cache_data = {key       => 'phenotype_' . $pop_id . '_'.  $trait,
                      file      => 'phenotype_trait_' . $trait . '_' . $pop_id,
                      stash_key => 'trait_phenodata_file'
    };

    $self->cache_file($c, $cache_data);

}


sub gebv_kinship_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
 
    my $cache_data = {key       => 'gebv_kinship_' . $pop_id . '_'.  $trait,
                      file      => 'gebv_kinship_' . $trait . '_' . $pop_id,
                      stash_key => 'gebv_kinship_file'
    };

    $self->cache_file($c, $cache_data);

}


sub blups_file {
    my ($self, $c) = @_;
    
    $c->stash->{blups} = $c->stash->{gebv_kinship_file};
    $self->top_blups($c);
}


sub download_blups :Path('/download/blups/pop') Args(3) {
    my ($self, $c, $pop_id, $trait, $trait_id) = @_;   
 
    $self->get_trait_name($c, $trait_id);
    $c->stash->{pop_id} = $pop_id;

    $self->output_files($c);
    $self->blups_file($c);
    my $blups_file = $c->stash->{blups};

    unless (!-e $blups_file || -s $blups_file == 0) 
    {
        my @blups =  map { [ split(/\t/) ] }  read_file($blups_file);
    
        $c->stash->{'csv'}={ data => \@blups };
        $c->forward("solGS::View::Download::CSV");
    } 

}


sub download_marker_effects :Path('/download/marker/pop') Args(3) {
    my ($self, $c, $pop_id, $trait, $trait_id) = @_;   
 
    $self->get_trait_name($c, $trait_id);
    $c->stash->{pop_id} = $pop_id;

    $self->gebv_marker_file($c);
    my $markers_file = $c->stash->{gebv_marker_file};

    unless (!-e $markers_file || -s $markers_file == 0) 
    {
        my @effects =  map { [ split(/\t/) ] }  read_file($markers_file);
    
        $c->stash->{'csv'}={ data => \@effects };
        $c->forward("solGS::View::Download::CSV");
    } 

}


sub download_urls {
    my ($self, $c) = @_;
    
    my $pop_id         = $c->stash->{pop_id};
    my $trait_id       = $c->stash->{trait_id};
    my $ranked_genos_file = $c->stash->{genotypes_mean_gebv_file};
    if ($ranked_genos_file) 
    {
        ($ranked_genos_file) = fileparse($ranked_genos_file);
    }
    
    my $blups_url      = qq | <a href="/download/blups/pop/$pop_id/trait/$trait_id">Download all GEBVs</a> |;
    my $marker_url     = qq | <a href="/download/marker/pop/$pop_id/trait/$trait_id">Download all marker effects</a> |;
    my $validation_url = qq | <a href="/download/validation/pop/$pop_id/trait/$trait_id">Download model accuracy report</a> |;
    my $ranked_genotypes_url = qq | <a href="/download/ranked/genotypes/pop/$pop_id/$ranked_genos_file">Download all ranked genotypes</a> |;
   
    $c->stash(blups_download_url            => $blups_url,
              marker_effects_download_url   => $marker_url,
              validation_download_url       => $validation_url,
              ranked_genotypes_download_url => $ranked_genotypes_url,
        );
}


sub top_blups {
    my ($self, $c) = @_;
    
    my $blups_file = $c->stash->{blups};
    
    my $blups = $self->convert_to_arrayref($c, $blups_file);
  
    my @top_blups = @$blups[0..9];
 
    $c->stash->{top_blups} = \@top_blups;
}


sub top_markers {
    my ($self, $c) = @_;
    
    my $markers_file = $c->stash->{gebv_marker_file};

    my $markers = $self->convert_to_arrayref($c, $markers_file);
    
    my @top_markers = @$markers[0..9];

    $c->stash->{top_marker_effects} = \@top_markers;
}


sub validation_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
    my $cache_data = {key       => 'cross_validation_' . $pop_id . '_' . $trait, 
                      file      => 'cross_validation_' . $trait . '_' . $pop_id,
                      stash_key => 'validation_file'
    };

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


sub download_validation :Path('/download/validation/pop') Args(3) {
    my ($self, $c, $pop_id, $trait, $trait_id) = @_;   
 
    $self->get_trait_name($c, $trait_id);
    $c->stash->{pop_id} = $pop_id;

    $self->validation_file($c);
    my $validation_file = $c->stash->{validation_file};

    unless (!-e $validation_file || -s $validation_file == 0) 
    {
        my @validation =  map { [ split(/\t/) ] }  read_file($validation_file);
    
        $c->stash->{'csv'}={ data => \@validation };
        $c->forward("solGS::View::Download::CSV");
    }
 
}

 
sub prediction_population :Path('/model') Args(3) {
    my ($self, $c, $model_id, $pop, $prediction_id) = @_;
 
    $c->res->redirect("/analyze/traits/population/$model_id/$prediction_id");

}


sub prediction_pop_gebvs_file {    
    my ($self, $c, $identifier, $trait_id) = @_;

    my $cache_data = {key       => 'prediction_pop_gebvs_' . $identifier . '_' . $trait_id, 
                      file      => 'prediction_pop_gebvs_' . $identifier . '_' . $trait_id,
                      stash_key => 'prediction_pop_gebvs_file'
    };

    $self->cache_file($c, $cache_data);

}


sub download_prediction_GEBVs :Path('/download/prediction/model') Args(4) {
    my ($self, $c, $pop_id, $prediction, $prediction_id, $trait_id) = @_;   
 
    $self->get_trait_name($c, $trait_id);
    $c->stash->{pop_id} = $pop_id;

    my $identifier = $pop_id . "_" . $prediction_id;
    $self->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    my $prediction_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    
    unless (!-e $prediction_gebvs_file || -s $prediction_gebvs_file == 0) 
    {
        my @prediction_gebvs =  map { [ split(/\t/) ] }  read_file($prediction_gebvs_file);
    
        $c->stash->{'csv'}={ data => \@prediction_gebvs };
        $c->forward("solGS::View::Download::CSV");
    }
 
}


sub prediction_pop_analyzed_traits {
    my ($self, $c) = @_;
        
    my $training_pop_id = 134; # $c->stash->{pop_id};
    my $prediction_pop_id = 268; # $c->stash->{prediction_pop_id};

    my $dir = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir or die "can't open $dir: $!\n";
   
    my @files  =  grep { /prediction_pop_gebvs_$training_pop_id/ && -f "$dir/$_" } 
                 readdir($dh);   
    closedir $dh; 
        
    my @copy_files = @files;
    my @trait_ids = map { s/prediction_pop_gebvs_|($training_pop_id)|($prediction_pop_id)|_//g ? $_ : 0} @copy_files;
  
    $c->stash->{prediction_pop_analyzed_traits} = \@trait_ids;
    $c->stash->{prediction_pop_analyzed_traits_files} = \@files;
    
}


sub download_prediction_urls {
    my ($self, $c) = @_;
    
    $self->prediction_pop_analyzed_traits($c);
    my $trait_ids = $c->stash->{prediction_pop_analyzed_traits};
    
    my $download_url = $c->stash->{download_prediction};

    foreach my $trait_id (@$trait_ids) 
    {
        my $pop_id = $c->stash->{pop_id};
        my $prediction_id = $c->stash->{prediction_pop_id};

        $self->get_trait_name($c, $trait_id);
        my $trait_name  = $c->stash->{trait_name};

        
        $download_url   .= " | " if $download_url;
        $download_url   .= qq | <a href="/download/prediction/model/$pop_id/prediction/$prediction_id/$trait_id">$trait_name</a> |;
    }
    
    $c->stash->{download_prediction} = $download_url;
  
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


sub get_trait_name {
    my ($self, $c, $trait_id) = @_;

    my $trait_name = $c->model('solGS')->trait_name($c, $trait_id);
  
    if (!$trait_name) 
    { 
        $c->throw(public_message =>"No trait name corresponding to the id was found in the database.", 
                  is_client_error => 1, 
            );
    }

    my $abbr = $self->abbreviate_term($c, $trait_name);
   
    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;
    $c->stash->{trait_abbr} = $abbr;

}

#creates and writes a list of GEBV files of 
#traits selected for ranking genotypes.
sub get_gebv_files_of_traits {
    my ($self, $c, $traits, $pred_pop_id) = @_;
    

    my $pop_id = $c->stash->{pop_id}; 
    my $dir = $c->stash->{solgs_cache_dir};
    my $gebv_files; 

    $self->prediction_pop_analyzed_traits($c);
    my $pred_gebv_files = $c->stash->{prediction_pop_analyzed_traits_files};
   
   if (@$pred_gebv_files) 
   {
       foreach (@$pred_gebv_files)
       {
           $gebv_files .= catfile($dir, $_);
           $gebv_files .= "\t" unless (@$pred_gebv_files[-1] eq $_);
       }     
   }
   
    unless ($pred_gebv_files->[0])
    {
        foreach my $tr (@$traits) 
        {         
            opendir my $dh, $dir 
                or die "can't open $dir: $!\n";
 
            my ($file)   = grep(/gebv_kinship_${tr}_${pop_id}/, readdir($dh));

            $gebv_files .= catfile($dir, $file);
            $gebv_files .= "\t" unless (@$traits[-1] eq $tr);
    
            closedir $dh;  
        }
    }
    
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id; 
     
    my ($fh, $file) = tempfile("gebv_files_of_traits_${pop_id}${pred_file_suffix}-XXXXX",
                               DIR => $c->stash->{solgs_tempfiles_dir}
        );
    $fh->close;

    
    write_file($file, $gebv_files);
   
    $c->stash->{gebv_files_of_traits} = $file;
    
}


sub gebv_rel_weights {
    my ($self, $c, $params, $pred_pop_id) = @_;
    
    my $pop_id      = $c->stash->{pop_id};
  
    my $rel_wts = "\t" . 'relative_weight' . "\n";
    foreach my $tr (keys %$params)
    {      
        my $wt = $params->{$tr};
        unless ($tr eq 'rank')
        {
            $rel_wts .= $tr . "\t" . $wt;
            $rel_wts .= "\n" unless( (keys %$params)[-1] eq $tr);
        }
    }

    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id; 
    
    my ($fh, $file) =  tempfile("rel_weights_${pop_id}${pred_file_suffix}-XXXXX",
                                DIR => $c->stash->{solgs_tempfiles_dir}
        );

    write_file($file, $rel_wts);
    
    $c->stash->{rel_weights_file} = $file;
    
}


sub ranked_genotypes_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id = $c->stash->{pop_id};
 
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;
  
    my ($fh, $file) =  tempfile("ranked_genotypes_${pop_id}${pred_file_suffix}-XXXXX",
                                DIR => $c->stash->{solgs_tempfiles_dir}
        );

    $c->stash->{ranked_genotypes_file} = $file;
   
}


sub mean_gebvs_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id      = $c->stash->{pop_id};
   
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;

    my ($fh, $file) =  tempfile("genotypes_mean_gebv_${pop_id}${pred_file_suffix}-XXXXX",
                                DIR => $c->stash->{solgs_tempfiles_dir}
        );

    $c->stash->{genotypes_mean_gebv_file} = $file;
   
}

sub download_ranked_genotypes :Path('/download/ranked/genotypes/pop') Args(2) {
    my ($self, $c, $pop_id, $genotypes_file) = @_;   
 
    $c->stash->{pop_id} = $pop_id;
  
    $genotypes_file = catfile($c->stash->{solgs_tempfiles_dir}, $genotypes_file);
  
    unless (!-e $genotypes_file || -s $genotypes_file == 0) 
    {
        my @ranks =  map { [ split(/\t/) ] }  read_file($genotypes_file);
    
        $c->stash->{'csv'}={ data => \@ranks };
        $c->forward("solGS::View::Download::CSV");
    } 

}


sub rank_genotypes : Private {
    my ($self, $c, $pred_pop_id) = @_;

    my $pop_id      = $c->stash->{pop_id};
    

    my $input_files = join("\t", 
                           $c->stash->{rel_weights_file},
                           $c->stash->{gebv_files_of_traits}
        );

    $self->ranked_genotypes_file($c, $pred_pop_id);
    $self->mean_gebvs_file($c, $pred_pop_id);

    my $output_files = join("\t",
                            $c->stash->{ranked_genotypes_file},
                            $c->stash->{genotypes_mean_gebv_file}
        );
 
   
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $pred_pop_id  if $pred_pop_id;
    
    my ($fh_o, $output_file) = tempfile("output_rank_genotypes_${pop_id}${pred_file_suffix}-XXXXX",
                                        DIR => $c->stash->{solgs_tempfiles_dir}
        );
    $fh_o->close;

    write_file($output_file, $output_files);
    $c->stash->{output_files} = $output_file;
    
    my ($fh_i, $input_file) = tempfile("input_rank_genotypes_${pop_id}${pred_file_suffix}-XXXXX",
                                       DIR => $c->stash->{solgs_tempfiles_dir}
        );
    $fh_i->close;

    write_file($input_file, $input_files);
    $c->stash->{input_files} = $input_file;

    $c->stash->{r_temp_file} = "rank-gebv-genotypes-${pop_id}${pred_file_suffix}";
    $c->stash->{r_script}    = 'R/rank_genotypes.r';
    
    $self->run_r_script($c);
    $self->download_urls($c);
    $self->top_ranked_genotypes($c);
  
}

#based on multiple traits performance
sub top_ranked_genotypes {
    my ($self, $c) = @_;
    
    my $genotypes_file = $c->stash->{genotypes_mean_gebv_file};
  
    my $genos_data = $self->convert_to_arrayref($c, $genotypes_file);
    shift(@$genos_data); #add condition
    my @top_genotypes = @$genos_data[0..9];
    
    $c->stash->{top_ranked_genotypes} = \@top_genotypes;
}


#converts a tab delimitted > two column data file
#into an array of array ref
sub convert_to_arrayref {
    my ($self, $c, $file) = @_;

    open my $fh, $file or die "couldnot open $file: $!";    
    
    my @data;   
    while (<$fh>)
    {
        push @data,  map { [ split(/\t/) ] } $_;
    }
   
    shift(@data);
    
    return \@data;

}


sub trait_phenotype_file {
    my ($self, $c, $pop_id, $trait) = @_;

    my $dir = $c->stash->{solgs_cache_dir};
    
    opendir my $dh, $dir or die "can't open $dir: $!\n";
 
    my ($file)   = grep(/phenotype_trait_${trait}_${pop_id}/, readdir($dh));
    my $trait_pheno_file .= catfile($dir, $file);
       
    closedir $dh; 

    $c->stash->{trait_phenotype_file} = $trait_pheno_file;

}

#retrieve from db prediction pops relevant to the
#training population
sub list_of_prediction_pops {
    my ($self, $c, $training_pop_id, $download_prediction) = @_;
   
    my $prediction_pop_id = 268;
    my $pred_pop_name = qq | <a href="/model/$training_pop_id/prediction/$prediction_pop_id" onclick="solGS.waitPage()">Barley prediction population test</a> |;

    my $pred_pop = [ ['', $pred_pop_name, 'barley prediction population from crosses...', 'F1', '2013', $download_prediction]];
    
    $c->stash->{list_of_prediction_pops} = $pred_pop;

}


sub traits_to_analyze :Regex('^analyze/traits/population/([\d]+)(?:/([\d+]+))?') {
    my ($self, $c) = @_; 
   
    my ($pop_id, $prediction_id) = @{$c->req->captures};
    
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{prediction_pop_id} = $prediction_id;
  
    my @selected_traits = $c->req->param('trait_id');
  
    my $single_trait_id;
    if (!@selected_traits)
    {
        $self->analyzed_traits($c);
        @selected_traits = @{$c->stash->{analyzed_traits}};
    }

    if (!@selected_traits)
    {
        $c->res->redirect("/population/$pop_id/selecttraits");
    }
    elsif (scalar(@selected_traits) == 1)
    {
        $single_trait_id = $selected_traits[0]; 
        $c->res->redirect("/trait/$single_trait_id/population/$pop_id");
    }
    elsif(scalar(@selected_traits) > 1)
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
                            my $trait_id   =  $c->model('solGS')->get_trait_id($c, $trait_name);

                            $traits    .= $r->[0];
                            $traits    .= "\t" unless ($i == $#selected_traits);
                            $trait_ids .= $trait_id;                                                        
                        }
                    }
                }
            }
            else 
            {
                my $tr = $c->model('solGS')->trait_name($c, $selected_traits[$i]);
   
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
        
        my $tmp_dir     = $c->stash->{solgs_tempfiles_dir}; 
        my ($fh, $file) = tempfile("selected_traits_pop_${pop_id}-XXXXX", 
                                   DIR => $tmp_dir
            );

        $fh->print($traits);
        $fh->close;

        my ($fh2, $file2) = tempfile("trait_${single_trait_id}_pop_${pop_id}-XXXXX", 
                                     DIR => $tmp_dir
                );
        $fh2->close;
  
        $c->stash->{selected_traits_file} = $file;
        $c->stash->{trait_file} = $file2;
        $c->forward('get_rrblup_output');
  
    }

    $c->res->redirect("/traits/all/population/$pop_id/$prediction_id");

}


sub all_traits_output :Regex('^traits/all/population/([\d]+)(?:/([\d+]+))?') {
     my ($self, $c) = @_;
     
     my ($pop_id, $pred_pop_id) = @{$c->req->captures};

     my @traits = $c->req->param; 
     @traits = grep {$_ ne 'rank'} @traits;
     $c->stash->{pop_id} = $pop_id;

     if ($pred_pop_id)
     {
         $c->stash->{prediction_pop_id} = $pred_pop_id;
         $c->stash->{population_is} = 'prediction population';
     }
     else
     {
         $c->stash->{prediction_pop_id} = 'N/A';
         $c->stash->{population_is} = 'training population';
     }

     $self->analyzed_traits($c);
     my @analyzed_traits = @{$c->stash->{analyzed_traits}};
 
     if (!@analyzed_traits) 
     {
         $c->res->redirect("/population/$pop_id/selecttraits/");
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

         my $trait_id   = $c->model('solGS')->get_trait_id($c, $trait_name);
         my $trait_abbr = $c->stash->{trait_abbr}; 
         
         my $dir = $c->stash->{solgs_cache_dir};
         opendir my $dh, $dir or die "can't open $dir: $!\n";
    
         my @validation_file  = grep { /cross_validation_${trait_abbr}_${pop_id}/ && -f "$dir/$_" } 
                                readdir($dh);   
         closedir $dh; 
        
         my @accuracy_value = grep {/Average/} read_file(catfile($dir, $validation_file[0]));
         @accuracy_value    = split(/\t/,  $accuracy_value[0]);

         push @trait_pages,  [ qq | <a href="/trait/$trait_id/population/$pop_id" onclick="solGS.waitPage()">$trait_name</a>|, $accuracy_value[1] ];
     }


     $self->project_description($c, $pop_id);
     my $project_name = $c->stash->{project_name};
     my $project_desc = $c->stash->{project_desc};
     
     my @model_desc = ([qq | <a href="/population/$pop_id">$project_name</a> |, $project_desc, \@trait_pages]);
     
     $c->stash->{template}    = '/population/multiple_traits_output.mas';
     $c->stash->{trait_pages} = \@trait_pages;
     $c->stash->{model_data}  = \@model_desc;

     $self->download_prediction_urls($c);
     my $download_prediction = $c->stash->{download_prediction};
 
     if ($download_prediction)
     {
         $c->stash->{download_prediction} = $download_prediction;
     }
     else
     {
         $download_prediction = 'N/A';
         $c->stash->{download_prediction} = $download_prediction;
     }
    
     #get prediction populations list..     
     $self->list_of_prediction_pops($c, $pop_id, $download_prediction);
    
     my @values;
     foreach (@traits)
     {
         push @values, $c->req->param($_);
     }
      
     if (@values) 
     {
         $self->get_gebv_files_of_traits($c, \@traits, $pred_pop_id);
         my $params = $c->req->params;
         $self->gebv_rel_weights($c, $params, $pred_pop_id);
         
         $c->forward('rank_genotypes', [$pred_pop_id]);
         
         my $geno = $self->tohtml_genotypes($c);
         
         my $link = $c->stash->{ranked_genotypes_download_url};
         
         my $ret->{status} = 'failed';
         my $ranked_genos = $c->stash->{top_ranked_genotypes};
        
         if (@$ranked_genos) 
         {
             $ret->{status} = 'success';
             $ret->{genotypes} = $geno;
             $ret->{link} = $link;
         }
               
         $ret = to_json($ret);
        
         $c->res->content_type('application/json');
         $c->res->body($ret);
    }
}


sub phenotype_graph :Path('/phenotype/graph') Args(0) {
    my ($self, $c) = @_;

    my $pop_id   = $c->req->param('pop_id');
    my $trait_id = $c->req->param('trait_id');

    my $trait_name = $c->model('solGS')->trait_name($c, $trait_id);
    my $trait_abbr = $self->abbreviate_term($c, $trait_name);
    
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{trait_abbr} = $trait_abbr;
     $c->stash->{trait_id} = $trait_id;

    $self->trait_phenotype_file($c, $pop_id, $trait_abbr);
    my $trait_pheno_file = $c->{stash}->{trait_phenotype_file};
    my $trait_data = $self->convert_to_arrayref($c, $trait_pheno_file);

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
    my $trait_abbr = $c->stash->{trait_abbr};
    my $pop_id = $c->stash->{pop_id};

    $self->trait_phenotype_file($c, $pop_id, $trait_abbr);
    my $trait_pheno_file = $c->{stash}->{trait_phenotype_file};
    my $trait_data = $self->convert_to_arrayref($c, $trait_pheno_file);

    my @pheno_data;   
    foreach (@$trait_data) 
    {
        unless (!$_->[0]) {
            push @pheno_data, $_->[1]; 
        }
    }

    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@pheno_data);
    
    my $min  = $stat->min; 
    my $max  = $stat->max; 
    my $mean = $stat->mean;
    my $std  = $stat->standard_deviation;
    my $cnt  = $stat->count;
    
    my $round = Math::Round::Var->new(0.01);
    $std  = $round->round($std);
    $mean = $round->round($mean);

    my @desc_stat =  ( [ 'No. of genotypes', $cnt ], 
                       [ 'Minimum', $min ], 
                       [ 'Maximum', $max ],
                       [ 'Mean', $mean ],
                       [ 'Standard deviation', $std ]
        );
   
    $c->stash->{descriptive_stat} = \@desc_stat;
    
}

#sends an array of trait gebv data to an ajax request
#with a population id and trait id parameters
sub gebv_graph :Path('/trait/gebv/graph') Args(0) {
    my ($self, $c) = @_;

    my $pop_id   = $c->req->param('pop_id');
    my $trait_id = $c->req->param('trait_id');
    $c->stash->{pop_id} = $pop_id;

    $self->get_trait_name($c, $trait_id);
       
    $self->gebv_kinship_file($c);
    my $gebv_file = $c->stash->{gebv_kinship_file};    
    my $gebv_data = $self->convert_to_arrayref($c, $gebv_file);

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
  
    my $genotypes = $c->stash->{top_ranked_genotypes};
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

    $self->add_trait_ids($c, $headers);
       
}


sub add_trait_ids {
    my ($self, $c, $list) = @_;   
    
    $list =~ s/\n//;
    my @traits = split (/\t/, $list);
  
    my $table = 'trait_name' . "\t" . 'trait_id' . "\n"; 
    
    my $acronym_pairs = $self->get_acronym_pairs($c);
    foreach (@$acronym_pairs)
    {
        my $trait_name = $_->[1];
        $trait_name =~ s/\n//g;
        my $trait_id = $c->model('solGS')->get_trait_id($c, $trait_name);
        $table .= $trait_name . "\t" . $trait_id . "\n";
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

    my ($file)   =  grep(/traits_acronym_pop_${pop_id}/, readdir($dh));
    $dh->close;

    my $acronyms_file = catfile($dir, $file);
      
   
    my @acronym_pairs;
    if (-f $acronyms_file) 
    {
        @acronym_pairs =  map { [ split(/\t/) ] }  read_file($acronyms_file);   
        shift(@acronym_pairs); # remove header;
    }

    return \@acronym_pairs;

}


sub traits_acronym_table {
    my ($self, $c, $acronym_table) = @_;
    
    my $table = 'acronym' . "\t" . 'name' . "\n"; 

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
    my $pop_id = $c->stash->{pop_id};

    my $dir = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir or die "can't open $dir: $!\n";
    
    my @files  = map { $_ =~ /($pop_id)/ ? $_ : 0 } 
                 grep { /gebv_kinship_[a-zA-Z0-9]/ && -f "$dir/$_" } 
                 readdir($dh);   
    closedir $dh;                     
    
    my @traits = map { s/gebv|kinship|_|($pop_id)//g ? $_ : 0} @files;
  
    $c->stash->{analyzed_traits} = \@traits;
    $c->stash->{analyzed_traits_files} = \@files;
}


sub filter_phenotype_header {
    my ($self, $c) = @_;
    
    my $meta_headers = "uniquename\t|object_id\t|object_name\t|stock_id\t|stock_name\t";
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

    my $rs = $c->model('solGS')->all_gs_traits($c);
 
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
        $trait_index .= qq | <a href=/gs/traits/$v_i>$v_i</a> |;
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
        push @traits_urls, [ qq | <a href="/search/result/traits/$tr">$tr</a> | ];
    }
    $c->stash->{traits_urls} = \@traits_urls;
}


sub gs_traits : PathPart('gs/traits') Chained Args(1) {
    my ($self, $c, $index) = @_;
    
    if ($index =~ /^\w{1}$/) 
    {
        $self->traits_starting_with($c, $index);
        my $traits_gr = $c->stash->{trait_subgroup};
        
        $self->hyperlink_traits($c, $traits_gr);
        my $traits_urls = $c->stash->{traits_urls};
        
        $c->stash( template    => '/search/traits/list.mas',
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
  
    my $file_cache  = Cache::File->new(cache_root => $c->stash->{solgs_cache_dir});
    $file_cache->purge();
   
    my $key        = "phenotype_data_" . $pop_id;
    my $pheno_file = $file_cache->get($key);

    unless ($pheno_file)
    {  
        $pheno_file = catfile($c->stash->{solgs_cache_dir}, "phenotype_data_" . $pop_id . ".txt");
        $c->model('solGS')->phenotype_data($c, $pop_id);
        my $data = $c->stash->{phenotype_data};
        
        $data = $self->format_phenotype_dataset($c, $data);
        write_file($pheno_file, $data);

        $file_cache->set($key, $pheno_file, '30 days');
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
    my ($self, $c) = @_;
    my $pop_id     = $c->stash->{pop_id};
    
    die "Population id must be provided to get the genotype data set." if !$pop_id;
  
    my $file_cache  = Cache::File->new(cache_root => $c->stash->{solgs_cache_dir});
    $file_cache->purge();
   
    my $key        = "genotype_data_" . $pop_id;
    my $geno_file = $file_cache->get($key);

    unless ($geno_file)
    {  
        $geno_file = catfile($c->stash->{solgs_cache_dir}, "genotype_data_" . $pop_id . ".txt");
        $c->model('solGS')->genotype_data($c, $pop_id);
        my $data = $c->stash->{genotype_data};
        
        write_file($geno_file, $data);

        $file_cache->set($key, $geno_file, '30 days');
    }
   
    $c->stash->{genotype_file} = $geno_file;

}


sub get_rrblup_output :Private{
    my ($self, $c) = @_;
    
    my $pop_id      = $c->stash->{pop_id};
    my $trait_abbr  = $c->stash->{trait_abbr};
    my $trait_name  = $c->stash->{trait_name};

    my ($traits_file, @traits, @trait_pages);
    my $prediction_id = $c->stash->{prediction_pop_id};
   
    if ($trait_name)     
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
           
           my $trait_id = $c->model('solGS')->get_trait_id($c, $trait_name);
           push @trait_pages, [ qq | <a href="/trait/$trait_id/population/$pop_id" onclick="solGS.waitPage()">$tr</a>| ];
       }    
    }

    if (scalar(@traits) == 1) 
    {
        $self->gs_files($c);
        $c->stash->{template} = 'population/trait.mas';
    }
    
    if (scalar(@traits) > 1)    
    {
       
        $self->analyzed_traits($c);
        $c->stash->{template}    = '/population/multiple_traits_output.mas'; 
        $c->stash->{trait_pages} = \@trait_pages;
    }

}

sub run_rrblup_trait {
    my ($self, $c, $trait_abbr) = @_;
    
    my $pop_id     = $c->stash->{pop_id};
    my $trait_name = $c->stash->{trait_name};
    my $trait_abbr = $c->stash->{trait_abbr};

    my $trait_id = $c->model('solGS')->get_trait_id($c, $trait_name);
    $c->stash->{trait_id}   = $trait_id ; 
                                
    my ($fh, $file) = tempfile("trait_${trait_id}_pop_${pop_id}-XXXXX", 
                               DIR => $c->stash->{solgs_tempfiles_dir}
        );
        
    $fh->close;   

    $c->stash->{trait_file} = $file;       
    write_file($file, $trait_abbr);

    my $pred_id = $c->stash->{prediction_pop_id};

    $self->output_files($c);

    if ($c->stash->{prediction_pop_id})
    {       
        $self->input_files($c);            
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
            $self->input_files($c);            
            $self->output_files($c);
            $self->run_rrblup($c); 
       
        }
    }
}

sub run_rrblup  {
    my ($self, $c) = @_;
   
    #get all input files & arguments for rrblup, 
    #run rrblup and save output in solgs user dir
    my $pop_id       = $c->stash->{pop_id};
    my $trait_id     = $c->stash->{trait_id};
    my $input_files  = $c->stash->{input_files};
    my $output_files = $c->stash->{output_files};
    
    die "\nCan't run rrblup without a trait id." if !$trait_id;
    die "\nCan't run rrblup without a population id." if !$pop_id;
    die "\nCan't run rrblup without input files." if !$input_files;
    die "\nCan't run rrblup without output files." if !$output_files;    
    
    $c->stash->{r_temp_file} = "gs-rrblup-${trait_id}-${pop_id}";
    $c->stash->{r_script}    = 'R/gs.r';
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
       
        
        $c->throw(is_client_error   => 1,
                  title             => "$r_script Script Error",
                  public_message    => "There is a problem running $r_script on this dataset!",	     
                  notify            => 1, 
                  developer_message => $err,
            );
    }

}
  
sub get_solgs_dirs {
    my ($self, $c) = @_;
   
    my $solgs_dir       = $c->config->{solgs_dir};
    my $solgs_cache     = catdir($solgs_dir, 'cache'); 
    my $solgs_tempfiles = catdir($solgs_dir, 'tempfiles');
  
    mkpath ([$solgs_dir, $solgs_cache, $solgs_tempfiles], 0, 0755);
   
    $c->stash(solgs_dir           => $solgs_dir, 
              solgs_cache_dir     => $solgs_cache, 
              solgs_tempfiles_dir => $solgs_tempfiles
        );

}

sub cache_file {
    my ($self, $c, $cache_data) = @_;
    
    my $solgs_cache = $c->stash->{solgs_cache_dir};
    my $file_cache  = Cache::File->new(cache_root => $solgs_cache);
    $file_cache->purge();

    my $file  = $file_cache->get($cache_data->{key});

    unless ($file)
    {      
        $file = catfile($solgs_cache, $cache_data->{file});
        write_file($file);
        $file_cache->set($cache_data->{key}, $file, '30 days');
    }

    $c->stash->{$cache_data->{stash_key}} = $file;
}

sub default :Path {
    my ( $self, $c ) = @_; 
    $c->forward('search');
}



=head2 end

Attempt to render a view, if needed.

=cut

sub render : ActionClass('RenderView') {}


sub end : Private {
    my ( $self, $c ) = @_;

    return if @{$c->error};

    # don't try to render a default view if this was handled by a CGI
    $c->forward('render') unless $c->req->path =~ /\.pl$/;

    # enforce a default text/html content type regardless of whether
    # we tried to render a default view
    $c->res->content_type('text/html') unless $c->res->content_type;

    # insert our javascript packages into the rendered view
    if( $c->res->content_type eq 'text/html' ) {
        $c->forward('/js/insert_js_pack_html');
        $c->res->headers->push_header('Vary', 'Cookie');
    } else {
        $c->log->debug("skipping JS pack insertion for page with content type ".$c->res->content_type)
            if $c->debug;
    }

}

=head2 auto

Run for every request to the site.

=cut

sub auto : Private {
    my ($self, $c) = @_;
    CatalystX::GlobalContext->set_context( $c );
    $c->stash->{c} = $c;
    weaken $c->stash->{c};

    $self->get_solgs_dirs($c);
    # gluecode for logins
    #
#  #   unless( $c->config->{'disable_login'} ) {
   #      my $dbh = $c->dbc->dbh;
   #      if ( my $sp_person_id = CXGN::Login->new( $dbh )->has_session ) {

   #          my $sp_person = CXGN::People::Person->new( $dbh, $sp_person_id);

   #          $c->authenticate({
   #              username => $sp_person->get_username(),
   #              password => $sp_person->get_password(),
   #          });
   #      }
   # }

    return 1;
}




=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
