=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 DESCRIPTION

SGN::Controller::solGS::geneticGain- Controller for comparing GEBVs of training and selection populations

=cut


package SGN::Controller::solGS::geneticGain;

use Moose;
use namespace::autoclean;


use File::Copy;
use File::Basename;
use File::Path qw / mkpath  /;
use File::Spec::Functions;
use File::Slurp qw /write_file read_file/;
use JSON;
use List::MoreUtils qw /uniq/;
use String::CRC;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller' }



sub get_training_pop_gebvs :Path('/solgs/get/gebvs/training/population/') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{training_pop_id} = $c->req->param('training_pop_id');
    $c->stash->{trait_id}        = $c->req->param('trait_id');
    $c->stash->{population_type} = 'training_population';

    my $protocol_id = $c->req->param('genotyping_protocol_id');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    my $ret->{gebv_exists} = undef;

    $self->get_training_pop_gebv_file($c);
    my $gebv_file = $c->stash->{training_gebv_file};

    if (-s $gebv_file)
    {
	$c->stash->{gebv_file} = $gebv_file;
	$self->get_gebv_arrayref($c);
	my $gebv_arrayref = $c->stash->{gebv_arrayref};

	$ret->{gebv_exists} = 1;
	$ret->{gebv_arrayref} = $gebv_arrayref;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_selection_pop_gebvs :Path('/solgs/get/gebvs/selection/population/') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{selection_pop_id} = $c->req->param('selection_pop_id');
    $c->stash->{training_pop_id}  = $c->req->param('training_pop_id');
    $c->stash->{trait_id}         = $c->req->param('trait_id');
    $c->stash->{population_type}  = 'selection_population';

    my $protocol_id = $c->req->param('genotyping_protocol_id');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    my $ret->{gebv_exists} = undef;

    $self->get_selection_pop_gebv_file($c);
    my $gebv_file = $c->stash->{selection_gebv_file};

    if (-s $gebv_file)
    {
	$c->stash->{gebv_file} = $gebv_file;
	$self->get_gebv_arrayref($c);
	my $gebv_arrayref = $c->stash->{gebv_arrayref};

	$ret->{gebv_exists} = 1;
	$ret->{gebv_arrayref} = $gebv_arrayref;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub genetic_gain_boxplot :Path('/solgs/genetic/gain/boxplot/') Args(0) {
    my ($self, $c) = @_;

    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $training_pop_id  = $c->req->param('training_pop_id');
    my $trait_id         = $c->req->param('trait_id');
    my @selection_pop_traits = $c->req->param('training_traits_ids[]');
    my $protocol_id = $c->req->param('genotyping_protocol_id');

    $c->stash->{selection_pop_id} = $selection_pop_id;
    $c->stash->{training_pop_id}  = $training_pop_id;
    $c->stash->{trait_id}         = $trait_id;

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    if (@selection_pop_traits)
    {
	$c->stash->{training_traits_ids} =  \@selection_pop_traits;
    }
    else
    {
	$c->stash->{training_traits_ids} = [$trait_id];
    }

    my $ret->{boxplot} = undef;

    my $result = $self->check_genetic_gain_output($c);

    if (!$result)
    {
	$self->run_boxplot($c);
    }

    $self->boxplot_download_files($c);

    $ret->{boxplot} = $c->stash->{download_boxplot};
    $ret->{boxplot_data} = $c->stash->{download_data};
    $ret->{Error} = undef;

    $ret = to_json($ret);
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub check_genetic_gain_output {
    my ($self, $c) = @_;

    $self->boxplot_file($c);
    my $boxplot = $c->stash->{boxplot_file};

    $self->boxplot_download_files($c);
    my $dld_plot = $c->stash->{download_boxplot};

    if (-s $boxplot && $dld_plot)
    {
	return 1;
    }
    else
    {
	return 0;
    }

}

sub get_training_pop_gebv_file {
    my ($self, $c) = @_;

    my $pop_id   = $c->stash->{training_pop_id};
    my $trait_id = $c->stash->{trait_id};

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    my $gebv_file;

    if ($pop_id && $trait_id)
    {
	$c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
	$gebv_file = $c->stash->{rrblup_training_gebvs_file};
    }

    $c->stash->{training_gebv_file} = $gebv_file;

}


sub get_selection_pop_gebv_file {
    my ($self, $c) = @_;

    my $selection_pop_id   = $c->stash->{selection_pop_id};
    my $training_pop_id    = $c->stash->{training_pop_id};
    my $trait_id           = $c->stash->{trait_id};

    my $gebv_file;

    if ($selection_pop_id && $trait_id && $training_pop_id)
    {
	# my $identifier = "${training_pop_id}_${selection_pop_id}";
	$c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
	$gebv_file = $c->stash->{rrblup_selection_gebvs_file};
    }

    $c->stash->{selection_gebv_file} = $gebv_file;

}


sub boxplot_id {
    my ($self, $c) = @_;

    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $training_pop_id  = $c->stash->{training_pop_id};
    my $trait_id         = $c->stash->{trait_id};
    my $protocol_id      = $c->stash->{genotyping_protocol_id};

    my $multi_traits = $c->stash->{training_traits_ids};
    if (scalar(@$multi_traits) > 1) {

	$trait_id = crc(join('', @$multi_traits));
    }

    $c->stash->{boxplot_id} = "${training_pop_id}_${selection_pop_id}_${trait_id}-${protocol_id}";

}


sub get_gebv_arrayref {
    my ($self, $c) = @_;

    my $file = $c->stash->{gebv_file};
    $c->stash->{gebv_arrayref} = $c->controller('solGS::Utils')->read_file_data($file);
}


sub check_population_type {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{population_type} = $c->model('solGS::solGS')->get_population_type($pop_id);
}


sub boxplot_file {
    my ($self, $c) = @_;

    $self->boxplot_id($c);
    my $boxplot_id = $c->stash->{boxplot_id};

    my $cache_data = {key       => "boxplot_${boxplot_id}",
                      file      => "genetic_gain_plot_${boxplot_id}.png",
                      stash_key => "boxplot_file",
		      cache_dir => $c->stash->{solgs_cache_dir},
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub boxplot_data_file {
    my ($self, $c) = @_;

    $self->boxplot_id($c);
    my $boxplot_id = $c->stash->{boxplot_id};

    my $cache_data = {key       => "boxplot_data_${boxplot_id}",
                      file      => "genetic_gain_data_${boxplot_id}.txt",
                      stash_key => "boxplot_data_file",
		      cache_dir => $c->stash->{solgs_cache_dir},
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub boxplot_input_files {
    my ($self, $c) = @_;

    my @files_list;

    foreach my $trait_id (uniq(@{$c->stash->{training_traits_ids}}))
    {
	$c->stash->{trait_id} = $trait_id;
	$self->get_training_pop_gebv_file($c);
	my $training_gebv = $c->stash->{training_gebv_file};

	$self->get_selection_pop_gebv_file($c);
	my $sel_gebv = $c->stash->{selection_gebv_file};

	push @files_list, $training_gebv, $sel_gebv;
    }

    my $files = join("\t", @files_list);

    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};

    $self->boxplot_id($c);
    my $boxplot_id = $c->stash->{boxplot_id};
    my $name = "boxplot_input_files_${boxplot_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files, );

    $c->stash->{boxplot_input_files} = $tempfile;

}


sub boxplot_output_files {
    my ($self, $c) = @_;

    $self->boxplot_file($c);
    my $boxplot_file = $c->stash->{boxplot_file};

    $self->boxplot_error_file($c);
    my $error_file = $c->stash->{boxplot_error_file};

    $self->boxplot_data_file($c);
    my $data_file = $c->stash->{boxplot_data_file};

    my $file_list = join ("\t",
                          $boxplot_file,
                          $error_file,
			  $data_file,
	);

    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};

    $self->boxplot_id($c);
    my $boxplot_id = $c->stash->{boxplot_id};

    my $name = "boxplot_output_files_${boxplot_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $file_list);

    $c->stash->{boxplot_output_files} = $tempfile;

}


sub boxplot_error_file {
    my ($self, $c) = @_;

    $self->boxplot_id($c);
    my $boxplot_id = $c->stash->{boxplot_id};

    $c->stash->{file_id} = $boxplot_id;
    $c->stash->{cache_dir} = $c->stash->{solgs_cache_dir};
    $c->stash->{analysis_type} = 'boxplot';

    $c->controller('solGS::Files')->analysis_error_file($c);

}

sub run_boxplot {
    my ($self, $c) = @_;

    $self->boxplot_input_files($c);
    my $input_file = $c->stash->{boxplot_input_files};

    $self->boxplot_output_files($c);
    my $output_file = $c->stash->{boxplot_output_files};

    $self->boxplot_id($c);
    my $boxplot_id = $c->stash->{boxplot_id};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{solgs_tempfiles_dir};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "boxplot-${boxplot_id}";
    $c->stash->{r_script}     = 'R/solGS/genetic_gain.r';

    $c->controller("solGS::AsyncJob")->run_r_script($c);

}


sub boxplot_download_files {
  my ($self, $c) = @_;

  my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'genetic_gain');
  my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);

  mkpath ([$base_tmp_dir], 0, 0755);

  $self->boxplot_file($c);
  my $boxplot_file  = $c->stash->{boxplot_file};

  $self->boxplot_error_file($c);
  my $error_file = $c->stash->{boxplot_error_file};

  $self->boxplot_data_file($c);
  my $data_file = $c->stash->{boxplot_data_file};

  $c->controller('solGS::Files')->copy_file($boxplot_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($error_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($data_file, $base_tmp_dir);

  $boxplot_file = fileparse($boxplot_file);
  $boxplot_file = catfile($tmp_dir, $boxplot_file);

  $error_file = fileparse($error_file);
  $error_file = catfile($tmp_dir, $error_file);

  $data_file = fileparse($data_file);
  $data_file = catfile($tmp_dir, $data_file);

  $c->stash->{download_boxplot} = $boxplot_file;
  $c->stash->{download_error}   = $error_file;
  $c->stash->{download_data}    = $data_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}


####
1;
####
