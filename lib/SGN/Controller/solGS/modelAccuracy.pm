package SGN::Controller::solGS::modelAccuracy;


use Moose;
use namespace::autoclean;


use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;
use JSON;
use Math::Round::Var;
use Statistics::Descriptive;


BEGIN { extends 'Catalyst::Controller' }

sub download_validation :Path('/solgs/download/model/validation') Args() {
    my ($self, $c) = @_;

	my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args( $c, $args );

	my $validation_file = $self->download_validation_file($c);

	my $ret = {'validation_file' => $validation_file};
	$ret = to_json($ret);
	$c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_model_accuracy_value {
    my ($self, $c, $model_id, $trait_abbr) = @_;

    my $cv_stat = $self->cross_validation_stat($c, $model_id, $trait_abbr);

    my ($accuracy) = grep{ $_->[0] eq 'Mean accuracy'} @$cv_stat;

    $c->stash->{accuracy_value} = $accuracy->[1];

}


sub get_cross_validations {
    my ($self, $c, $model_id, $trait_abbr) = @_;

    $c->stash->{training_pop_id} = $model_id;
    $c->stash->{trait_abbr} = $trait_abbr;

    $c->controller('solGS::Files')->validation_file($c);
    my $file = $c->stash->{validation_file};

    my $cvs = $c->controller('solGS::Utils')->read_file_data($file);
    my @raw_cvs = grep { $_->[0] =~ /CV Fold/i } @$cvs;
  
    return \@raw_cvs;
}


sub model_accuracy_report {
    my ($self, $c) = @_;
    my $file = $c->stash->{validation_file};

    my $accuracy;
    if (!-e $file)
    {
	$accuracy = [["Validation file doesn't exist.", "None"]];
    }
    elsif (!-s $file)
    {
	$accuracy = [["There is no cross-validation output report.", "None"]];
    }
    else
    {
        my $model_id = $c->stash->{training_pop_id};
        my $trait_abbr = $c->stash->{trait_abbr};

        $c->stash->{accuracy_report} = $self->cross_validation_stat($c, $model_id, $trait_abbr);
    }

}

sub append_val_summary_stat {
    my ($self, $c, $val_file) = @_;

    my $model_id = $c->stash->{training_pop_id};
    my $trait_abbr = $c->stash->{trait_abbr};
    my $summary_stat = $self->cross_validation_stat($c, $model_id, $trait_abbr);
    my $summary_txt  = "\n----summary statistics----\n";
    $summary_stat = join("\n", map { $_->[0] . "\t" . $_->[1] }  @$summary_stat);
    $summary_txt .= $summary_stat;

    my $val_txt = read_file($val_file, {binmode=>'utf8'});
    if ($val_txt !~ /summary statistics/) {
        write_file($val_file, 
            {append => 1, binmode => 'utf8'}, 
            $summary_txt
        );
    }
}

sub cross_validation_stat {
    my ($self, $c, $model_id, $trait_abbr) = @_;

    my $cv_data = $self->get_cross_validations($c, $model_id, $trait_abbr);

    my @data = map {$_->[1] =~ s/\s+//r } @$cv_data;

    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@data);

    my $min  = $stat->min;
    my $max  = $stat->max;
    my $mean = $stat->mean;
    my $med  = $stat->median;
    my $std  = $stat->standard_deviation;
    my $cv   = ($std / $mean) * 100;
    my $cnt  = scalar(@data);

    my $round = Math::Round::Var->new(0.01);
    $std  = $round->round($std);
    $mean = $round->round($mean);
    $cv   = $round->round($cv);

    $cv  = $cv . '%';

    my @desc_stat = (
	['No. of K-folds', 10],
	['Replications', 2],
	['Total cross-validation runs', $cnt],
	['Minimum accuracy', $min],
	['Maximum accuracy', $max],
	['Standard deviation', $std],
	['Coefficient of variation', $cv],
	['Median accuracy', $med],
	['Mean accuracy',  $mean]
	);

    return \@desc_stat;

}


sub create_model_summary {
    my ($self, $c, $model_id, $trait_id) = @_;

    my $protocol_id = $c->stash->{genotyping_protocol_id};

    $c->controller('solGS::Trait')->get_trait_details($c, $trait_id);
    my $tr_abbr = $c->stash->{trait_abbr};

    my $path = $c->req->path;

	my $data_set_type;
	if ($path =~ /solgs\/traits\/all\/population\//)
	{

	  	$data_set_type = 'single_population';
	}
	elsif ($path =~ /solgs\/models\/combined\/trials\//)
	{
	 	$data_set_type = 'combined_populations';
	}

	my $args = {
		'trait_id' => $trait_id,
		'training_pop_id' => $model_id,
		'genotyping_protocol_id' => $protocol_id,
		'data_set_type' => $data_set_type
	};

	my $model_page = $c->controller('solGS::Path')->model_page_url($args);
	my $trait_page = qq | <a href="$model_page" onclick="solGS.waitPage()">$tr_abbr</a>|;

    $self->get_model_accuracy_value($c, $model_id, $tr_abbr);
    my $accuracy_value = $c->stash->{accuracy_value};

    my $heritability = $c->controller("solGS::gebvPhenoRegression")->get_heritability($c, $model_id, $trait_id);
    my $additive_variance = $c->controller("solGS::gebvPhenoRegression")->get_additive_variance($c, $model_id, $trait_id);

    my $model_summary = [$trait_page, $accuracy_value, $additive_variance, $heritability];

    $c->stash->{model_summary} = $model_summary;

}

sub download_validation_file {
	my ($self, $c) = @_;

	$c->controller('solGS::Trait')->get_trait_details($c, $c->stash->{trait_id});
	
	my $file = $c->controller('solGS::Files')->validation_file($c);
    $self->append_val_summary_stat($c, $file);
	$file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir( $c, $file, 'solgs' );

	return $file;
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}


####
1;
###
