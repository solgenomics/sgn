# bulk BAC End Raw download script for SGN database
# Lukas Mueller, August 12, 2003

# This bulk download option handles the query 
# Of BAC Ends of type Raw.
# Many of its methods are in the Bulk object.

# Modified July 15, 2005
# Modified more August 11, 2005
# Summer Intern Caroline N. Nyenke

# Modified July 7, 2006
# Summer Intern Emily Hart

# Modified July 3rd, 2007
# Alexander Naydich and Matthew Crumb

=head1 NAME

  /CXGN/Bulk/BACEndRaw.pm
  (A subclass of Bulk)

=head1 DESCRIPTION

  This perl script is used on the bulk download page. The script collects
  identifiers submitted by the user and returns information based on the
  BAC End Raw Ids entered. It then determines the information the user is
  searching for (Bac Id, Clone Type, Orgonism Name, Accession Name,
  Library Name, Estimated Length, Genbank Accession, Bac End Sequence,
  and Qual Value Sequence) and preforms the appropriate querying of the 
  database. The results of the database query are formated and presented
  to the user on a separate page. Options of viewing or downloading
  in text or fasta are available.

=cut

use strict;
use warnings;
use CXGN::Bulk;
use CXGN::DB::DBICFactory;
use CXGN::Genomic::CloneNameParser;
use CXGN::Genomic::Chromat;
use CXGN::Genomic::GSS;

package CXGN::Bulk::BACEndRaw;
use base "CXGN::Bulk";

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

=head2 process_parameters

  Desc:
  Args: none
  Ret : 1 if the parameters were OK, 0 if not

  Modifies some of the parameters received set in get_parameters. Preparing
  data for the database query.

=cut

sub process_parameters
{
    my $self = shift;

    # @output_list defines the identity on order of all fields that can be output

    my @output_list = ('bac_id', 'clone_type', 'org_name',
                                'accession_name', 'library_name', 'estimated_length',
                                'genbank_accession', 'overgo_matches',
                                'bac_end_sequence', 'qual_value_seq');

    my @output_fields = ();

    $self->debug("Type of identifier: ".($self->{idType})."");

    # @output_fields is the sub-set of fields that will actually be output.
    for my $o (@output_list)
    {
        if (my $value = $self->{$o})
        {
            if ($value eq "on")
            {
            push @output_fields, $o;
            }
        }
    }

    $self->{output_list} = \@output_list;
    $self->{output_fields} = \@output_fields;

    my @ids = $self->check_ids();
    if (@ids == ()) {return 0;}
    $self->debug("IDs to be processed:");
    foreach my $i (@ids)
    {
	$self->debug($i);
    }
    my $has_valid_id = 0;
    foreach my $i(@ids)
    {
	if ($i ne "")
	{
	    $has_valid_id = 1;
	}
    }
    if(!$has_valid_id)
    {
	return 0;
    }
    $self->{ids} = \@ids;

    return 1; #params were OK if we got here
}

=head2 process_ids

  Desc: sub process_ids
  Args: default;
  Ret : data from database printed to a file;

  Queries database using Persistent (see perldoc Persistent) and
  object oriented perl to obtain data on Bulk Objects using formatted
  IDs.

=cut

sub process_ids
{
    my $self = shift;
    $self->{query_start_time} = time();
    my $dbh = $self->{db};
    my $chado = CXGN::DB::DBICFactory->open_schema('Bio::Chado::Schema');
    my @output_fields = @{$self->{output_fields}};
    my @notfound = ();
    my @return_data = ();
    my ($dump_fh, $notfound_fh) = $self->create_dumpfile();
    my @bac_output;
    # time counting
    my $current_time= time() - $self->{query_start_time};
    my $foundcount=0;
    my $notfoundcount=0;
    my $count=0;

    # iterate through identifiers
    foreach my $id (@{$self->{ids}}) {
      $count++;
      my $bac_end_parser = CXGN::Genomic::CloneNameParser->new(); # parse name
      my $parsed_bac_end = $bac_end_parser->BAC_end_external_id ($id);
	
      # parsed clone returns undef if parsing did not succeed
      unless ($parsed_bac_end) {
	print $notfound_fh (">$id\n");
	next;
      }

      #look up the chromat
      my $chromat = CXGN::Genomic::Chromat->retrieve($parsed_bac_end->{chromat_id});
      unless ($chromat) {
	print $notfound_fh (">$id\n");
	next;
      }

      my $clone = $chromat->clone_object;
      my $lib = $clone->library_object;
      my ($gss) = CXGN::Genomic::GSS->search(chromat_id => $chromat->chromat_id,
					     version    => $parsed_bac_end->{version},
					    );
      unless($gss) {
	print $notfound_fh ">$id\n";
	next;
      }

      # get organism name and accession
      my (undef, $oname, $cname) = $lib->accession_name();

      # raw seq and qual value
      my $bacseq = $gss->seq;
      my $qualvalue = $gss->qual;


      print STDERR "GENBANK ACCESSION:". ref($clone->genbank_accession($chado)) ."\n"; 
#       # check which parameters were selected
#       my @use_flags = @{$self}{qw/ bac_id
# 				   clone_type
# 				   org_name
# 				   accession_name
# 				   library_name
# 				   estimated_length
# 				   genbank_accession
# 				   overgo_matches
# 				   bac_end_sequence
# 				   qual_value_seq
# 				   /};

      # will be added soon
      my $bac_id = $chromat->clone_read_external_identifier();
      my $clone_type = $parsed_bac_end->{clonetype};
      my $library_name = $lib->name();
      my $estimated_length = $clone->estimated_length();
      my $genbank_accession = $clone->genbank_accession($chado);
      my $overgo = "overgo";

      my %field_vals = ( "bac_id" => $bac_id,
			 "clone_type" => $clone_type,
			 "org_name" => $oname,
			 "accession_name" => $cname,
			 "library_name" => $library_name,
			 "estimated_length" => $estimated_length,
			 "genbank_accession" =>  $genbank_accession ,
			 "overgo_matches" => $overgo,
			 "bac_end_sequence" =>  $bacseq,
			 "qual_value_seq" => $qualvalue,
					);
      #warn 'made field vals ',join(', ',@field_vals);

      my @data_array = ();

      print STDERR "OUTPUT FIELDS: ". (join "\t", @output_fields)."\n\n";
      foreach my $selected_field (@output_fields) { 
	  print STDERR "PUSHING $selected_field = $field_vals{$selected_field}\n";
	  push @data_array, $field_vals{$selected_field};
      }

#       my @field_vals = map { $_ || '' } ($chromat->clone_read_external_identifier,
# 					 $parsed_bac_end->{clonetype},
# 					 $oname,
# 					 $cname,
# 					 $lib->name,
# 					 $clone->estimated_length,
# 					 $clone->genbank_accession,
# 					 $overgo,
# 					 $bacseq,
# 					 $qualvalue,
# 					);
#       #warn 'made field vals ',join(', ',@field_vals);
#       my @data_array = map { my $val = shift @field_vals;
# 			     $_ ? ($val) : ()
# 			   } @output_fields;
      # warn "information from query: $oname, $cname,\n";

      # print query results to dumpfile
      my $linecolumns = join("\t", @data_array)."\n";
      print $dump_fh $linecolumns ;
      print STDERR "LINE: ". $linecolumns;


    }
    $current_time = time() - $self->{query_start_time};
    close($dump_fh);
    close($notfound_fh);
    $self->{foundcount}= $foundcount;
    $self->{notfoundcount}= $notfoundcount;
    $current_time = time() - $self->{query_start_time};
    $self->{query_time} = time() - $self->{query_start_time};
}

1;
