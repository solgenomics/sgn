package CXGN::File::Parse;

use Moose;
use Module::Pluggable require => 1;

# Path to the file that is being parsed
has 'file' => (
  isa => "Str",
  is => "ro",
  required => 1
);

# File type, if not provided will use the file path extension to guess
# csv = comma separated values
# tsv = tab separated values
# txt = (alias for tsv)
# xls = Old MS Excel
# xlsx = New MS Excel
has 'type' => (
  isa => "Str",
  is => "ro",
  required => 0
);


sub parse {
  my $self = shift;
  my $file = $self->file();
  my $type = $self->type();

  # If type is not defined, use the file extension
  if ( !$type ) {
    ($type) = $file =~ /\.([^.]+)$/;
  }

  # Use tsv for txt files
  $type = "tsv" if ($type eq "txt");

  # Check if the file exists
  if ( !-e $file ) {
    return {
      errors => [
        "The file $file does not exist"
      ]
    }
  }

  # Find the appropriate parser plugin
  my $parser;
  foreach my $p ($self->plugins()) {
    if ( $type eq $p->type() ) {
      $parser = $p;
    }
  }

  # Parse the file with the plugin
  if ( $parser ) {
    return $parser->parse($file);
  }

  # No parser plugin found for file type
  else {
    return {
      errors => [
        "No appropriate file parsing plugin for file: $file, type: $type"
      ]
    };
  }
}

1;
