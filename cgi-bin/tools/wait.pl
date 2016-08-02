
use strict;
use Storable qw / retrieve /;
use File::Temp qw / tempfile /;
use File::Copy;
use File::Basename qw / basename /;

use Cwd qw/ realpath /;
use File::Spec::Functions;
use File::NFSLock qw/uncache/;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ page_title_html blue_section_html /;
use CXGN::Tools::Run;

use CatalystX::GlobalContext qw( $c );

my $page = CXGN::Page->new("Generic SGN Cluster Job Waiting Page", "Lukas");

#extra_params added since I couldn't prevent encoding/decoding merges
# format: param1:value1::param2:value2::etc3:v3  
# this adds parameters to the redirect page

my ($tmp_app_dir, $job_file, $redirect, $out_file_override, $extra_params) 
	= $page->get_arguments("tmp_app_dir", "job_file", "redirect", "out_file_override", "extra_params");

if( $out_file_override ) {
    $out_file_override = realpath( $out_file_override );

    print STDERR "OUTFILE: $out_file_override\n";
    $out_file_override =~ m!/(data|export)/(prod|shared)|(/tmp)! && $out_file_override !~ /\.\./
        or die "is someone trying to do something nasty? illegal out_file_override '$out_file_override'";
}

my ($message) = $page->get_arguments("message");


my $d = CXGN::Debug->new;

$tmp_app_dir =~ s!/!!g;
my $tmpdir = $page->path_to( $page->tempfiles_subdir($tmp_app_dir) );

$job_file = catfile($tmpdir,$job_file);

$d->d("Arguments: job_file = $job_file redirect = $redirect");

unless( -f $job_file ) {
  $c->throw( message => "Job not found.  Has it already been executed and the results retrieved?",
             is_error => 0,
             developer_message => "Job file was '$job_file'\n",
            );
}


my $job = retrieve($job_file)
  or die "Could not retrieve job_file $job_file";

if ( $job->alive ){
    display_not_finished($message);
    return;
}
else {
    # the job has finished
    # copy the cluster temp file back into "apache space"
    #
    my (undef, $apache_temp) = tempfile( DIR=>$tmpdir,
                                         TEMPLATE=>"alignXXXXXX",
                                       );

    $d->debug("COPY --> OUTFILE: ".$job->out_file()." Apache temp: $apache_temp");

    my $job_out_file = $job->out_file();
    for( 1..10 ) {
      uncache($job_out_file);
      last if -f $job_out_file;
      sleep 1;
    }

    -f $job_out_file or die "job output file ($job_out_file) doesn't exist";
    -r $job_out_file or die "job output file ($job_out_file) not readable";
    -w $apache_temp  or die "apache temp directory doesn't exist or not writable - won't copy";

    # You may wish to provide a different output file to send back
    # rather than STDOUT from the job.  Use the out_file_override
    # parameter if this is the case.
    my $out_file = $out_file_override || $job->out_file();
    system("ls /data/prod/tmp 2>&1 >/dev/null");
    copy($out_file, $apache_temp)
        or die "Can't copy result file '$out_file' to temp dir $!";

    #clean up the job tempfiles
    $job->cleanup();

    #also delete the job file
    unlink $job_file;


    my $redirect_string = $redirect . basename( $apache_temp );
	
    $page->client_redirect($redirect_string);
}


sub display_not_finished { 

	my $message = shift;
	$message ||= "Job running, please wait.";

    print <<HTML;
Content-type: text/html

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<title>Job running</title>
<meta http-equiv="Refresh" content="3" />
<link rel="stylesheet" href="/css/sgn.css" type="text/css" />
</head>
<body>
    <style>
      body { padding-top: 80px }
      img, div, h2 {
        display: block;
        margin: 1em auto;
        text-align: center;
      }
    </style>
    <img src="/img/sgn_logo_animated.gif" alt="SGN logo"/>
    <h2>$message</h2>
    <div>Please note: jobs are limited to 1 hour of run time.</div>
    <img src="/img/progressbar1.gif" alt="In Progress..."/>
</body>
</html>
HTML

}

sub display_finished { 
    my $link = shift;

    my $title = page_title_html("Job completed.");

    $page->header();

    print <<HTML;
    <br /><br />
    $title
<center>

<br />
<a href="$link"><b>View Result</b></a>
<br /><br /><br />
</center>

<!--    Debug info: -->
<!--  -->

<br /><br /><br /><br />
HTML

$page->footer();
}
