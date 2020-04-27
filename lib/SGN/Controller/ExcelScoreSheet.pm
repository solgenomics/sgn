
use strict;

package SGN::Controller::ExcelScoreSheet;

use Moose;
use Spreadsheet::WriteExcel;
use File::Slurp qw | read_file |;
use File::Temp;
use Data::Dumper;
use CXGN::Trial::TrialLayout;

BEGIN { extends 'Catalyst::Controller'; }


sub excel_download_trial : Path('/barcode/trial_excel_download') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id=shift;

    my $tl = CXGN::Trial::TrialLayout->new( { schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id, experiment_type => 'field_layout' });

    my $trial_data = $tl->get_design();

    print STDERR Data::Dumper::Dumper($trial_data);
    
    



}


sub excel_download : Path('/barcode/excel_download/') Args(0) { 
    my $self  =shift;
    my $c = shift;
  
    my $operator = $c->req->param('operator');
    my $date     = $c->req->param('date');
    my $project  = $c->req->param('project');
    my $location = $c->req->param('location');
    my $lines    = $c->req->param('lines');
    my @cvterms = $c->req->param('cvterms');
	print "MY PROJECT: $operator , $date ,  $location , $lines , my @cvterms\n";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $project_row = $schema->resultset("Project::Project")->find({ name => $project});
    my $project_name = $project_row->name();
    my $project_desc = $project_row->description();


    $lines =~ s/\r//g;
    my @lines = split /\n/, $lines;

    my $plot_of = $schema->resultset("Cv::Cvterm")->find( { name => "plot_of" })->cvterm_id();
    print STDERR "PLOT_OF: $plot_of\n";
    
    my $plot_type = $schema->resultset("Cv::Cvterm")->find( { name=>"plot"})->cvterm_id();
    

    # check if all lines exist and bail out if not
    my @missing = ();
    my @not_plots = ();
    my @stock_rows = ();
    foreach my $s (@lines) { 
	my $stock_row = $schema->resultset("Stock::Stock")->find( { name=>$s });
	if (!$stock_row) {
	    print STDERR "Missing: $s\n";
	    push @missing, $s;
	}
	elsif ($stock_row->type_id != $plot_type) { 
	    push @not_plots, $s;
	}
	else { 
	    push @stock_rows, $stock_row;
	}
    }
	
    if (@missing > 0 || @not_plots > 0) { 
	$c->res->body("The following plots could not be found in the database or are not of type stocks: ".(join(",", @missing)).", ".(join(",", @not_plots))."<br />Please correct the problem and try again.");
	return;
    }

    my $cvterm_data = [];
    my @tools_def = read_file($c->path_to("../cassava/documents/barcode/tools.def"));
    
    my %cvinfo;
    for (my $i=0; $i<(@tools_def); $i++) { 
	chomp($tools_def[$i]);
	my ($id, $version, $priority, $values, $name) = split /\t/, $tools_def[$i];
	$cvinfo{$id} = { version => $version,
			 priorty => $priority,
			 values => $values,
			 name => $name,
	};
    }
    
#    print Data::Dumper::Dumper(\%cvinfo);
	
    my $dir = $c->tempfiles_subdir('/other');
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');
    print STDERR "TEMPFILE: $tempfile\n";
    my $wb = Spreadsheet::WriteExcel->new($tempfile);
    die "Could not create excel file " if !$wb;

    my $ws = $wb->add_worksheet();

    my $bold = $wb->add_format();
    $bold->set_bold();
 
    my $unique_id = time().$$;
    $ws->write(0, '0', 'Spreadsheet ID'); $ws->write('0', '1', $unique_id);
    $ws->write(1,'0', 'Trial name');      $ws->write(1, 1, $project_name);
    $ws->write(2, 0, $project_desc);
    $ws->write(3, 0, "Plants per plot");  $ws->write(3, 1, "PLANTS PER PLOT");
    $ws->write(4, '0', 'Operator');       $ws->write(4, '1', $operator, $bold);
    $ws->write(5, '0', 'Date');           $ws->write(5, '1', $date, $bold);

    for (my $i=0; $i<@cvterms; $i++) { 
	$ws->write(6, $i+6, $cvinfo{$cvterms[$i]}->{name});
    }
    

    for (my $n=0; $n<@lines;  $n++) { 	
	my $parent_id = $schema->resultset("Stock::StockRelationship")->find( { subject_id=>$stock_rows[$n]->stock_id(), type_id=>$plot_of })->object_id();

	my $parent = $schema->resultset("Stock::Stock")->find( { stock_id => $parent_id })->name();

	my $prop_rs = $schema->resultset("Stock::Stockprop")->search( { stock_id=>$lines[$n] } );
	my %props = ();

	while (my $prop_rs->next()) { 
	    $props{$prop_rs->type->name()} = $prop_rs->value();

	}

	my $row_number = $props{row_number};
	my $clone_name = $parent;
	my $block = $props{block};
	my $plot_id = $lines[$n];
	my $rep = $props{replicate};
	my $number_of_surviving_plants = $props{number_of_surviving_plants};

	$ws->write($n+6, 0, $row_number);
	$ws->write($n+6, 1, $lines[$n]);
	$ws->write($n+6, 2, $block);
	$ws->write($n+6, 3, $plot_id);
	$ws->write($n+6, 4, $rep);
	$ws->write($n+6, 5, $number_of_surviving_plants);

	for (my $i=0; $i<@cvterms; $i++) { 
	    if ($cvinfo{$cvterms[$i]}->{values} eq "numeric") { 
		$ws->data_validation($n+6, $i+6, { validate => "any" });
	    }
	    else { 
		$ws->data_validation($n+6, $i+6, 
				     { 
					 validate => 'list',
					 value    => [ split ",", $cvinfo{$cvterms[$i]}->{values} ],
				     });
	    }
	}
    }
    $wb->close();
    my $contents = read_file($tempfile);
    $c->res->content_type('Application/xls');
    $c->res->body($contents);
}


1;


