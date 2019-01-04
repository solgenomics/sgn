package SGN::Controller::solGS::TraitsGebvs;

use Moose;
use namespace::autoclean;

use Cache::File;

use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;

use JSON;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller' }





sub combine_gebvs_of_traits {
    my ($self, $c) = @_;

    $self->get_gebv_files_of_traits($c);  
    my $gebvs_files = $c->stash->{gebv_files_of_valid_traits};

    if (!-s $gebvs_files) 
    {
	$gebvs_files = $c->stash->{gebv_files_of_traits};
    }
   
    my $index_file  = $c->stash->{selection_index_file};

    my @files_no = map { split(/\t/) } read_file($gebvs_files);

    if (scalar(@files_no) > 1 ) 
    {    
        if ($index_file) 
        {
            write_file($gebvs_files, {append => 1}, "\t". $index_file )   
        }

        my $pred_pop_id = $c->stash->{prediction_pop_id};
        my $model_id    = $c->stash->{model_id};
        my $identifier  =  $pred_pop_id ? $model_id . "_" . $pred_pop_id :  $model_id; 

	my $tmp_dir = $c->stash->{solgs_tempfiles_dir};
        my $combined_gebvs_file = $c->controller('solGS::Files')->create_tempfile($tmp_dir, "combined_gebvs_${identifier}"); 
  
        $c->stash->{input_files}  = $gebvs_files;
        $c->stash->{output_files} = $combined_gebvs_file;
        $c->stash->{r_temp_file}  = "combining-gebvs-${identifier}";
        $c->stash->{r_script}     = 'R/solGS/combine_gebvs_files.r';
	$c->stash->{analysis_tempfiles_dir} = $tmp_dir;
	
        $c->controller("solGS::solGS")->run_r_script($c);
	$c->stash->{combined_gebvs_file} = $combined_gebvs_file;
    }
    else 
    {
        $c->stash->{combined_gebvs_files} = 0;           
    }
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
        $c->controller('solGS::solGS')->prediction_pop_analyzed_traits($c, $pop_id, $pred_pop_id);
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
        $c->controller('solGS::solGS')->analyzed_traits($c);
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
    my $file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
   
    write_file($file, $gebv_files);
   
    $c->stash->{gebv_files_of_traits} = $file;

    my $name2 = "gebv_files_of_valid_traits_${pop_id}${pred_file_suffix}";
    my $file2 = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name2);
   
    write_file($file2, $valid_gebv_files);
   
    $c->stash->{gebv_files_of_valid_traits} = $file2;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



####
1;
####
