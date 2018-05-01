
package CXGN::Blast::Parse::Plugin::BioPerlBlastParser;

use Moose;

use English;
use HTML::Entities;
use List::MoreUtils 'minmax';
use Bio::SeqIO;
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;
use CXGN::Tools::Identifiers;
use File::Slurp qw | read_file |;

use constant MAX_FORMATTABLE_REPORT_FILE_SIZE => 2_000_000;

sub name { 
    return "Bioperl";
}

sub prereqs { 

    # stuff to support AJAXy disambiguation of site xrefs
return <<EOJS;

<div class="modal fade" id="xref_menu_popup" role="dialog">
  <div class="modal-dialog">
  
    <!-- Modal content-->
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal">&times;</button>
        <h4 class="modal-title">Match Information</h4>
      </div>
      <div class="modal-body">
        <dl>
          <dt>Hit region <span class="region_string"></span></dt>
            <dd>
              <div style="margin: 0.5em 0"><a class="match_details" href="" target="_blank">View matched sequence</a></div>
              <div class="hit_region_xrefs"></div>
            </dd>
          <dt>Subject sequence <span class="sequence_name"></span></dt>
            <dd class="subject_sequence_xrefs">
            </dd>
        </dl>
      </div>
    </div>
    
  </div>
</div>


<script>

  function resolve_blast_ident( id, id_region, match_detail_url, identifier_url ) {
    var popup = jQuery( "#xref_menu_popup" );

    var sequence_name = popup.find('.sequence_name');
    if( identifier_url == null ) {
       sequence_name.html( id );
    } else {
       sequence_name.html( '<a href="' + identifier_url + '" target="_blank">' + id + '</a>' );
    }

    popup.find('.region_string').html( id_region );

    popup.find('a.match_details').attr( 'href', match_detail_url );

    // look up xrefs for overall subject sequence
    var subj = popup.find('.subject_sequence_xrefs');
    subj.html( '<img src="/img/throbber.gif" /> searching ...' );
    subj.load( '/api/v1/feature_xrefs?q='+id );

    // look up xrefs for the hit region
    var region = popup.find('.hit_region_xrefs');
    region.html( '<img src="/img/throbber.gif" /> searching ...' );
    region.load( '/api/v1/feature_xrefs?q='+id_region );

    popup.modal("show");

    return false;
  }

</script>

EOJS

}

sub parse { 
    my $self = shift;
    my $c = shift;
    my $raw_report_file = shift;
    my $bdb = shift;

    # check if $raw_report_file exists
    unless (-e $raw_report_file) {
        my $error = "BLAST results are automatically deleted after 7 days. You may need to run your BLAST again. "
            . "If you feel you received this message in error, please <a href='/contact/form'>contact us</a>.";
	return { file => '',
		 error => $error,
	};
    }
    
    
    #don't do any formatting on report files that are huge
    if (-s $raw_report_file > MAX_FORMATTABLE_REPORT_FILE_SIZE) { 
	print STDERR "raw report too large ".(-s $raw_report_file)."\n";
	return read_file($raw_report_file);
    }

    print STDERR "Starting to format BLAST report...\n";

    my $formatted_report_file = $raw_report_file.".formatted.html";
    
    #for smaller reports, HTML format them
    my %bioperl_formats = ( 0 => 'blast', #< only do for regular output,
                            #not the tabular and xml, even
                            #though bioperl can parse
                            #these.  if people choose
                            #these, they probably don't
                            #want bioperl to munge it.
	);

    
    sub linkit {
        my $bdb = shift;
        my $s = shift;

        $s =~ s/^lcl\|//;
        my $url = $bdb->lookup_url || CXGN::Tools::Identifiers::identifier_url($s);
	print STDERR "CHECKING ID $s FOR URL... found $url\nLOOKUPURL: ".$bdb->lookup_url."\n".CXGN::Tools::Identifiers::identifier_url($s)."\n";
        return qq { <a class="blast_match_ident" href="$url">$s</a> };
    }
    
    
    print STDERR "Parse file $raw_report_file using bioperl...\n";
    my $in = Bio::SearchIO->new(-format => 'blast', -file   => "< $raw_report_file")
	or die "$! opening $raw_report_file for reading";
    my $writer = $self->make_bioperl_result_writer( $bdb->blast_db_id() );
    my $out = Bio::SearchIO->new( -writer => $writer,
				  -file   => "> $formatted_report_file",
	);
    $out->write_result($in->next_result);
    
    # open my $raw,$raw_report_file
    # 	or die "$! opening $raw_report_file for reading";
    # open my $fmt,'>',$formatted_report_file
    # 	or die "$! opening $formatted_report_file for writing";
    
    # print $fmt qq|<pre>|;
    # while (my $line = <$raw>) {
    # 	$line = encode_entities($line);
    # 	$line =~ s/(?<=Query[=:]\s)(\S+)/linkit($bdb,$MATCH)/eg;
    # 	print $fmt $line;
    # }
    # print $fmt qq|</pre>\n|;
    
    print STDERR "FORMATTED BLAST REPORT AVAILABLE AT: $formatted_report_file\n";

    return read_file($formatted_report_file);
}

sub make_bioperl_result_writer {
    my $self = shift;
    my $db_id = shift;

    my $writer = Bio::SearchIO::Writer::HTMLResultWriter->new;
    
    $writer->id_parser( sub {
	my ($idline) = @_;
	my ($ident,$acc) = Bio::SearchIO::Writer::HTMLResultWriter::default_id_parser($idline);
	
	# The default implementation checks for NCBI-style identifiers in the given string ('gi|12345|AA54321').
	# For these IDs, it extracts the GI and accession and
	# returns a two-element list of strings (GI, acc).
	
	return ($ident,$acc) if $acc;
	return CXGN::Tools::Identifiers::clean_identifier($ident) || $ident;
    });
    
    my $hit_link = sub {

	my ($self, $hit, $result) = @_;

  # print STDERR "HIT LINK: $hit->name, $result\n";

	my $id = $hit->name;
	
	#see if we can link it as a CXGN identifier.  Otherwise,
	#use the default bioperl link generat	
	my $identifier_url = CXGN::Tools::Identifiers::identifier_url( $id );
	my $js_identifier_url = $identifier_url ? "'$identifier_url'" : 'null';
	
	my $region_string = $id.':'.join('..', minmax map { $_->start('subject'), $_->end('subject') } $hit->hsps );
	
	my $coords_string =
	    "hilite_coords="
	    .join( ',',
		   map $_->start('subject').'-'.$_->end('subject'),
		   $hit->hsps,
	    );
	
	my $match_seq_url = "/tools/blast/match/show?blast_db_id=$db_id;id=$id;$coords_string";
	
	my $no_js_url = $identifier_url || $match_seq_url;
	
	return qq{ <a class="blast_match_ident" href="$no_js_url" onclick="return resolve_blast_ident( '$id', '$region_string', '$match_seq_url', $js_identifier_url )">$id</a> };
	
    };
    $writer->hit_link_desc(  $hit_link );
    $writer->hit_link_align( $hit_link );
    $writer->start_report(sub {''});
    $writer->end_report(sub {''});
    return $writer;
}

1;
