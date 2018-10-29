
package SGN::Controller::AJAX::MixedModels;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Basename qw | basename |;
use CXGN::Dataset::File;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

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
    #my $tmp_dir = File::Spec->catfile($c->config->{basepath}, 'gwas_tmpdir');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;
    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath);
    my $phenotype_data_ref = $ds->retrieve_phenotypes();

    print STDERR Dumper($phenotype_data_ref->[0]);
    
    my @select = ();
    foreach my $colname (@{$phenotype_data_ref->[0]}) { 
	my $html .= "<option id=\"$colname\">$colname</option>";
	push @select, $html;
    }
    print STDERR Dumper(\@select);
    my @dependent_items = @select[39..scalar(@select)];
    print STDERR Dumper(\@dependent_items);
    my $dependent_html = join("\n", @dependent_items);

    my @factors =@select[0..38];
    my $html = join("\n", @factors);
    
    $c->stash->{rest} = { 
	dependent_variable => "<select id=\"dependent_variable_select\">$dependent_html</select>",
	fixed_factors => "<select multiple rows=\"10\" id=\"fixed_factors_select\">$html</select>",
	random_factors => "<select multiple rows=\"10\" id=\"random_factors_select\">$html</select>",
        tempfile => $tempfile."_phenotype.txt",
    };
}

sub run: Path('/ajax/mixedmodels/run') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $tempfile = $c->req->param("tempfile");
    my $dependent_variable = $c->req->param("dependent_variable");
    my $fixed_factors = $c->req->param("fixed_factors");
    my $random_factors = $c->req->param("random_factors");

    print STDERR "DV: $dependent_variable FF: $fixed_factors - RF: $random_factors TF: $tempfile\n";
    my $temppath = $c->config->{basepath}."/".$tempfile;

    # generate params_file
    #
    my $param_file = $temppath.".params";
    open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
    print $F "dependent_variable = \"$dependent_variable\"\n";
    #my @fixed_factors = split ",", $fixed_factors;
    my $formatted_fixed_factors = "\"$fixed_factors\"";

    print $F "fixed_factors <- c($formatted_fixed_factors)\n";
    my @random_factors = split ",", $random_factors;
    my $formatted_random_factors = join(",", map { "\"(1|$_)\"" } @random_factors);
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

    print STDERR "Grab data...\n";

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");
    
    $file = basename($file);

    my $temppath = $c->config->{basepath}."/static/documents/tempfiles/mixedmodels/".$file;
    
    my $F;
    if (! open($F, "<", $temppath)) { 
	$c->stash->{rest} = { error => "Can't find data." };
	return;
    }

    my $header = <$F>;
    chomp($header);
    
    my @keys = split("\t", $header);
    
    print STDERR "keys = ( ".(join ",", @keys).")\n";

    my @data = ();

    while (<$F>) { 
	chomp;
	if (//) { next; }
	my @fields = split "\t";
	my %line = {};
	for(my $n=0; $n <@keys; $n++) { 
	    if (exists($fields[$n]) && 
		!($fields[$n] eq "" ||
		$fields[$n] eq "null")) { 
		$line{$keys[$n]}=$fields[$n];   
	    }
	}
	
	push @data, \%line;
    }

    print STDERR Dumper(\@data);

    $c->stash->{rest} = { data => \@data, trait => $trait};
}


1;
