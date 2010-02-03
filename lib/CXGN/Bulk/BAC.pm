use strict;
use warnings;

package CXGN::Bulk::BAC;
use CXGN::Genomic::Clone;
use CXGN::Genomic::CloneIdentifiers;
use CXGN::Genomic::Library;
use CXGN::Tools::List qw/any/;

use base "CXGN::Bulk";

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    #debug start#
    my $paramhash = $_[0];
    $self->debug("ID String from BAC.pm constructor");
    $self->debug("ids_string is " . $paramhash->{ids_string});
    #debug end#

    return $self;
}





our @field_list = qw(
		     chr_clone_name
		     cornell_clone_name
		     arizona_clone_name
		     clone_type
		     org_name
		     accession_name
		     library_name
		     estimated_length
		     genbank_accession
		    );

sub process_parameters
{
    my $self = shift;

    return 0
      unless length($self->{ids_string}) <= 1_000_000 && $self->{ids_string} =~ /\w/;

    $self->{output_fields} = [grep $self->{$_} eq 'on', @field_list];

    # clean up data retrieved
    my $ids = $self->{ids_string};
    $ids =~ s/[\n\s\r]+/ /g;
    my @ids = grep $_, split /\s+/, $ids;
    return 0 if @ids > 10_000; #limit to 10_000 ids to process
    return 0 unless any(@ids);

    $self->{ids} = \@ids;

    return 1; #params were OK if we got here
}

sub process_ids
{
    my $self = shift;
    $self -> {query_start_time} = time();
    my $dbh = $self->{db};
    my @output_fields = @{$self -> {output_fields}};
    my @notfound = ();
    my @return_data = ();
    my ($dump_fh, $notfound_fh) = $self -> create_dumpfile();
    my @bac_output;
    my $current_time= time() - $self -> {query_start_time};
    $self->debug("Time point 1: $current_time");

    my $foundcount=0;
    my $notfoundcount=0;
    my $count=0;

    # iterate through identifiers
    foreach my $id (@{$self->{ids}}) {
      $count++;

      my $clone = CXGN::Genomic::Clone->retrieve_from_clone_name($id);

      #ask rob if parser should choke when given zero
      unless ($clone) {
	print $notfound_fh (">$id\n");
	next;
      }
      my $lib = $clone->library_object;

      # get organism name and accession
      my (undef, $oname, $cname) = $lib->accession_name();

      my %data;
      @data{@field_list} = ($clone->clone_name_with_chromosome || '',
			    $clone->cornell_clone_name || '',
			    $clone->clone_name,
			    $clone->clone_type_object->name,
			    $oname,
			    $cname,
			    $lib->name,
			    $clone->estimated_length,
			    $clone->genbank_accession,
			   );
      my @dump_fields = grep $self->{$_},@field_list;
	
      print $dump_fh join("\t", @data{@dump_fields})."\n";

    }
    $current_time = time() - $self->{query_start_time};
    $self->debug("Time point 2: $current_time");
    close $dump_fh;
    close $notfound_fh;

    $self->{foundcount}= $foundcount;
    $self->{notfoundcount}= $notfoundcount;
    $current_time = time() - $self->{query_start_time};
    $self->{query_time} = time() - $self -> {query_start_time};
    $self->debug("Time point 3: $current_time");
}

1;
