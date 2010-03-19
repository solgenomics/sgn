package CXGN::BioTools::SearchIOHTMLWriter;
use strict;
use warnings;

use CXGN::Tools::Identifiers;
use CXGN::BlastDB;

use base qw/Bio::SearchIO::Writer::HTMLResultWriter/;

sub new {
  my ($class,$db_id, @args) = @_;
  my $self = $class->SUPER::new(@args);



  $self->id_parser( sub {
			my ($idline) = @_;
			my ($ident,$acc) = Bio::SearchIO::Writer::HTMLResultWriter::default_id_parser($idline);
                        #The default implementation checks for NCBI-style identifiers in the given string ('gi|12345|AA54321').
                        #For these IDs, it extracts the GI and accession and
                        #returns a two-element list of strings (GI, acc).

			return ($ident,$acc) if $acc;
			return CXGN::Tools::Identifiers::clean_identifier($ident) || $ident;
		      });
  my $hit_link = sub {
    my ($self, $hit, $result) = @_;
    #see if we can link it as a CXGN identifier.  Otherwise,
    #use the default bioperl link generator
    my $url = CXGN::Tools::Identifiers::link_identifier($hit->name())
	|| $self->default_hit_link_desc($hit,$result,$db_id);   

    return $url;
  };
  $self->hit_link_desc($hit_link);
  $self->hit_link_align($hit_link);
  $self->start_report(sub {''});
  return $self;
}

sub end_report {
  return '';
}


sub default_hit_link_desc { 
    my $self = shift;
    my $hit = shift;
    my $result = shift;
    my $db_id = shift;

    my $coords_string = "hilite_coords=";
    while (my $hsp = $hit->next_hsp()) {
	$coords_string .= $hsp->start('subject')."-".$hsp->end('subject').","
    }
    my $id = $hit->name();
    return qq { <a href="show_match_seq.pl?blast_db_id=$db_id&amp;id=$id&amp;$coords_string">$id</a> };


}
    

###
1;#do not remove
###


