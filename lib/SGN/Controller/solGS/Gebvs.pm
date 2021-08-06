package SGN::Controller::solGS::Gebvs;

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
use Scalar::Util qw /weaken reftype/;
use String::CRC;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller' }



sub gebvs_data :Path('/solgs/trait/gebvs/data') Args(0) {
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
    $c->stash->{selectiion_pop_id} = $selection_pop_id;
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);

    my $gebvs_file;
    my $page = $c->req->referer();

    if ($page =~ /solgs\/selection\//)
    {
        $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
        $gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
    }
    else
    {
        $c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
        $gebvs_file = $c->stash->{rrblup_training_gebvs_file};
    }

    my $gebvs_data = $c->controller("solGS::Utils")->read_file_data($gebvs_file);

    my $ret->{status} = 'failed';

    if (@$gebvs_data)
    {
        $ret->{status} = 'success';
        $ret->{gebvs_data} = $gebvs_data;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

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


sub combine_gebvs_jobs_args {
    my ($self, $c) = @_;

    $self->get_gebv_files_of_traits($c);
    my $gebvs_files = $c->stash->{gebv_files_of_valid_traits};

    if (!-s $gebvs_files)
    {
	       $gebvs_files = $c->stash->{gebv_files_of_traits};
    }

    my $index_file  = $c->stash->{selection_index_file};

    my @files_no = map { split(/\t/) } read_file($gebvs_files, {binmode => ':utf8'});

    if (scalar(@files_no) > 1 )
    {
        if ($index_file)
        {
            write_file($gebvs_files, {append => 1, binmode => ':utf8'}, "\t". $index_file)
        }

	my $identifier = $self->combined_gebvs_file_id($c);
    print STDERR "\ncombined_gebvs_file_id: $identifier\n";
	my $tmp_dir = $c->stash->{solgs_tempfiles_dir};

        #my $combined_gebvs_file = $c->controller('solGS::Files')->create_tempfile($tmp_dir, "combined_gebvs_${identifier}");
        $self->combined_gebvs_file($c);
        my  $combined_gebvs_file = $c->stash->{combined_gebvs_file};
        print STDERR "\ncombined_gebvs_file --  $combined_gebvs_file\n";
        $c->stash->{input_files}  = $gebvs_files;
        $c->stash->{output_files} = $combined_gebvs_file;
        $c->stash->{r_temp_file}  = "combining-gebvs-${identifier}";
        $c->stash->{r_script}     = 'R/solGS/combine_gebvs_files.r';
	$c->stash->{analysis_tempfiles_dir} = $tmp_dir;
    }
    else
    {
        $c->stash->{combined_gebvs_files} = 0;
    }

}


sub combined_gebvs_file_id {
    my ($self, $c) = @_;

    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $training_pop_id    = $c->stash->{training_pop_id};
    my $traits_code = $c->stash->{training_traits_code};

    my $file_id  =  $selection_pop_id ? "${training_pop_id}-${selection_pop_id}-${traits_code}"  :  "${training_pop_id}-${traits_code}";

    return $file_id;

}


sub combined_gebvs_file {
    my ($self, $c) = @_;

    my $identifier = $self->combined_gebvs_file_id($c);

    my $cache_data = {
           key => "combined_gebvs_${identifier}",
           file      => "combined_gebvs_${identifier}" . '.txt',
           stash_key => 'combined_gebvs_file',
		   cache_dir => $c->stash->{solgs_cache_dir}
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub combine_gebvs_jobs {
    my ($self, $c) = @_;

    $self->combine_gebvs_jobs_args($c);

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
    $jobs = [$jobs];
    }

    $c->stash->{combine_gebvs_jobs} = $jobs;

}

sub run_combine_traits_gebvs {
    my ($self, $c) = @_;

    $self->combine_gebvs_jobs_args($c);
    $c->controller("solGS::AsyncJob")->run_r_script($c);

}

#creates and writes a list of GEBV files of
#traits selected for ranking genotypes.
sub get_gebv_files_of_traits {
    my ($self, $c) = @_;

    my $training_pop_id = $c->stash->{training_pop_id} || $c->stash->{combo_pops_id} || $c->stash->{corre_pop_id};
    $c->stash->{model_id} = $training_pop_id;
    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $dir = $c->stash->{solgs_cache_dir};

    my $gebv_files;
    my $valid_gebv_files;

    if ($selection_pop_id)
    {
        $self->selection_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
	$gebv_files = join("\t", @{$c->stash->{selection_pop_analyzed_traits_files}});
    }
    else
    {
       $self->training_pop_analyzed_traits($c);
	$gebv_files = join("\t", @{$c->stash->{training_pop_analyzed_traits_files}});
	$valid_gebv_files = join("\t", @{$c->stash->{training_pop_analyzed_valid_traits_files}});
    }

    my $pred_file_suffix =   '_' . $selection_pop_id if $selection_pop_id;
    my $name = "gebv_files_of_traits_${training_pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);

    write_file($file, {binmode => ':utf8'}, $gebv_files);
    $c->stash->{gebv_files_of_traits} = $file;

    my $name2 = "gebv_files_of_valid_traits_${training_pop_id}${pred_file_suffix}";
    my $file2 = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name2);

    write_file($file2, {binmode => ':utf8'}, $valid_gebv_files);

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
        write_file($file, {binmode => ':utf8'}, ($header, $entry));
    }
    else
    {
	my @combo = ($entry);

        my @entries = map{ $_ =~ s/\n// ? $_ : undef } read_file($file, {binmode => ':utf8'});
        my @intersect = intersect(@combo, @entries);

        unless( @intersect )
        {
            write_file($file, {append => 1, binmode => ':utf8'}, "\n" . $entry);
        }
    }

}


sub get_traits_selection_list {
    my ($self, $c, $id) = @_;

    $id = $c->stash->{traits_selection_id} if !$id;

    $self->traits_selection_catalogue_file($c);
    my $traits_selection_catalogue_file = $c->stash->{traits_selection_catalogue_file};

    my @combos = uniq(read_file($traits_selection_catalogue_file, {binmode => ':utf8'}));

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


sub create_traits_selection_id {
    my ($self, $traits_ids) = @_;

    if ($traits_ids)
    {
	return  crc(join('', sort(uniq(@$traits_ids))));
    }
    else
    {
	return 0;
    }

}


sub training_pop_analyzed_traits {
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
	    $c->controller('solGS::solGS')->get_trait_details($c);
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
print STDERR "\nanalyzed_traits_files -- @analyzed_traits_files\n";
    $c->stash->{training_pop_analyzed_traits}        = \@traits;
    $c->stash->{training_pop_analyzed_traits_ids}    = \@selected_analyzed_traits;
    $c->stash->{training_pop_analyzed_traits_files}  = \@analyzed_traits_files;
    $c->stash->{selection_index_traits} = \@si_traits;
    $c->stash->{training_pop_analyzed_valid_traits_files}  = \@valid_traits_files;
}


sub selection_pop_analyzed_traits {
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

	foreach my $trait_id (@selected_analyzed_traits)
	{
	    $c->stash->{trait_id} = $trait_id;
	    $c->controller('solGS::solGS')->get_trait_details($c);
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

    $c->stash->{selection_pop_analyzed_traits}       = \@trait_abbrs;
    $c->stash->{selection_pop_analyzed_traits_ids}   = \@trait_ids;
    $c->stash->{selection_pop_analyzed_traits_files} = \@files;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



####
1;
####
