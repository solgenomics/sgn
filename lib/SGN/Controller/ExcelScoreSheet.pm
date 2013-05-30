
use strict;

package SGN::Controller::ExcelScoreSheet;

use Moose;
use Spreadsheet::WriteExcel;
use File::Slurp qw | read_file |;
use File::Temp;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }

sub excel_download : Path('/barcode/excel_download/') Args(0) { 
    my $self  =shift;
    my $c = shift;
  
    my $operator = $c->req->param('operator');
    my $date     = $c->req->param('date');
    my $project  = $c->req->param('project');
    my $location = $c->req->param('location');
    my $lines    = $c->req->param('lines');
    my @cvterms = $c->req->param('cvterms');

    $lines =~ s/\r//g;
    my @lines = split /\n/, $lines;

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
    
    print Data::Dumper::Dumper(\%cvinfo);
	
    my $dir = $c->tempfiles_subdir('/other');
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');
    print STDERR "TEMPFILE: $tempfile\n";
    my $wb = Spreadsheet::WriteExcel->new($tempfile);
    die "Could not create excel file " if !$wb;

    my $ws = $wb->add_worksheet();

    my $bold = $wb->add_format();
    $bold->set_bold();
    
    $ws->write(0, '0', 'Operator');
    $ws->write(0, '1', $operator, $bold);
    $ws->write(1, '0', 'Date');
    $ws->write(1, '1', $date, $bold);

    # write two rows with cvterm names and ids
    for (my $i=0; $i<@cvterms; $i++) { 
	$ws->write(2, $i+2, $cvinfo{$cvterms[$i]}->{name});
	$ws->write(3, $i+2, $cvterms[$i]);	
    }
    
    # write line info and format 
    for (my $n=0; $n<@lines;  $n++) { 
	$ws->write($n+4, 0, $lines[$n]);
	for (my $i=0; $i<@cvterms; $i++) { 
	    if ($cvinfo{$cvterms[$i]}->{values} eq "numeric") { 
		$ws->data_validation($n+4, $i+2, { validate => "any" });
	    }
	    else { 
		$ws->data_validation($n+4, $i+2, 
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


