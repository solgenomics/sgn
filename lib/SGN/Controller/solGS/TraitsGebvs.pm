package SGN::Controller::solGS::TraitsGebvs;

use Moose;
use namespace::autoclean;

use Array::Utils qw(:all);
use Cache::File;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use JSON;
use List::MoreUtils qw /uniq/;
use String::CRC;
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
    
    my $training_pop_id = $c->stash->{training_pop_id} || $c->stash->{combo_pops_id} || $c->stash->{corre_pop_id};
    $c->stash->{model_id} = $training_pop_id;
    my $selection_pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    
    my $dir = $c->stash->{solgs_cache_dir};
 
    my $gebv_files;
    my $valid_gebv_files;
     
    if ($selection_pop_id) 
    {
        $c->controller('solGS::solGS')->prediction_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
	$gebv_files = join("\t", @{$c->stash->{prediction_pop_analyzed_traits_files}});	
    } 
    else
    {
        $c->controller('solGS::solGS')->analyzed_traits($c);
	$gebv_files = join("\t", @{$c->stash->{analyzed_traits_files}});     
	$valid_gebv_files = join("\t", @{$c->stash->{analyzed_valid_traits_files}}); 
    }
 
    my $pred_file_suffix =  $selection_pop_id ? '_' . $selection_pop_id : 0;    
    my $name = "gebv_files_of_traits_${training_pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
   
    write_file($file, $gebv_files);   
    $c->stash->{gebv_files_of_traits} = $file;

    my $name2 = "gebv_files_of_valid_traits_${training_pop_id}${pred_file_suffix}";
    my $file2 = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name2);
   
    write_file($file2, $valid_gebv_files);
   
    $c->stash->{gebv_files_of_valid_traits} = $file2;

}


sub traits_selection_catalogue_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'traits_selection_catalogue_file',
                      file      => 'traits_selection_catalogue_file.txt',
                      stash_key => 'traits_selection_catalogue_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub catalogue_traits_selection {
    my ($self, $c, $traits_ids) = @_;
  
    $self->traits_selection_catalogue_file($c);
    my $file = $c->stash->{traits_selection_catalogue_file};

    my $traits_selection_id = $self->create_traits_selection_id($traits_ids);	    
    my $ids = join(',', @$traits_ids);
    my $entry = $traits_selection_id . "\t" . $ids;
	 
    if (!-s $file) 
    {
        my $header = 'traits_selection_id' . "\t" . 'traits_ids' . "\n";
        write_file($file, ($header, $entry));    
    }
    else 
    {
	my @combo = ($entry);

        my @entries = map{ $_ =~ s/\n// ? $_ : undef } read_file($file);
        my @intersect = intersect(@combo, @entries);

        unless( @intersect ) 
        {
            write_file($file, {append => 1}, "\n" . $entry);
        }
    }
    
}


sub get_traits_selection_list {
    my ($self, $c, $id) = @_;

    $id = $c->stash->{traits_selection_id} if !$id;
    
    $self->traits_selection_catalogue_file($c);
    my $traits_selection_catalogue_file = $c->stash->{traits_selection_catalogue_file};
   
    my @combos = uniq(read_file($traits_selection_catalogue_file));
    
    foreach my $entry (@combos)
    {
        if ($entry =~ m/$id/)
        {
	    chomp($entry);
            my ($traits_selection_id, $traits)  = split(/\t/, $entry);

	    if ($id == $traits_selection_id)
	    {
		my @traits_list = split(',', $traits);
		$c->stash->{traits_selection_list} = \@traits_list;
	    }
        }   
    }     

}


sub get_traits_selection_id :Path('/solgs/get/traits/selection/id') Args(0) {
    my ($self, $c) = @_;
    
    my @traits_ids = $c->req->param('trait_ids[]');
   
    my $ret->{status} = 0;

    if (@traits_ids > 1) 
    {
	$self->catalogue_traits_selection($c, \@traits_ids);
	
	my $traits_selection_id = $self->create_traits_selection_id(\@traits_ids);
	$ret->{traits_selection_id} = $traits_selection_id;
	$ret->{status} = 1;
    }

    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub create_traits_selection_id {
    my ($self, $traits_ids) = @_;
    
    if ($traits_ids)
    {
	return  crc(join('', @$traits_ids));
    }
    else
    {
	return 0;
    }
}

	

#####


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



####
1;
####
