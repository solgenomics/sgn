
package CXGN::Trial::Download::Plugin::IGDFacilitySpreadsheet;

use Moose::Role;
use Spreadsheet::WriteExcel;

sub verify {
    1;
}

sub download { 
    my $self = shift;
    
    my $trial_id = $self->trial_id();

    my $t = CXGN::Trial->new( { bcs_schema => $self->bcs_schema(), trial_id => $trial_id });
    
    my $layout = $t->get_layout()->get_design();
    print STDERR "FILENAME: ".$self->filename()."\n";
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    # write primary headers
    #
    $ws->write(0, 0, "Project Details");
    $ws->write(0, 2, "Sample Details");
    $ws->write(0, 12, "Organism Details");
    $ws->write(0, 21, "Origin Details");

    # write secondary headers
    #
    my @headers = ( 
	"Project Name",
	"User ID",
	"Plate Name",
	"Well", 
	"Sample Name", 
	"Pedigree",
	"Population",
	"Stock Number",
	"Sample DNA Concentration (ng/ul)",
	"Sample Volume (ul)",
	"Sample DNA Mass(ng)",
	"Kingdom",
	"Genus",
	"Species",
	"Common Name",
	"Subspecies",
	"Variety",
	"Seed Lot"
	);

    for(my $i=0; $i<@headers; $i++) { 
	$ws->write(1, $i, $headers[$i]);
    }

    # replace accession names with igd_synonyms
    #
    print STDERR "Converting accession names to igd_synonyms...\n";
    foreach my $k (sort wellsort (keys %{$layout})) { 
	my $q = "SELECT value FROM stock JOIN stockprop using(stock_id) JOIN cvterm ON (stockprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='igd_synonym' AND stock.uniquename = ?";
	my $h = $self->bcs_schema()->storage()->dbh()->prepare($q);
	$h->execute($layout->{$k}->{accession_name});
	my ($igd_synonym) = $h->fetchrow_array();
	$layout->{$k}->{igd_synonym} = $igd_synonym;
	if ($layout->{$k}->{accession_name}=~/BLANK/i) { 
	    $layout->{$k}->{igd_synonym} = "BLANK";
	}
    }
    # write plate info
    #
    my $line = 0;

    foreach my $k (sort wellsort (keys %{$layout})) { 
	$ws->write(2 + $line, 0, "NextGen Cassava");
	my $breeding_program_data = $t->get_breeding_programs();
	my $breeding_program_name = "";
	if ($breeding_program_data->[0]) { 
	    $breeding_program_name = $breeding_program_data->[0]->[1];
	}
	$ws->write(2 + $line, 0, $layout->{$k}->{genotyping_project_name});
	$ws->write(2 + $line, 1, $layout->{$k}->{genotyping_user_id});
	$ws->write(2 + $line, 2, $t->get_name());
	$ws->write(2 + $line, 3, $k);
	$ws->write(2 + $line, 4, $layout->{$k}->{igd_synonym});
	$ws->write(2 + $line, 16, "Manihot");
	$ws->write(2 + $line, 17, "esculenta");
	$ws->write(2 + $line, 20, $t->get_location());
	$line++;
    }

    $ss ->close();
    return "";
}

sub wellsort { 
    my $row_a = substr($a, 0, 1);
    my $row_b = substr($b, 0, 1);

    my $col_a;
    my $col_b;
    if ($a =~ m/(\d+)/) { 
	$col_a = $1;
    }
    if ($b =~ m/(\d+)/) { 
	$col_b = $1;
    }

    if ($row_a ne $row_b) { 
	return $row_a cmp $row_b;
    }
    else { 
	return $col_a <=> $col_b;
    }
}


1;
