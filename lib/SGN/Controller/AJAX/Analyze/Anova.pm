=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 Name

SGN::Controller::AJAX::Analyze::Anova - a controller for ANOVA. For now, this implements a one-way
single trial ANOVA with a possibility for simultanously running anova for multiple traits.
 
=cut


package SGN::Controller::AJAX::Analyze::Anova;

use Moose;
use namespace::autoclean;

use File::Slurp qw /write_file read_file/;
use JSON;
use CXGN::Trial;
use File::Copy;
use File::Basename;
use File::Spec::Functions;
use File::Path qw / mkpath  /;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller::REST' }



__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 
		   'text/html' => 'JSON' },
    );


sub anova_traits_list :Path('/anova/traits/list/') Args(0) {
    my ($self, $c) = @_;
   
    my $trial_id = $c->req->param('trial_id');
    
    $c->stash->{trial_id} = $trial_id;
    $self->anova_traits($c);
    
}


sub anova_phenotype_data :Path('/anova/phenotype/data/') Args(0) {
    my ($self, $c) = @_;
   
    my $trial_id = $c->req->param('trial_id');
    my @traits_ids   = $c->req->param('traits_ids[]');
    
    $c->stash->{rest}{trial_id} = $trial_id;

    $c->stash->{trial_id} = $trial_id;
    $c->stash->{traits_ids} = \@traits_ids;  

    $self->create_anova_phenodata_file($c);
    $self->check_trial_design($c);
    $self->get_traits_abbrs($c);
   
}


sub anova_traits {
     my ($self, $c) = @_;

     my $trial_id = $c->stash->{trial_id};

     my $trial = CXGN::Trial->new(bcs_schema => $self->schema($c), 
				  trial_id => $trial_id);

     my $traits = $trial->get_traits_assayed();
     my $clean_traits = $self->remove_ontology($traits);

     $c->stash->{rest}{anova_traits} = $clean_traits;

}


sub remove_ontology {
    my ($self, $traits) = @_;

    my @clean_traits;

    foreach my $tr (@$traits) {
	my $name = $tr->[1];
	$name =~ s/\|CO_\d+:\d+//;

	my $id_nm = {'trait_id' => $tr->[0], 'trait_name' => $name};
 	push @clean_traits, $id_nm;	    	    
    }

    return \@clean_traits;

}


sub create_anova_phenodata_file {
    my ($self, $c)  = @_;
        
    $self->anova_pheno_file($c);
    my $pheno_file =  $c->stash->{phenotype_file};

    if (!-s $pheno_file) {
	$c->stash->{rest}{'Error'} = 'There is no phenotype data for this  trial.';
    } else {
	$c->stash->{rest}{'success'} = 'Success.';	
    }

    if (@{$c->error}) {
	$c->stash->{rest}{'Error'} = 'There was error querying for the phenotype data.';
    }
        
}


sub check_trial_design {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    
    my $trial = CXGN::Trial->new(bcs_schema => $self->schema($c), 
				 trial_id => $trial_id);

    my $design = $trial->get_design_type();

    $c->stash->{pop_id} = $trial_id;    
    $c->controller("solGS::solGS")->all_traits_file($c);
    my $traits_file = $c->stash->{all_traits_file};
    my @traits = read_file($traits_file);

    if (!$design) {
	$c->stash->{rest}{'Error'} = 'This trial has no suitable trial design to do the ANOVA analysis.'; 
    }
    
}


sub get_traits_abbrs {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $traits_ids = $c->stash->{traits_ids};

    $c->stash->{pop_id} = $trial_id;    
    $c->controller("solGS::solGS")->all_traits_file($c);
    my $traits_file = $c->stash->{all_traits_file};
    my @traits = read_file($traits_file);
   
    my @traits_abbrs;

    foreach my $id (@$traits_ids) {
	my ($tr) = grep(/$id/, @traits);
	chomp($tr);
	my $abbr = (split('\t', $tr))[2] if $tr;
	my $id_abbr = {'trait_id' => $id, 'trait_abbr' => $abbr};
	push @traits_abbrs, $id_abbr;	    	    
    }

   $c->stash->{rest}{traits_abbrs} = \@traits_abbrs;    

}


sub anova_analyis :Path('/anova/analysis/') Args(0) {
    my ($self, $c) = @_;

    my $trial_id = $c->req->param('trial_id');
    my $traits   = $c->req->param('traits[]');
    
    $c->stash->{trial_id} = $trial_id;

    my $json = JSON->new();
    $traits  = $json->decode($traits);

    foreach my $tr (@$traits) 
    {
	foreach my $k (keys $tr) 
	{
	    $c->stash->{$k} = $tr->{$k};	   
	}
	
	unless ($self->check_anova_output($c)) 
	{
	    $self->run_anova($c);
	    $self->check_anova_output($c);
		
	}
    }    
}


sub check_anova_output {
    my ($self, $c) = @_;
    
    $self->anova_table_file($c);
    my $html_file = $c->stash->{anova_table_html_file};
   
    if (-s $html_file) {

	my $html_table = read_file($html_file);

	$self->prep_download_files($c);
	my $anova_table_file = $c->stash->{download_anova};
	my $model_file = $c->stash->{download_model};
	my $means_file = $c->stash->{download_means};
       
	$c->stash->{rest}{anova_html_table} = $html_table;
	$c->stash->{rest}{anova_table_file} = $anova_table_file;
	$c->stash->{rest}{anova_model_file} = $model_file;
	$c->stash->{rest}{adj_means_file}   = $means_file;

	return 1;

    } else {
	return 0;
    }
    
}


sub prep_download_files {
  my ($self, $c) = @_; 
  
  my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'anova');
  my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);
   
  mkpath ([$base_tmp_dir], 0, 0755);  

  $self->anova_table_file($c);
  my $anova_txt_file  = $c->stash->{anova_table_txt_file};
  my $anova_html_file = $c->stash->{anova_table_html_file};

  $self->anova_model_file($c);
  my $model_file = $c->stash->{anova_model_file};

  $self->adj_means_file($c);    
  my $means_file = $c->stash->{adj_means_file};
  
  copy($anova_txt_file, $base_tmp_dir)  
            or die "could not copy $anova_txt_file to $base_tmp_dir";

  copy($model_file, $base_tmp_dir)  
            or die "could not copy $model_file to $base_tmp_dir";
  
  copy($means_file, $base_tmp_dir)  
            or die "could not copy $means_file to $base_tmp_dir";

  $anova_txt_file = fileparse($anova_txt_file);
  $anova_txt_file = catfile($tmp_dir, $anova_txt_file);

  $model_file = fileparse($model_file);
  $model_file = catfile($tmp_dir, $model_file);

  $means_file = fileparse($means_file);
  $means_file = catfile($tmp_dir, $means_file);
  
  $c->stash->{download_anova} = $anova_txt_file;
  $c->stash->{download_model} = $model_file;
  $c->stash->{download_means} = $means_file;

}


sub run_anova {
    my ($self, $c) = @_;
    
    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};
   
    $self->anova_input_files($c);
    my $input_file = $c->stash->{anova_input_files};

    $self->anova_output_files($c);
    my $output_file = $c->stash->{anova_output_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{anova_temp_dir};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "anova-${trial_id}-${trait_id}";
    $c->stash->{r_script}     = 'R/anova.r';

    $c->controller("solGS::solGS")->run_r_script($c);
    
}


sub anova_input_files {
    my ($self, $c) = @_;
 
    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};   
    
    $self->anova_pheno_file($c);
    my $pheno_file = $c->stash->{phenotype_file};

    $self->anova_traits_file($c);   
    my $traits_file = $c->stash->{anova_traits_file};

    my $file_list = join ("\t",
                          $pheno_file,
                          $traits_file,
	);
     
    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name = "anova_input_files_${trial_id}_${trait_id}"; 
    my $tempfile =  $c->controller("solGS::solGS")->create_tempfile($tmp_dir, $name); 
    write_file($tempfile, $file_list);
    
    $c->stash->{anova_input_files} = $tempfile;

}


sub anova_pheno_file {
    my ($self, $c) = @_;
    
    $c->stash->{pop_id} = $c->stash->{trial_id};

    $c->controller('solGS::solGS')->phenotype_file($c);
   
}


sub anova_traits_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};   
    my $traits   = $c->stash->{trait_abbr};

    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name    = "anova_traits_file_${trial_id}"; 
    my $traits_file =  $c->controller("solGS::solGS")->create_tempfile($tmp_dir, $name); 
    write_file($traits_file, $traits);

    $c->stash->{anova_traits_file} = $traits_file;
    
}


sub anova_output_files {
    my ($self, $c) = @_;
 
    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};   
    
    $self->anova_table_file($c);
    $self->anova_model_file($c);
    $self->adj_means_file($c);

    my @files = $c->stash->{anova_table_file};

    my $file_list = join ("\t",
                          $c->stash->{anova_model_file},
                          $c->stash->{anova_table_html_file},
			  $c->stash->{anova_table_txt_file},
			  $c->stash->{adj_means_file},
	);
     
    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name = "anova_output_files_${trial_id}_${trait_id}"; 
    my $tempfile =  $c->controller("solGS::solGS")->create_tempfile($tmp_dir, $name); 
    write_file($tempfile, $file_list);
    
    $c->stash->{anova_output_files} = $tempfile;

}


sub anova_table_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};
    
    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    my $cache_data = {key       => "anova_table_${trial_id}_${trait_id}_html",
                      file      => "anova_table_${trial_id}_${trait_id}.html",
                      stash_key => "anova_table_html_file"
    };

    $c->controller("solGS::solGS")->cache_file($c, $cache_data);

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    $cache_data = {key       => "anova_table_${trial_id}_${trait_id}_txt",
		   file      => "anova_table_${trial_id}_${trait_id}.txt",
		   stash_key => "anova_table_txt_file"
    };

    $c->controller("solGS::solGS")->cache_file($c, $cache_data);

}


sub anova_model_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};
    
    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};;

    my $cache_data = {key       => "anova_model_${trial_id}_${trait_id}",
                      file      => "anova_model_${trial_id}_${trait_id}.txt",
                      stash_key => "anova_model_file"
    };

    $c->controller("solGS::solGS")->cache_file($c, $cache_data);

}


sub adj_means_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};
    
    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};;

    my $cache_data = {key       => "adj_means_${trial_id}_${trait_id}",
                      file      => "adj_means_${trial_id}_${trait_id}.txt",
                      stash_key => "adj_means_file"
    };

    $c->controller("solGS::solGS")->cache_file($c, $cache_data);

}


sub schema {
    my ($self, $c) = @_;

    return $c->dbic_schema("Bio::Chado::Schema");

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

1;

