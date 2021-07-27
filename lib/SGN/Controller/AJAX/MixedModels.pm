
package SGN::Controller::AJAX::MixedModels;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::MixedModels;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );

	
select(STDERR);
$| = 1;

sub model_string: Path('/ajax/mixedmodels/modelstring') Args(0) {
    my $self = shift;
    my $c = shift;

    my $params = $c->req->body_data();

    my $fixed_factors = $params->{"fixed_factors"};

    my $fixed_factors_interaction = $params->{fixed_factors_interaction};

    my $variable_slope_intersects = $params->{variable_slope_intersects};

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

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);
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
    
    my $mm = CXGN::MixedModels->new( { tempfile => $c->config->{basepath}."/".$tempfile });

    $mm->dependent_variables($dependent_variables);
    $mm->random_factors($random_factors);
    $mm->run_model($c->config->{backend}, $c->config->{cluster_host});

    my $temppath = $c->config->{basepath}."/".$tempfile;

    my $adjusted_blups_file = $temppath.".adjustedBLUPs";
    my $blupfile = $temppath.".BLUPs";
    my $bluefile = $temppath.".BLUEs";
    my $adjusted_blues_file = $temppath.".adjustedBLUEs";
    my $anovafile = $temppath.".anova";
    my $varcompfile = $temppath.".varcomp";
    my $error;
    my $lines;
    
    my $accession_names;

    my $adjusted_blups_html;
    my $adjusted_blups_data;

    my $adjusted_blues_html;
    my $adjusted_blues_data;

    my $traits;

    my $method;
    
    # we need either a blup or blue result file. Check for these and otherwise return an error!
    #
    if ( -e $adjusted_blups_file) {
	$method = "random";
	($adjusted_blups_data, $adjusted_blups_html, $accession_names, $traits) = $self->result_file_to_hash($c, $adjusted_blups_file);
    }
    elsif (-e $adjusted_blues_file) {
	$method = "fixed";
	($adjusted_blues_data, $adjusted_blues_html, $accession_names, $traits) = $self->result_file_to_hash($c, $adjusted_blues_file);
    }
    else { 
	$error = "The analysis could not be completed. The factors may not have sufficient numbers of levels to complete the analysis. Please choose other parameters.";
	$c->stash->{rest} = { error => $error };
	return;
    }

    # read other result files, if they exist and parse into data structures
    #
    my $blups_html;
    my $blups_data;
    if (-e $blupfile) {
	($blups_data, $blups_html, $accession_names, $traits) = $self->result_file_to_hash($c, $blupfile);
    }

    my $blues_html;
    my $blues_data;
    if (-e $bluefile) {
	($blues_data, $blues_html, $accession_names, $traits) = $self->result_file_to_hash($c, $bluefile);	
    }

    my $response = {
	error => $error,
	accession_names => $accession_names,
	adjusted_blups_data => $adjusted_blups_data,
        adjusted_blups_html => $adjusted_blups_html,
	adjusted_blues_data => $adjusted_blues_data,
	adjusted_blues_html => $adjusted_blues_html,
	blups_data => $blups_data,
	blups_html => $blups_html,
	blues_data => $blues_data,
	blues_html => $blues_html,
	method => $method,
	input_file => $temppath,
	traits => $traits
    };

    $c->stash->{rest} = $response;
}

sub result_file_to_hash {
    my $self = shift;
    my $c = shift;
    my $file = shift;

    print STDERR "result_file_to_hash(): Processing file $file...\n";
    my @lines = read_file($file);
    chomp(@lines);

    my $header_line = shift(@lines);
    my ($accession_header, @trait_cols) = split /\t/, $header_line;

    my $now = DateTime->now();
    my $timestamp = $now->ymd()."T".$now->hms();

    my $operator = $c->user()->get_object()->get_first_name()." ".$c->user()->get_object()->get_last_name();
    
    my @fields;
    my @accession_names;
    my %analysis_data;
    
    my $html = qq | <style> th, td { padding: 10px;} </style> \n <table cellpadding="20" cellspacing="20"> |;
    
    foreach my $line (@lines) {
	my ($accession_name, @values) = split /\t/, $line;
	push @accession_names, $accession_name;
	$html .= "<tr><td>".join("</td><td>", $accession_name, @values)."</td></tr>\n";
	for(my $n=0; $n<@values; $n++) {
	    print STDERR "Building hash for accession $accession_name and trait $trait_cols[$n]\n";
	    $analysis_data{$accession_name}->{$trait_cols[$n]} = [ $values[$n], $timestamp, $operator, "", "" ];
	    
	}
	
    }
    $html .= "</table>";

    print STDERR "Analysis data formatted: ".Dumper(\%analysis_data);
    
    return (\%analysis_data, $html, \@accession_names, \@trait_cols);
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
