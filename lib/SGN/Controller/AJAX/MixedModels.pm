
package SGN::Controller::AJAX::MixedModels;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use JSON::Any;
use File::Basename qw | basename |;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::MixedModels;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );


sub model_string: Path('/ajax/mixedmodels/modelstring') Args(0) {
    my $self = shift;
    my $c = shift;

    my $params = $c->req->body_data();

    print STDERR Dumper($params);

    my $fixed_factors = $params->{"fixed_factors"};

    print STDERR "JSON received: $fixed_factors\n";

    my $fixed_factors_interaction = $params->{fixed_factors_interaction};

    print STDERR "JSON for interaction: ".Dumper($fixed_factors_interaction)."\n";

    my $variable_slope_intersects = $params->{variable_slope_intersects};

    print STDERR "JSON for variable slope intersect: ".Dumper($variable_slope_intersects)."\n";

    my $random_factors = $params->{random_factors};
    my $dependent_variables = $params->{dependent_variables};

    my $mm = CXGN::MixedModels->new();
    if ($dependent_variables) {
	$mm->dependent_variables($dependent_variables);
    }
    if ($fixed_factors) {
	$mm->fixed_factors( $fixed_factors );
    }
    if ($fixed_factors_interaction) {
	$mm->fixed_factors_interaction( $fixed_factors_interaction );
    }
    if ($variable_slope_intersects) {
	$mm->variable_slope_intersects( $variable_slope_intersects);
    }
    if ($random_factors) {
	$mm->random_factors( $random_factors );
    }

    my ($model, $error) =  $mm->generate_model();

    print STDERR "MODEL: $model\n";

    $c->stash->{rest} = {
	error => $error,
	model => $model,
	dependent_variables => $dependent_variables,
    };
}

sub prepare: Path('/ajax/mixedmodels/prepare') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');

    if (! $c->user()) {
        $c->stash->{rest} = {error=>'You must be logged in first!'};
        $c->detach;
    }

    $c->tempfiles_subdir("mixedmodels");

    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"mixedmodels/mm_XXXXX");

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    $ds->retrieve_phenotypes();

    my $pf = CXGN::Phenotypes::File->new( { file => $temppath."_phenotype.txt" });

    my @factor_select;

    # only use if factor has multiple levels, start from appropriate hardcoded list
    #
    my @factors = qw | studyYear programName studyName studyDesign plantingDate locationName replicate rowNumber colNumber germplasmName|;
    foreach my $factor (@factors) {
	if ($pf->distinct_levels_for_factor($factor) > 1) {
	    push @factor_select, $factor;
	}
    }

    my @traits_select = ();
    my $traits = $pf->traits();

    #my $trait_select_checkbox = "trait_select_checkbox";
    my $dependent_variable_select = "dependent_variable_select";

  my $trait_html ="";

     foreach my $trait (@$traits) {
       if ($trait =~ m/.+\d{7}/){
        $trait_html .= '<input type="checkbox" class= "trait_box" name="'.$dependent_variable_select.'" value="'.$trait.'">'.$trait.'</input> </br>';
      }
       }
        #$html .= "</tbody></table>";

       #$html .= "<script>jQuery(document).ready(function() { jQuery('#html-dependent_variable_select').DataTable({ 'lengthMenu': [[2, 4, 6, 8, 10, 25, 50, -1], [2, 4, 6, 8, 10, 25, 50, 'All']] }); } );</script>";

        #$c->stash->{rest} = { select => $html };

  $c->stash->{rest} = {

       dependent_variable => $trait_html,

	factors => \@factor_select,
	tempfile => $tempfile."_phenotype.txt",
    };

    if (!@factor_select) {
	$c->stash->{rest}->{error} = "There are no factors with multiple levels in this dataset.";
    }
}

sub run: Path('/ajax/mixedmodels/run') Args(0) {
    my $self = shift;
    my $c = shift;

    my $params = $c->req()->params();

    print STDERR Dumper($params);

    my $tempfile = $params->{tempfile};
    my $dependent_variables = $params->{'dependent_variables[]'};
    if (!ref($dependent_variables)) {
  $dependent_variables = [ $dependent_variables ];
    }
    my $model  = $params->{model};
    my $random_factors = $params->{'random_factors[]'}; #
    if (!ref($random_factors)) {
	$random_factors = [ $random_factors ];
    }
    my $fixed_factors = $params->{'fixed_factors[]'}; #   "
    if (!ref($fixed_factors)) {
	$fixed_factors = [ $fixed_factors ];
    }
    print STDERR "FIXED FACTOR = ".Dumper($fixed_factors);
    print STDERR "RANDOM factors = ".Dumper($random_factors);
    print STDERR "DEPENDENT VARS = ".Dumper($dependent_variables);

    my $random_factors = '"'.join('","', @$random_factors).'"';
    my $fixed_factors = '"'.join('","',@$fixed_factors).'"';
    my $dependent_variables = '"'.join('","',@$dependent_variables).'"';

    print STDERR "DV: $dependent_variables Model: $model TF: $tempfile.\n";

    my $temppath = $c->config->{basepath}."/".$tempfile;

    # generate params_file
    #
    my $param_file = $temppath.".params";
    open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
    print $F "dependent_variables <- c($dependent_variables)\n";
    print $F "random_factors <- c($random_factors)\n";
    print $F "fixed_factors <- c($fixed_factors)\n";

    print $F "model <- \"$model\"\n";
    close($F);

    # run r script to create model
    #
    my $cmd = "R CMD BATCH  '--args datafile=\"".$temppath."\" paramfile=\"".$temppath.".params\"' " . $c->config->{basepath} . "/R/mixed_models.R $temppath.out";
    print STDERR "running R command $cmd...\n";

    print STDERR "running R command $temppath...\n";

    system($cmd);
    print STDERR "Done.\n";

    my $resultfile = $temppath.".adjusted_means";
    my $blupfile = $temppath.".BLUPs";
    my $bluefile = $temppath.".BLUEs";
    my $anovafile = $temppath.".anova";
    my $varcompfile = $temppath.".varcomp";
    my $error;
    my $lines;

    if (! -e $resultfile) {
	$error = "The analysis could not be completed. The factors may not have sufficient numbers of levels to complete the analysis. Please choose other parameters."
    }
    else {
	$lines = read_file($resultfile);
    }

    my $blups;
    if (-e $blupfile) {     
	$blups = read_file($blupfile);
    }

    my $blues;
    if (-e $bluefile) {
	$blues = read_file($bluefile);
    }

    my $anova;
    if (-e $anovafile) {
	$anova = read_file($anovafile);
    }

    my $varcomp;
    if (-e $varcompfile) {
	$varcomp = read_file($varcompfile);
    }

    my $figure1file_response;
    my $figure2file_response;
    my $figure3file_response;
    my $figure4file_response;

    $c->stash->{rest} = {
	error => $error,
#        figure1 => $figure1file_response,
#        figure2 => $figure2file_response,
#        figure3 => $figure3file_response,
#        figure4 => $figure4file_response,
        adjusted_means_html =>  $lines,
	
	blups_html => $blups,
	blues_html => $blues,
	varcomp_html => $varcomp,
	anova_html => $anova,
    };
}

sub extract_trait_data :Path('/ajax/mixedmodels/grabdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/mixedmodels/".$file);

    my $F;
    if (! open($F, "<", $temppath)) {
	$c->stash->{rest} = { error => "Can't find data." };
	return;
    }

    my $header = <$F>;
    chomp($header);

    my @keys = split("\t", $header);

    my @data = ();

    while (<$F>) {
	chomp;

	my @fields = split "\t";
	my %line = {};
	for(my $n=0; $n <@keys; $n++) {
	    if (exists($fields[$n]) && defined($fields[$n])) {
		$line{$keys[$n]}=$fields[$n];
	    }
	}
	push @data, \%line;
    }

    $c->stash->{rest} = { data => \@data, trait => $trait};
}




1;
