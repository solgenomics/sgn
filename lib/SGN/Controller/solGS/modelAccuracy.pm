package SGN::Controller::solGS::modelAccuracy;


use Moose;
use namespace::autoclean;


use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;
use Math::Round::Var;
use Statistics::Descriptive;


BEGIN { extends 'Catalyst::Controller' }



sub download_validation :Path('/solgs/download/validation/pop') Args() {
    my ($self, $c, $pop_id, $trait, $trait_id, $gp, $protocol_id) = @_;

    $c->stash->{training_pop_id} = $pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    $c->controller('solGS::Files')->validation_file($c);
    my $val_file = $c->stash->{validation_file};

    if (-s $val_file)
    {
	my @raw = read_file($val_file);

	$self->cross_validation_stat($c, $pop_id, $trait_abbr);
	my $cv_stat = $c->stash->{cross_validation_stat};

	my @summary = join("\n", map { $_->[0] . "\t" . $_->[1] }  @$cv_stat);

	my @all = (@raw, "\n ---- Summary --- \n", @summary);
	$c->res->content_type("text/plain");
        $c->res->body(join('', @all));
    }
    else
    {
	croak "No cross validation file was found or it is empty.";
    }

}


sub get_model_accuracy_value {
    my ($self, $c, $model_id, $trait_abbr) = @_;

    $c->stash->{training_pop_id} = $model_id;
    $c->stash->{trait_abbr} = $trait_abbr;

    $self->cross_validation_stat($c, $model_id, $trait_abbr);
    my $cv_stat = $c->stash->{cross_validation_stat};

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
    my @raw_cvs = grep { $_->[0] ne 'Average'} @$cvs;

    $c->stash->{cross_validations} =  \@raw_cvs;
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

	$self->cross_validation_stat($c, $model_id, $trait_abbr);
	$c->stash->{accuracy_report} = $c->stash->{cross_validation_stat};
    }

}


sub cross_validation_stat {
    my ($self, $c, $model_id, $trait_abbr) = @_;

    $self->get_cross_validations($c, $model_id, $trait_abbr);
    my $cv_data = $c->stash->{cross_validations};

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

    $c->stash->{cross_validation_stat} = \@desc_stat;

}


sub create_model_summary {
    my ($self, $c, $model_id, $trait_id) = @_;

    my $protocol_id = $c->stash->{genotyping_protocol_id};

    $c->controller("solGS::solGS")->get_trait_details($c, $trait_id);
    my $tr_abbr = $c->stash->{trait_abbr};

    my $path = $c->req->path;

	my $data_set_type;
	if ($path =~ /solgs\/traits\/all\/population\//)
	{

	  	$data_set_type = 'single population';
	}
	elsif ($path =~ /solgs\/models\/combined\/trials\//)
	{
	 	$data_set_type = 'combined populations';
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

    my $heritability = $c->controller("solGS::Heritability")->get_heritability($c, $model_id, $trait_id);
    my $additive_variance = $c->controller("solGS::Heritability")->get_additive_variance($c, $model_id, $trait_id);

    my $model_summary = [$trait_page, $accuracy_value, $additive_variance, $heritability];

    $c->stash->{model_summary} = $model_summary;

}



sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}


####
1;
###
