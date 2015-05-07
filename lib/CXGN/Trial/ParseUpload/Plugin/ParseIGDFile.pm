
=head1 NAME

ParseIGDFile - a plugin to parse files provided by the IGD, defining the name of a genotyping experiment as well as the location of the blank. The file is a tab delimited file with the format described at the IGD website. [add link here].

=head1 AUTHOR

Lukas Mueller

=cut

package CXGN::Trial::ParseUpload::Plugin::ParseIGDFile;

use Moose::Role;
use File::Slurp "read_file";

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my @lines = read_file($filename);
  
    my $well_col = 3;
    my $accession_col = 4;
    my $trial_col = 2;

    my $blank_well = "";
    my %trial_names = ();
    for(my $row=2; $row<98; $row++) {  # first two rows are header rows
	my @fields = split "\t", $lines[$row];
	if ($fields[$accession_col]=~/blank/i) { 
	    $blank_well = $fields[$well_col];
	}
	$trial_names{$fields[$trial_col]}++;
    }

    my $errors =[]; 
    if (!$blank_well) { 
	push @$errors, "No blank well found in spreadsheet";
    }
    if (keys(%trial_names)>1) {
	print STDERR join ",", keys(%trial_names);
	push @$errors, "All trial names in the trial column must be identical";

    }

    $self->_set_parse_errors($errors);    
    
    if (@$errors!=0) { 
	return 0;
    }

    my ($trial_name) = keys(%trial_names);

    $self->_set_parsed_data( { trial_name => $trial_name, blank_well => $blank_well } );

    return 1;	
}

sub _parse_with_plugin { 
    my $self = shift;
    if ($self->_validate_with_plugin()) { 
	return 1;
    }
    return 0;
}
    
1;
    
