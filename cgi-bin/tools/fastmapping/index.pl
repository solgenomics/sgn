use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ blue_section_html page_title_html /;

use File::Temp;
use File::Basename;

use IPC::Cmd 'run';

use Path::Class;

use CatalystX::GlobalContext '$c';

my $vhost = $c;

my ($upload_temp,$upload_temp_uri) = $c->tempfile( TEMPLATE => [ 'fastmapping', 'fastmap-XXXXXX' ] );

# get a new page object and the rest of the parameters
#
our $page = CXGN::Page->new('index.html','FastMapping',);

# get an upload object to upload a file
#

if( my $upload = $page->get_upload() ) {
    if( my $fh = $upload->fh ) {
        $upload_temp->print($_) while <$fh>;
    }
}
$upload_temp->close;

my $file = $page->get_arguments("file");
my $lg_groups = $page->get_arguments("lg_groups");
my $corelod = $page->get_arguments("corelod");
my $lowlod = $page->get_arguments("lowlod");
my $missingvaluethresh = $page->get_arguments("missingvaluethresh");
my $screening11 = $page->get_arguments("screening11");
my $screening121 = $page->get_arguments("screening121");
my $screening13 = $page->get_arguments("screening13");
my $order = $page->get_arguments("order");
my $skipgrouping =$page->get_arguments("skipgrouping");


# decide what to do - if we have a filename, we can do an analysis,
# otherwise we display the form.
#
if ($file) { 

    if (!check_is_number($lg_groups, $corelod, $lowlod, $missingvaluethresh, $screening11, $screening121, $screening13)) { 
	print_message("Some of the input is incorrect. Please go back and try to fix. Verify that all fields contain
                       valid numbers.");
    }
    else { 
	
	if ($order) { print STDERR "ORDER $order\n";  $order = " -o "; }
	if ($skipgrouping) { print STDERR "SKIPGROUPING: $skipgrouping\n"; $skipgrouping = " -s "; }
	my $fm_bin = $vhost->path_to( $vhost->get_conf('programs_subdir'),
                                      'fast_mapping',
                                    );
        my $matrix_path = $vhost->path_to( $vhost->get_conf('programs_subdir'),
                                      'fast_mapping_matrix.txt',
                                    );
	my $call = "$fm_bin $skipgrouping -c $lg_groups -u $corelod -l $lowlod -v $missingvaluethresh -g $screening11 -h $screening121 -d $screening13 $order  -m $matrix_path $upload_temp";

        $page->header();

        print page_title_html("FastMapping results");

        # no use checking return val or output, program does not respect them
        system($call);
        my $log_file = $vhost->path_to(  $vhost->generated_file_uri
                                         ( 'fastmapping',
                                           'fast_mapping_log.txt'
                                         )
                                      );
        my $result_url = $vhost->uri_for_file($upload_temp.'_map.loc');
        unless( -r $log_file && file($log_file)->slurp =~ /terminating/i ) {
            print "Download the FastMapping results: [<a href=\"$result_url\">Results</a>]<br />\n";
        } else {
            print "<p>Failed to run fastmapping, please check your input data and try again.</p>
                   <p>If this error persists, email the administrators of this site.</p>
                  ";
            if( -r $log_file ) {
                warn "error running fastmapping: \n".file($log_file)->slurp;
            }
        }

        $page->footer();

    }
}
else { 
    print_form();
}


sub print_form { 

    $page->header();
    my $title = page_title_html("FastMapping");

print<<END_HEREDOC;

    $title

FastMapping is a fast mapping program. It requires a file in mapmaker format that you can upload. The results are returned in a tab-delimited file that can be opened in Excel and OpenOffice, using special macros that can be downloaded here. [<a href="help.pl">Help</a>]
<br />
     <br />
     <center>
<form action="index.pl" method="post" enctype="multipart/form-data">
     <table summary="" class="boxbgcolor2" width="100\%">
 
 <tr><td>Upload <a href="help.pl">loc file</a>:</td><td><input type="file" name="file" /></td></tr>
<tr><td colspan="2"><input type="checkbox" name="skipgrouping" /> <a href="help.pl#skipgrouping">Skip grouping</a></td><td></td></tr>
     
<tr><td>     <a href="help.pl#linkage_groups">\# of expected linkage groups</a>:</td><td> <input name="lg_groups" size="5" value="1" /></td></tr>
<tr><td>     <a href="help.pl#corelod">Core LOD:</a> </td><td><input name="corelod" size="5" value="20" /></td></tr>
<tr><td>     <a href="help.pl#lowlod">Low LOD:</a>  </td><td><input name="lowlod" size="5" value="3" /></td></tr>
<tr><td>     <a href="help.pl#missingvaluethresh">Missing value threshold</a>: </td><td><input name="missingvaluethresh" size="5" value="1" /></td></tr>
<tr><td>     <a href="help.pl#screening">1:1 screening threshold</a>: </td><td><input name="screening11" size="5" value="50" /></td></tr>
<tr><td>  <a href="help.pl#screening">1:2:1 screening threshold</a>:</td><td> <input name="screening121" size="5" value="50"  /></td></tr>
<tr><td>  <a href="help.pl#screening">1:3 screening threshold</a>:</td><td> <input name="screening13" size="5" value="50" /></td></tr>
 
<tr><td colspan="2">    <input type="checkbox" name="order" /> <a href="help.pl#order">Order individuals</a></td><td></td></tr>

</table>
<br />
<input type="reset" /> &nbsp; &nbsp; &nbsp; <input type="submit" value="Submit" />
</form>
</center>

END_HEREDOC
$page->footer();


}

sub print_message { 
    my $message = shift;
    $page->header();
    print page_title_html("FastMapping Input Error: ");
    print "$message\n";
    print "<br /><br /><br />";
    $page->footer();
    exit();
}

sub check_is_number { 
    my @numbers = @_;
    foreach my $n (@numbers) { 
	chomp($n);
	if ($n=~/^[^0-9\.e\- ]+/i) {
	    print STDERR "is not number: $n\n";
	    return 0;
	}
    }
    return 1;
}
