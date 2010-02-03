# Unigene ID's of  Unigene download script for SGN database

# This bulk download option handles the query 
# Of Array Spot of type EST.
# Many of its methods are in the Bulk object.

=head1 NAME

  /CXGN/Bulk/UnigeneIDUnigene.pm
  (A subclass of Bulk)

=head1 DESCRIPTION

  This perl script is used on the bulk download page. The script collects
  identifiers submitted by the user and returns information based on the
  Unigene ID's for  Unigene entered. It then determines the information the 
  user is searching for (SGN_U, Build Number, Automatic Annotation and
  Unigene Sequence) and performs the appropriate querying of the 
  database. The results of the database query are formated and presented
  to the user on a separate page. Options of viewing or downloading
  in text or fasta are available.

=cut

package CXGN::Bulk::UnigeneIDUnigene;
use strict;
use warnings;

use CXGN::Bulk;
use CXGN::Transcript::Unigene;
use CXGN::Transcript::CDS;
use CXGN::Phenome::Locus;

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

    my %links = (SGN_U  => "/search/unigene.pl?unigene_id=",);

    $self->{links} = \%links;
    my @output_fields = ();

    $self->debug("Type of identifier: ".($self->{idType})."");

    # @output_fields is the sub-set of fields that will actually be output.

    my @output_list = qw(
			 automatic_annotation
			 evalue
			 best_genbank_match
			 best_arabidopsis_match
			 associated_loci
			);

    if(my $value = $self->{convert_to_current})
    {
	if ($value eq "on")
	{
	    push @output_fields, 'input_unigene';
	}
    }

    #check condition for SGN_U
    if(my $value = $self->{SGN_U_U})
    {
	if ($value eq "on")
	{
	    push @output_fields, 'SGN_U';
	}
    }

    #then check for rest of fields
    foreach my $o (@output_list)
    {
	if (my $value =  $self->{$o}) {
	    if ($value eq "on")
	    {
		push @output_fields, $o;
	    }
	}
    }

    if ($self->{uni_seq} eq "on") {push @output_fields, $self->{seq_mode}; }

    $self->{output_list} = \@output_list;
    $self->{output_fields} = \@output_fields;

    my @ids = $self ->check_ids();
    if (@ids == ()) {return 0;}
    $self->debug("IDs to be processed:");
    my $has_valid_id = 0;

    foreach my $i (@ids)
    {
      $self->debug($i);
      if ($self -> {idType} =~ /unigene/)
      {
	$i =~ s/^.*?(\d+).*?$/$1/;
      }
      if(!($i =~ m/\d+/))
      {
          $i = "";
      }
      if ($i ne "")
      {
          $has_valid_id = 1;
      }
    }
    if(!$has_valid_id) {
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

sub process_ids {
    my $self = shift;

    my $db = $self->{db};
    my @output_fields = @{$self -> {output_fields}};
    my @notfound = ();
    my ($dump_fh, $notfound_fh) = $self -> create_dumpfile();
    my $current_time= time(); # - $self -> {query_start_time};
    $self->debug("Time point 6: $current_time");

    $self -> {query_start_time} = time();

    my @u_ids = sort {$a<=>$b} @{$self->{ids}};
    if( $self->{convert_to_current} ) {
	@u_ids = $self->convert_to_current( \@u_ids, $notfound_fh );
    }

    for my $u_id ( @u_ids ) {

	my $input_unigene; #< only used if converting to current
	if( ref $u_id ) {
	    ( $u_id, $input_unigene ) = @$u_id;
	}
	
	(print $notfound_fh "$u_id\n" and next)	if($u_id > 2147483647);

	my $unigene = CXGN::Transcript::Unigene->new($db, $u_id) or (print $notfound_fh "$u_id\t(not found in database)\n" and next);

	my $cds = CXGN::Transcript::CDS->new_with_unigene_id($db, $u_id);

	my @return_data;
	for my $field (@output_fields){
	    if($field eq "SGN_U"){
		push (@return_data,"SGN-U".$unigene->get_unigene_id());
	    }
	    elsif($field eq "automatic_annotation"){
		my @annotations = $unigene->get_annotations(1);
		if(@annotations){
		    my @temp;
		    for my $index (0..4){
			if($annotations[$index]){
			    for my $anno ($annotations[$index]){
				my @annotation_list = @$anno;
				my($evalue, $annotation) = @annotation_list[2,7];
				if($index == 0){
				    push(@temp, "MATCHED ".$annotation."(evalue: $evalue )");
				}
				else {
				    push(@temp, "AND MATCHED ".$annotation." (evalue: $evalue)");
				}
			    }
			}
		    }
		    push(@return_data, join(" ", @temp));
		}else{
		    push(@return_data, "None.");
		}
	    }
	    elsif($field eq "best_genbank_match"){
		my @annotations = $unigene->get_genbank_annotations();
		if(@annotations){
		    my($blast_db_id, $seq_id, $evalue, $score, $identities, $start_coord,  $end_coord,  $annotation) = @{$annotations[0]};
		    push(@return_data, $seq_id." (".$evalue.")");
		}else{
		    push(@return_data, "None.");
		}
	    }
	    elsif($field eq "best_arabidopsis_match"){
		my @annotations = $unigene->get_arabidopsis_annotations();
		if (@annotations) { 
		    my ($blast_db_id, $seq_id, $evalue, $score, $identities, $start_coord,  $end_coord,  $annotation) = @{$annotations[0]};
		    push(@return_data, $seq_id . " (".$evalue.")"); 
		}else{
		    push(@return_data, "None.");
		}
	    }
	    elsif($field eq "associated_loci"){
		if( my @associated_loci = $unigene->get_associated_loci()) {
		    my @loci;
		    for my $locus (@associated_loci) {
			push(@loci, $locus->get_locus_symbol());
		    }
		    push(@return_data, join " ", @loci);
		}
		else {push(@return_data, "None.");}
	    }
	    elsif($field eq "unigene_seq"){
		push(@return_data, $unigene->get_sequence()) or push(@return_data, "None.");
	    }
	    elsif($field eq "estscan_seq"){
		my $cds_seq = $cds->get_protein_seq();
		push(@return_data, $cds_seq) or push(@return_data, "None.");
	    }

            # TODO: This needs to be fixed up.
	    elsif($field eq "longest6frame_seq"){

		my $filename = $self->{tempdir}."/longest6frameseq";

		open (FASTA_WRITER, ">$filename") or die "cannot open $filename: $!\n";
		print FASTA_WRITER ">lcl|identifier\n".$unigene->get_sequence();
		close FASTA_WRITER;

		my $returnCode = system("get_longest_protein.pl $filename");

		if ( $returnCode != 0 ) { 
		    die "Failed executing get_longest_protein.pl: $returnCode: $!\n";    
		}

		open PROTEIN_READER, "$filename.protein" or die "cannot open $filename.protein: $!\n";
		my $sequence;
		while(<PROTEIN_READER>){
		    chomp($sequence .= $_) unless(/^>/);
		}
		push(@return_data, $sequence) or  push(@return_data, "None.");
	    }
	    elsif($field eq "preferred_protein_seq"){
	        if(my $cds_id = $unigene->get_preferred_protein()){
		    my $cds2 = CXGN::Transcript::CDS->new($db, $cds_id);
		    my $preferred = $cds2->get_protein_seq();
		    push(@return_data, $preferred); 
		}else{
		    push(@return_data, "None.");
		}
	    }
	    elsif( $field eq 'input_unigene' ) {
		push @return_data, "SGN-U$input_unigene";
	    }
	}
        print $dump_fh (join "\t", @return_data)."\n";
    }
    close($dump_fh);
    close($notfound_fh);

    $self->{query_time} = time() - $self -> {query_start_time};

    # my $in_ids = 'IN ('.join(',',(map {$db->quote($_)} @{$self->{ids}})).')'; #makes fragment of SQL query
#     my $query = get_query($in_ids);

#     warn "using query \n",$query;

#     my $sth = $db -> prepare($query);

#     $self -> {query_start_time} = time();
#     $sth -> execute();
#     $current_time = time() - $self->{query_start_time};

#     # execute the query and get the data.
#     while (my $row = $sth -> fetchrow_hashref()) {
#       # crop est_seq if qc_report data is available

#       if ( defined($row->{start}) && defined($row->{length}) ) {
# 	my $start = $row->{start};
# 	my $length = $row->{length};
# 	$row->{"est_seq"}=substr($row->{est_seq}, $start, $length);
#       }

#       $row->{sgn_u}="SGN-U$row->{sgn_u}" if defined($row->{sgn_u});

#       # if the required unigene seq does not exist (because it is a singlet) replace
#       # it with the cropped est sequence.
#       if ($row->{unigene_seq} eq "") {
# 	$row->{unigene_seq} = $row->{est_seq};
#       }

#       @return_data = map ($row->{lc($_)}, @{$self -> {output_fields}});
#       # the pesky manual annotation field contains carriage returns!!!
#       foreach my $r (@return_data) {
# 	$r =~ s/\n//g;
#       }
      
#       print STDERR "^^^^^^^^^^^^^^^^^^^^^^^UNIGENE ID UNIGENE:".(join "\t", @return_data)."\n\n"; 
#       print $dump_fh (join "\t", @return_data)."\n";
#     }
#     close($notfound_fh);
#     close($dump_fh);

#    $self->{query_time} = time() - $self -> {query_start_time};

}


# returns list as [ new_unigene_id, old_unigene_id ], ...
# if the unigene is current, old and new will be the same id
sub convert_to_current {
    my ( $self, $uids, $notfound_fh ) = @_;

    my @current_uids;
    foreach my $uid (@$uids) {
	if( my $unigene = CXGN::Transcript::Unigene->new( $self->{db}, $uid) ) {
	    my $unigene_build = CXGN::Transcript::UnigeneBuild->new( $self->{db}, $unigene->get_build_id );
	    if( $unigene_build->get_status eq 'C' ) {
		push @current_uids, [$uid,$uid];
	    } else {
		if( my @curr = $unigene->get_current_unigene_ids ) {
		    push @current_uids, map [$_,$uid], @curr;
		} else {
		    print $notfound_fh "$uid\t(no equivalent in current build)\n";
		}
	    }
	}
    }

    return @current_uids;
}

=head2 get_query

  Desc: 
  Args: default;
  Ret : data from database printed to a file;

  Queries database using SQL to obtain data on Bulk Objects using formatted
  IDs.

=cut

# sub get_query
# {
#        my $in_ids = shift;
#        return <<EOSQL
# SELECT DISTINCT ON (unigene.unigene_id)
#         unigene.unigene_id as SGN_U,
# 	unigene_build.build_nr as build_nr,
# 	unigene_consensi.seq as unigene_seq,
#         est.seq as est_seq,
# 	cds.protein_seq,
#         (SELECT array_to_string(array(SELECT 'MATCHED '
#                                              || dl.defline
#                                              || ' (evalue:'
#                                              || bh.evalue
#                                              || ')'
#                                       FROM blast_annotations as ba
#                                       JOIN blast_hits as bh USING(blast_annotation_id)
#                                       JOIN blast_defline as dl USING(defline_id)
#                                       WHERE ba.apply_id=unigene.unigene_id
# 					AND ba.blast_target_id=1
#                                         AND ba.apply_type=15
# 	                              LIMIT 5
#                                      ),
#                                 ' AND ')
#         ) as automatic_annotation,
# 	(SELECT target_db_id  FROM blast_annotations  join blast_hits using(blast_annotation_id) WHERE (blast_target_id=1) AND  (apply_id=unigene.unigene_id) AND blast_annotations.apply_type=15 order by score desc limit 1) as best_genbank_match,
# 	(SELECT target_db_id FROM blast_annotations join blast_hits using(blast_annotation_id) WHERE (blast_target_id=2) AND (apply_id=unigene.unigene_id) AND blast_annotations.apply_type=15 order by score desc limit 1) as best_arabidopsis_match
	

# FROM unigene
# LEFT JOIN unigene_consensi USING(consensi_id)
# LEFT JOIN unigene_build USING(unigene_build_id)
# LEFT JOIN unigene_member USING(unigene_id)
# LEFT JOIN cds ON (unigene.unigene_id=cds.unigene_id)
# LEFT JOIN est USING(est_id)
# WHERE unigene.unigene_id $in_ids
# ORDER BY unigene.unigene_id
# EOSQL
# }

1;
