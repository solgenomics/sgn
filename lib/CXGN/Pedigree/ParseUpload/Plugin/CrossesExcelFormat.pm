
package CXGN::Pedigree::ParseUpload::Plugin::CrossesExcelFormat;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Spreadsheet::ParseExcel;

sub name {
    return "crosses excel";
}

sub validate {
  my $self = shift;
  my $filename = shift;
  my $validate_result = $self->_validate($filename);
  if (!$validate_result) {
    return;
  }
  if (!$validate_result->{valid}) {
    return;
  }
}

sub parse_errors {
  my $self = shift;
  my $filename = shift;
  my $validate_result = $self->_validate($filename);
  my @errors;
  if (!$validate_result) {
    my $error_message = "Error running parse on cross upload file";
    push (@errors, $error_message);
    return \@errors;
  }
  if (!$validate_result->{valid}) {
    my $errors_ref = $validate_result->{errors};
    if (!$errors_ref) {
      my $error_message = "Error running parse validation on cross upload file";
      push (@errors, $error_message);
      return \@errors;
    }
    @errors = @{$errors_ref};
    return \@errors;
  }
  return;
}

sub _validate {
    my $self = shift;
    my $filename = shift;
    my @errors;
    my $passed_validation;
    my %validate_result;

    my $parser   = Spreadsheet::ParseExcel->new();
    my $spreadsheet = $parser->parse($filename);
    if ( !$spreadsheet ) {
        push @errors,  $parser->error();
	$validate_result{'valid'} = $passed_validation;
	$validate_result{'errors'} = \@errors;
	return \%validate_result;
    }


    my $worksheet = ( $spreadsheet->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if ($col_max < 2 || $row_max < 4 ) {#must have header and at least one row of crosses
      push @errors, "Spreadsheet is missing header";
      $validate_result{'valid'} = $passed_validation;
      $validate_result{'errors'} = \@errors;
      return \%validate_result
    }

    print STDERR "Validating cross file\n\n";
    #hash for column headers
    my $cross_name  = $worksheet->get_cell(0,0);
    my $cross_type  = $worksheet->get_cell(0,1);
    my $maternal_parent  = $worksheet->get_cell(0,2);
    my $paternal_parent  = $worksheet->get_cell(0,3);


    if (!$cross_name || $cross_name ne 'cross_name' ) {
      push @errors, "cross_name is missing from the header";
    }

    if (!$cross_type || $cross_type ne 'cross_type') {
      push @errors, "cross_type is missing from the header";
    }

    if (!$maternal_parent || $maternal_parent ne 'maternal_parent') {
      push @errors, "maternal_parent is missing from the header";
    }

    if (!$paternal_parent || $paternal_parent ne 'paternal_parent') {
      push @errors, "paternal_parent is missing from the header";
    }

    if (scalar(@errors) >= 1) {
      $validate_result{'valid'} = $passed_validation;
      $validate_result{'errors'} = \@errors;
      return \%validate_result
    }

    $validate_result{'valid'} = $passed_validation;
    $validate_result{'errors'} = \@errors;
    return \%validate_result
}




sub parse {
    my $self = shift;
    my $filename = shift;
    my %parse_result;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %plots_seen;
    my %traits_seen;
    my @plots;
    my @traits;
    my %data;

    #validate first
    if (!$self->validate($filename)) {
	$parse_result{'error'} = "File not valid";
	print STDERR "File not valid\n";
	return \%parse_result;
    }

    @file_lines = read_file($filename);
    $header = shift(@file_lines);
    chomp($header);
    @header_row = split($delimiter, $header);

    ## Get column numbers (indexed from 1) of the plot_id, trait, and value.
    foreach my $header_cell (@header_row) {
	$header_cell = substr($header_cell,1,-1);  #remove double quotes
	if ($header_cell eq "plot_id") {
	    $header_column_info{'plot_id'} = $header_column_number;
	}
	if ($header_cell eq "trait") {
	    $header_column_info{'trait'} = $header_column_number;
	}
	if ($header_cell eq "value") {
	    $header_column_info{'value'} = $header_column_number;
	}
	$header_column_number++;
    }
    if (!defined($header_column_info{'plot_id'}) || !defined($header_column_info{'trait'}) || !defined($header_column_info{'value'})) {
	$parse_result{'error'} = "plot_id and/or trait columns not found";
	print STDERR "plot_id and/or trait columns not found";
	return \%parse_result;
    }

    foreach my $line (@file_lines) {
	chomp($line);
     	my @row =  split($delimiter, $line);
	my $plot_id = substr($row[$header_column_info{'plot_id'}],1,-1);
	my $trait = substr($row[$header_column_info{'trait'}],1,-1);
	my $value = substr($row[$header_column_info{'value'}],1,-1);
	if (!defined($plot_id) || !defined($trait) || !defined($value)) {
	    $parse_result{'error'} = "error getting value from file";
	    print STDERR "value: $value\n";
	    return \%parse_result;
	}
	$plots_seen{$plot_id} = 1;
	$traits_seen{$trait} = 1;
	$data{$plot_id}->{$trait} = $value;
    }

    foreach my $plot (keys %plots_seen) {
	push @plots, $plot;
    }
    foreach my $trait (keys %traits_seen) {
	push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'plots'} = \@plots;
    $parse_result{'traits'} = \@traits;

    return \%parse_result;
}

1;
