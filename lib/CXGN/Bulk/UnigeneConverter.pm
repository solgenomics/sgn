# Unigene Converter download script for SGN database
# Lukas Mueller, August 12, 2003

# This bulk download option handles the query 
# Of Unigene Converting.
# Many of its methods are in the Bulk object.

# Modified July 15, 2005
# Modified more August 11, 2005
# Summer Intern Caroline N. Nyenke

# Modified July 7, 2006
# Summer Intern Emily Hart

# Modified July 3rd, 2007
# Alexander Naydich and Matthew Crumb

=head1 NAME

  /CXGN/Bulk/UnigeneConverter.pm
  (A subclass of Bulk)

=head1 DESCRIPTION

  This perl script is used on the bulk download page. The script collects
  identifiers submitted by the user and returns information based on the
  Unigene ID's for  Unigene converting. It then determines the information the 
  user is searching for (SGN_U, Old Build Number, New Build Number,
  and Convterted Id) and preforms the appropriate querying of the 
  database. The results of the database query are formated and presented
  to the user on a separate page. Options of viewing or downloading
  in text or fasta are available.

=cut

use strict;
use warnings;
use CXGN::Bulk;

package CXGN::Bulk::UnigeneConverter;
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

    my @output_fields = ('SGN_U', 'old_build_nr', 'new_build_nr', 'converted_id');
    my %links = (clone_name =>
             "/search/est.pl?request_type=10&search=Search&request_id=",
		   SGN_U  => "/search/unigene.pl?unigene_id=",
		   converted_id => "/search/unigene.pl?unigene_id=",
		   );

    $self->{output_fields} = \@output_fields;

    my @ids = $self->check_ids();
    return 0 unless @ids;
    $self->debug("IDs to be processed:");
    foreach my $i (@ids) {
	# we want only numbers for unigene and microarray ids.
      	$i =~ s/^.*?(\d+).*?$/$1/;
	if(!($i =~ m/\d+/)){
	    $i = "";
	}
	$self->debug($i);
    }
    my $has_valid_id = 0;
    foreach my $i(@ids){
	if ($i ne ""){
	    $has_valid_id = 1;
	}
    }
    if(!$has_valid_id){
	return 0;
    }
    $self->{ids} = \@ids;

    return 1; #params were OK if we got here
}

=head2 process_query_data

  Desc: 
  Args: default;
  Ret : data from database printed to a file;

  Queries database using SQL to obtain data on Bulk Objects using formatted
  IDs.

=cut

sub process_query_data
{
    my $in_ids = shift;
    #unigene_convert =>
    #sub
    #{
	return <<EOSQL
SELECT distinct old_unigene.unigene_id AS SGN_U,
                old_groups.comment || ' - ' || old_unigene_build.build_nr AS old_build_nr, 
                new_groups.comment || ' - ' || new_unigene_build.build_nr AS new_build_nr,
                'SGN-U' || new_unigene.unigene_id AS converted_id
      FROM groups as old_groups
      JOIN unigene_build AS old_unigene_build ON (old_groups.group_id = old_unigene_build.organism_group_id)
      JOIN unigene AS old_unigene ON (old_unigene.unigene_build_id=old_unigene_build.unigene_build_id)
      JOIN unigene_member AS old_unigene_member ON (old_unigene.unigene_id=old_unigene_member.unigene_id)
      JOIN est ON (old_unigene_member.est_id = est.est_id)
      LEFT JOIN unigene_member AS new_unigene_member ON (est.est_id = new_unigene_member.est_id)
      LEFT JOIN unigene AS new_unigene ON (new_unigene_member.unigene_id = new_unigene.unigene_id)
      LEFT JOIN unigene_build AS new_unigene_build ON (new_unigene.unigene_build_id=new_unigene_build.unigene_build_id)
      LEFT JOIN groups AS new_groups ON (new_unigene_build.organism_group_id=new_groups.group_id)
      WHERE ((new_unigene_build.unigene_build_id = old_unigene_build.latest_build_id) OR (new_unigene_build.unigene_build_id IS NULL))
      AND old_unigene.unigene_id $in_ids
EOSQL
   #},
   #return unigene_convert{$type}($self,$in_ids);
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

    my $db = $self->{db};
    my @output_fields = @{$self -> {output_fields}};
    my @return_data = ();
    my @notfound = ();
    my ($dump_fh, $notfound_fh) = $self -> create_dumpfile();
    # start querying the database
    $self->debug("Time point 6: ".time);

    my $in_ids = 'IN ('.join(',',(map {$db->quote($_)} @{$self->{ids}})).')'; #makes fragment of SQL query
    my $query = process_query_data($in_ids);

    #warn "using query \n",$query;

    my $sth = $db -> prepare($query);

    $self -> {query_start_time} = time();
    $sth -> execute();
    my $current_time = time() - $self->{query_start_time};

    # execute the query and get the data.
    while (my $row = $sth -> fetchrow_hashref()) {
      # crop est_seq if qc_report data is available

      if ( defined($row->{start}) && defined($row->{length}) ) {
	my $start = $row->{start};
	my $length = $row->{length};
	$row->{"est_seq"}=substr($row->{est_seq}, $start, $length);
      }

      $row->{sgn_u}="SGN-U$row->{sgn_u}" if defined($row->{sgn_u});

      @return_data = map ($row->{lc($_)}, @{$self -> {output_fields}});
      # the pesky manual annotation field contains carriage returns!!!
      foreach my $r (@return_data) {
	$r =~ s/\n//g;
      }

      #for testing purposes
      #$self->{query_result_str} = (join "\t", @return_data)."\n";

      print $dump_fh (join "\t", @return_data)."\n";
    }
    close($notfound_fh);
    close($dump_fh);

    $self->{query_time} = time() - $self -> {query_start_time}

}

1;
