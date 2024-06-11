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
  is => "ro"
);

# Array of required columns, will check to see if they are included in the file
has required_columns => (
  isa => "ArrayRef[Str]",
  is => "ro"
);

# Array of optional columns, any column that is not required or optional will be labeled as "additional"
has optional_columns => (
  isa => "ArrayRef[Str]",
  is => "ro"
);


sub parse {
  my $self = shift;
  my $file = $self->file();
  my $type = $self->type();
  my $required_columns = $self->required_columns();
  my $optional_columns = $self->optional_columns();

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
    my $parsed = $parser->parse($file);
    my $columns = $parsed->{columns};
    my $data = $parsed->{data};

    # Check for empty files with no data
    if ( scalar(@$columns) < 1 || scalar(@$data) < 1 ) {
      push @{$parsed->{errors}}, "The file has no data";
    }

    # Handle required / optional columns
    if ( $required_columns ) {

      # Check for missing required columns
      foreach my $req (@$required_columns) {
        if ( !grep( /^$req$/, @$columns ) ) {
          push @{$parsed->{errors}}, "Required column $req is missing";
        }
      }

      # Parse each column into required / optional / additional
      $parsed->{required_columns} = [];
      $parsed->{optional_columns} = [];
      $parsed->{additional_columns} = [] if $optional_columns;
      foreach my $col (@$columns) {
        if ( grep (/^$col$/, @$required_columns) ) {
          push @{$parsed->{required_columns}}, $col;
        }
        elsif ( $optional_columns ) {
          if ( grep (/^$col$/, @$optional_columns) ) {
            push @{$parsed->{optional_columns}}, $col;
          }
          else {
            push @{$parsed->{additional_columns}}, $col;
          }
        }
        else {
          push @{$parsed->{optional_columns}}, $col;
        }
      }

    }

    return $parsed;
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
