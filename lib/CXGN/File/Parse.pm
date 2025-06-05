package CXGN::File::Parse;

=head1 NAME

CXGN::File::Parse - a generic data file parser that can read csv, txt, xls and xlsx files (via matching plugin) into a uniform parsed data format

=head1 USAGE

BASIC USAGE:
  - Pass the path to the data file as the file argument when instantiating the class.
  - Then, call the parse function to read the file and parse its contents.

  my $parser = CXGN::File::Parse->new(
    file => '/path/to/data.xlsx'
  );
  my $parsed = $parser->parse();
  my $errors = $parsed->{errors};
  my $columns = $parsed->{columns};
  my $data = $parsed->{data};
  my $values = $parsed->{values};

OVERRIDE FILE TYPE:
  - The plugin used to read the data file is chosen based on the file's extension
  - This can be overridden by manually specifying the type in the class constructor

  my $parser = CXGN::File::Parse->new(
    file => '/path/to/data.txt',
    type => 'csv'
  );

SUPPORTED FILE TYPES:
  - excel = MS Excel format, perl module based on type
  - xlsx = New MS Excel Format, alias for excel
  - xls = Old MS Excel Format, alias for excel
  - plain = Plain text format, delimiter based on type
  - csv = Comma-separated file, alias for plain
  - tsv = Tab-separated file, alias for plain
  - txt = Tab-separated file, alias for plain
  - ssv = Semicolon-separated file, alias for plain

REQUIRED COLUMNS:
  - You can include an array of required columns as required_columns
  - The parser will check to make sure those columns are in the file
  - The parser will check to make sure all rows have a value for the required columns
  - The parser will return additional properties:
      - required_columns: an array of columns that are in the data file and are specified as required
      - optional_columns: an array of columns that are in the data file and are not specified as required

  my $parser = CXGN::File::Parse->new(
    file => '/path/to/data.xlsx',
    required_columns => ['accession_name', 'species_name']
  );
  my $parsed = $parser->parse();
  my $errors = $parsed->{errors};
  my $columns = $parsed->{columns};
  my $data = $parsed->{data};
  my $values = $parsed->{values};
  my $required_columns = $parsed->{required_columns};
  my $opional_columns = $parsed->{optional_columns};


OPTIONAL COLUMNS:
  - You can specify the optional columns by including an array as optional_columns
  - When including just the required columns, all other columns are considered optional by default
  - When including both required and optional columns, all other columns are considered 'additional'
  - The parser will return additional properties:
      - required_columns: an array of columns that are in the data file and are specified as required
      - optional_columns: an array of columns that are in the data file and are specified as optional
      - additional_columns: an array of columns that are in the data file and are not specified as required or optional

  my $parser = CXGN::File::Parse->new(
    file => '/path/to/data.xlsx',
    required_columns => ['accession_name', 'species_name'],
    optional_columns => ['variety', 'organization']
  );
  my $parsed = $parser->parse();
  my $errors = $parsed->{errors};
  my $columns = $parsed->{columns};
  my $data = $parsed->{data};
  my $values = $parsed->{values};
  my $required_columns = $parsed->{required_columns};
  my $opional_columns = $parsed->{optional_columns};
  my $additional_columns = $parsed->{additional_columns};

COLUMN ALIASES
  - Alternate column headers can be specified as column_aliases
  - This will replace the alternate name with the preferred name in the final parsed data

  my $parser = CXGN::File::Parse->new(
    file => '/path/to/data.xlsx',
    required_columns => ['accession_name', 'species_name'],
    column_aliases => {
      'accession_name' => [ 'accession', 'name' ],
      'species_name' => [ 'species' ]
    }
  );

COLUMN ARRAYS
  - Specify columns that can include multiple items (separated by a delimiter)
  - The default delimiter is a comma
  - To use the default delimiter, you can specify the columns to parse as an array
  - To specify a different delimiter, you can specify the columns to parse as a hash with the delimiter as the value
  - The returned values in the data hash will be returned as a split array of values

  # to use the default delimiter
  my $parser = CXGN::File::Parse->new(
    file => '/path/to/data.xlsx',
    required_columns => ['accession_name', 'species_name'],
    column_arrays => ['synonym', 'organization_name']
  );

  # to specify the delimiter
  my $parser = CXGN::File::Parse->new(
    file => '/path/to/data.xlsx',
    required_columns => ['accession_name', 'species_name'],
    column_arrays => {
      'synonym' => ';',
      'organization_name' => '&'
    }
  );

CASE SENSITIVITY
  - Column names are case-insensitive for any names provided in required_columns, optional_columns, or column_aliases (known column names)
  - If the file contains a column name in a different case than the known column name, the column name in the file
      will be replaced by the known column name in the final parsed data

=head1 DESCRIPTION

The parse() function will return a hashref with the following properties:

  - errors:
    - an array of error messages, if any were encountered during the parsing
    - this could include errors encountered when trying to read the file
    - the parser will check for required columns and values and return error messages if any are missing

  - columns:
    - an array of all of the column headers in the file

  - data:
    - an array of hashrefs, where each hashref represents one row of data
    - the key in the hashref will be the column header
    - the value in the hashref will be the cell value for that row/column
    - empty cell values will be included in the hashref as undef
    - completely empty rows will be skipped (not included in `data`)
    - a _row property is added to indicate the original row number in the data file, where 1 is the header row

  - values:
    - a hashref containing the unique values in the data file for each column
    - the key of the hashref will be the column header
    - the value of the hashref will be an arrayref of the unique values for that column
    - For example, if you want to get the trial names in a trial upload:
      - $trial_names = $parsed->{values}->{trial_name};

When required_columns is included in the constructor, the parse() function will also return:

  - required_columns:
    - an array of the column headers in the file that are also specified as required

  - optional_columns:
    - an array of the column headers in the file that are not specified as required

When both required_columns and optional_columns are included in the constructor, the parse() function will also return:

  - required_columns:
    - an array of the column headers in the file that are also specified as required

  - optional_columns:
    - an array of the column headers in the file that are also specified as optional

  - additional_columns:
    - an array of the column headers in the file that are neither required nor optional

For example, the trial upload template can specify the required columns (such as trial_name, plot_number, etc),
and the optional columns (such as planting_date, harvest_date, etc).  Any of the 'additional_columns' will
be treated as management factors / treatments.

=head1 PLUGINS

  This Class uses a plugin structure, where a CXGN::File::Parse::Plugin will be used to read the file
  and parse the data into a unified structure.  The plugin MUST provide two functions:

    - type: which returns the file type that the plugin handles (xls, xlsx, csv, tsv, etc)

    - parse(file): which reads the file and parses its contents.  The function should return a hashref with the keys:
      - errors: an arrayref of error messages encountered while reading and parsing the file
      - columns: an arrayref of the column header values
      - data: an arrayref of hashrefs with the individual row data (see notes below)
      - values: a hashref containing the unique values for each column (key = column header, value = arrayref of unique values)

  Some notes on parsing the contents of the file:
    - A `_row` property should be added to each item in `data`.  The value should be the original
      row number from the data file, where row 1 is the header row and row 2 is the first row data.
    - Completely blank rows should be skipped.
    - An empty cell value should be added as undef to the `data` hash.
    - Empty values should not be added to `values`.
    - Required columns and values will be checked by the CXGN::File::Parse->parse() function, so they
      don't need to be checked by the plugin.

=head1 AUTHORS

  David Waring <djw64@cornell.edu>

=cut

use Moose;
use Try::Tiny;
use Module::Pluggable require => 1;
use Data::Dumper;

# Path to the file that is being parsed
has 'file' => (
  isa => "Str",
  is => "ro",
  required => 1
);

# File type, if not provided will use the file path extension to guess
has 'type' => (
  isa => "Str",
  is => "rw"
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

# Map of column aliases, where the key is the preferred column name and the value is an arrayref of alternate names
has column_aliases => (
  isa => "HashRef",
  is => "ro"
);

# Array or Map of column arrays
# If an array, the default demiliter will be used for each specified colum name
# If a hash, they key is the column name and the value is the delimiter used to split the value
has column_arrays => (
  isa => "ArrayRef[Str]|HashRef",
  is => "ro"
);


#
# PROCESS INITIAL ARGUMENTS
# - Flatten the column aliases from 'preferred' => [ 'alt 1', 'alt 2' ] to 'alt 1' => 'preferred', 'alt 2' => 'preferred'
#
sub BUILDARGS {
  my $orig = shift;
  my %args = @_;

  # flatten column aliases to alias = preferred
  if ( $args{column_aliases} ) {
    my %alias_map;
    my $aliases = $args{column_aliases};
    foreach my $pref ( keys %$aliases ) {
      foreach my $alias ( @{$aliases->{$pref}} ) {
        $alias_map{$alias} = $pref;
      }
    }
    $args{column_aliases} = \%alias_map;
  }

  # flatten column arrays to column = delimiter
  if ( $args{column_arrays} ) {
    my %array_map;
    my $v = $args{column_arrays};
    if ( ref($v) eq 'HASH' ) {
      foreach my $k (keys %$v) {
        $array_map{$k} = $v->{$k};
      }
    }
    elsif ( ref($v) eq 'ARRAY' ) {
      foreach my $c (@$v) {
        $array_map{$c} = ',';
      }
    }
    $args{column_arrays} = \%array_map;
  }

  return \%args;
}


# 
# PARSE DATA FILE
# Read the data file and parse it into the uniform format using the appropriate plugin
#
sub parse {
  my $self = shift;
  my $file = $self->file();
  my $type = $self->type();
  my $required_columns = $self->required_columns();
  my $optional_columns = $self->optional_columns();
  my $column_arrays = $self->column_arrays();

  # If type is not defined, use the file extension
  if ( !$type ) {
    ($type) = $file =~ /\.([^.]+)$/;
    $type = 'xls' if !$type;          # set default type to 'xls' if not defined (there are some test files with no extension)
    $self->type($type);
  }

  # Check if the file exists
  if ( !-e $file ) {
    return {
      errors => [ "The file $file does not exist" ]
    };
  }

  # Find the appropriate parser plugin
  my $parser;
  foreach my $p ($self->plugins()) {
    if ( $type eq $p->type() ) {
      $parser = $p;
    }
  }

  # Plugin found, use it to parse the file
  if ( $parser ) {

    # Parse the file with plugin
    my $parsed;
    my $error;
    try {
      $parsed = $parser->parse($self);
    } catch {
      $error = "Encountered error while reading and parsing file: $_";
    };
    if ( $error ) {
      return {
        errors => [ $error ]
      };
    }

    # Get parsed columns and row data
    my $errors = $parsed->{errors};
    my $columns = $parsed->{columns};
    my $data = $parsed->{data};

    # Return if parsing errors
    if ( scalar(@$errors) > 0 ) {
      return {
        errors => $errors
      };
    }

    # Check for empty files with no data
    if ( scalar(@$columns) < 1 || scalar(@$data) < 1 ) {
      return {
        errors => [ "The file has no data" ]
      };
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

      # Check the data for missing required values
      foreach my $d (@$data) {
        foreach my $c ( @{$parsed->{required_columns}} ) {
          my $v = $d->{$c};
          if ( !defined($v) || $v eq '' ) {
            my $r = $d->{_row};
            push @{$parsed->{errors}}, "Required column $c does not have a value in row $r";
          }
        }
      }

    }

    # Add columns that are arrays, as defined in the CXGN::File::Parse constructor
    my @array_columns = keys %$column_arrays if $column_arrays;
    $parsed->{'array_columns'} = \@array_columns || [];

    return $parsed;
  }

  # No parser plugin found for file type
  else {
    return {
      errors => [ "No appropriate file parsing plugin for file: $file, type: $type" ]
    };
  }
}

#
# CLEAN HEADER
# - clean the header value
# - check for case-insensitive matches of required and optional columns
# - check for case-insensitive matches of column aliases
#
sub clean_header {
  my $self = shift;
  my $header = shift;

  if ( $header ) {
    my $required_columns = $self->required_columns();
    my $optional_columns = $self->optional_columns();
    my $column_aliases = $self->column_aliases();

    # Do usual value cleaning
    $header = $self->clean_value($header);

    # check for case-insensitive required column match
    if ( $required_columns ) {
      foreach my $col (@$required_columns ) {
        $header = $col if ( uc($col) eq uc($header) );
      }
    }

    # check for case-insensitive optional column match
    if ( $optional_columns ) {
      foreach my $col (@$optional_columns ) {
        $header = $col if ( uc($col) eq uc($header) );
      }
    }

    # check for case-insensitive column alias
    if ( $column_aliases ) {
      foreach my $alias ( keys(%$column_aliases) ) {
        $header = $column_aliases->{$alias} if ( uc($alias) eq uc($header) );
      }
    }
  }

  return $header;
}

#
# CLEAN VALUE
# - remove leading & trailing whitespace
# - split column arrays
#
sub clean_value {
  my $self = shift;
  my $value = shift;
  my $column = shift;
  my $column_arrays = $self->column_arrays();

  if ( defined($value) && $value ne '' ) {

    # trim whitespace
    $value =~ s/^\s+|\s+$//g;

    # trim unicode no-break space
    $value =~s/\xa0//g;

    # split values
    if ( $column && $column_arrays && exists $column_arrays->{$column} ) {
      my $delim = $column_arrays->{$column};
      my @values;
      foreach my $v (split($delim, $value) ) {
        $v =~ s/^\s+|\s+$//g;
        push(@values, $v);
      }
      $value = \@values;
    }

  }

  return $value;
}

1;
