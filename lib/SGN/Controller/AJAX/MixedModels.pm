
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
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub model_string: Path('/ajax/mixedmodels/modelstring') Args(0) {
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();
    
    print STDERR Dumper($params);
    
    my $fixed_factors = $c->req->param("fixed_factors");
    
    print STDERR "JSON received: $fixed_factors\n";

    my $fixed_factors_interaction = $params->{fixed_factors_interaction};
    my $random_factors = $params->{random_factors};

    
    my $mm = CXGN::MixedModels->new();
    $mm->fixed_factors( $fixed_factors );
    $mm->fixed_factors_interaction( $fixed_factors_interaction );
    $mm->random_factors( $random_factors );

    my ($model, $error) =  $mm->generate_model();

    print STDERR "MODEL: $model\n";
    
    $c->stash->{rest} = { error => $error, model => $model };
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
    foreach my $trait (@$traits) {
	my $html .= "<option>$trait</option>\n";
	push @traits_select, $html;
    }
    
    my $traits_html = join("\n", @traits_select);


    $c->stash->{rest} = { 
	dependent_variable => "<select id=\"dependent_variable_select\">$traits_html</select>",
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

    my $tempfile = $c->req->param("tempfile");
    my $dependent_variable = $c->req->param("dependent_variable");
    my $fixed_factors = $c->req->param("fixed_factors");
    my $fixed_factors_interaction = $c->req->param("fixed_factors_interaction");
    my $random_factors = $c->req->param("random_factors");
    my $random_factors_random_slope = $c->req->param("random_factors_random_slope");
    
    print STDERR "DV: $dependent_variable FF: $fixed_factors - RF: $random_factors TF: $tempfile. FFI: $fixed_factors_interaction RFRS: $random_factors_random_slope\n";
  
    my $temppath = $c->config->{basepath}."/".$tempfile;

    # generate params_file
    #
    my $param_file = $temppath.".params";
    open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
    print $F "dependent_variable = \"$dependent_variable\"\n";
    #my @fixed_factors = split ",", $fixed_factors;
    my $formatted_fixed_factors = "\"$fixed_factors\"";

    print $F "fixed_factors <- c($formatted_fixed_factors)\n";

    if ($fixed_factors_interaction) { 
	print $F "fixed_factors_interaction = T\n";
    }
    if ($random_factors_random_slope) { 
        print $F "random_factors_random_slope = T\n";
    }

    my @random_factors = split ",", $random_factors;
    my $formatted_random_factors = "";
    if ($random_factors_random_slope) { 
	$formatted_random_factors = "\" (1 + $random_factors[0] | $random_factors[1]) \"";

    }
    else { 
	$formatted_random_factors = join(",", map { "\"(1|$_)\"" } @random_factors);	
    }
    print $F "random_factors <- c($formatted_random_factors)\n";
    close($F);
    
    # run r script to create model
    #
    my $cmd = "R CMD BATCH  '--args datafile=\"".$temppath."\" paramfile=\"".$temppath.".params\"' " . $c->config->{basepath} . "/R/mixed_models.R $temppath.out";
    
    print STDERR "running R command $cmd...\n";
    system($cmd);
    print STDERR "Done.\n";

    my $resultfile = $temppath.".results";

    my $error;
    my $lines;

    if (! -e $resultfile) { 
	$error = "The analysis could not be completed. The factors may not have sufficient numbers of levels to complete the analysis. Please choose other parameters."
    }
    else { 
	$lines = read_file($temppath.".results");
    }

    my $figure1file_response;
    my $figure2file_response;
    my $figure3file_response;
    my $figure4file_response;

    $c->stash->{rest} = {
	error => $error,
        figure1 => $figure1file_response,
        figure2 => $figure2file_response,
        figure3 => $figure3file_response,
        figure4 => $figure4file_response,
        html =>  $lines,
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
