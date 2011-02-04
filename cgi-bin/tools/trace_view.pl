use strict;
use warnings;

use CXGN::Page;
use CXGN::Chromatogram;
use URI::Escape;
use CatalystX::GlobalContext '$c';

my $page = CXGN::Page->new( "Chromatogram viewer", "john" );
my ( $file, $temp ) = $page->get_encoded_arguments( 'file', 'temp' );
if ($file) {

#do not accept files specified with /. because that might be an attempt to view some other file that they
#are not allowed to view
    if ( $file =~ /\/\./ ) {
        $page->message_page( 'Invalid file location.',
            '', '', "Invalid file location: $file" );
    }

    #if it's a tempfile, look in the tempfile location
    if ($temp) {
        $file =~ /^[\w\-]+\.mct$/
          or $page->message_page( 'Invalid file location.',
            '', '', "Invalid file location: $file" )
          ; #i made up the extension 'mct' for 'mystery chromatogram type' since we have various kinds of chromatograms and nothing recorded about their file types. --john
        $file =
            $c->config->{'basepath'}
          . $c->config->{'tempfiles_subdir'}
          . '/traceimages/'
          . $file;
    }

    #otherwise it will be in data shared
    else {
        my $data_shared_url = $c->config->{'static_datasets_url'};
        my $data_shared_website_path =
          $c->config->{'static_datasets_path'};

        #find cosii chromatogram
        if ( $file =~ /^$data_shared_url\/cosii2?\/[\w\-\/]+\.ab1$/ ) {
            $file =~ s/$data_shared_url/$data_shared_website_path/;
        }

        #or find pgn chromatogram
        elsif ( $file =~ /trace_files/ ) {
            $file =~
s/trace_files/data\/prod\/public\/pgn_data_processing\/processed_traces\//;
        }

        #or give up
        else {
            $page->message_page( 'Invalid file location.',
                '', '', "Invalid file location: $file" );
        }
    }

    my $temp_image_filename;
    if ( $file =~ /([\w\-\.]+)\.\w+$/ ) {
        $temp_image_filename = $1;
    }
    else {
        $page->message_page( 'Invalid file location.',
            '', '', "Invalid file location: $file" );
        print STDERR
          "/cgi-bin/tools/trace_view.pl: invalid file location: $file\n";
    }

    my $display_pngfile;
    if ( -f ($file) ) {
        if ( CXGN::Chromatogram::is_abi_file($file) ) {
            $display_pngfile = CXGN::Chromatogram::create_image_file( $file,
                "$temp_image_filename.png" );
        }
        else {
            my $uncompressed_file =
                $c->config->{'basepath'}
              . $c->config->{'tempfiles_subdir'}
              . "/traceimages/$temp_image_filename"
              . "_uncompressed";
            CXGN::Chromatogram::uncompress_if_necessary( $file,
                $uncompressed_file );
            if ( CXGN::Chromatogram::is_abi_file($uncompressed_file) ) {
                $display_pngfile =
                  CXGN::Chromatogram::create_image_file( $uncompressed_file,
                    "$temp_image_filename.png" );
            }
            else {
                $page->message_page(
'Sorry, but the viewer does not support this type of chromatogram file.'
                );
            }
        }
    }
    else {
        $page->message_page( 'Invalid file location.',
            '', '', "Chromatogram file not found at $file" );
        print STDERR
          "/cgi-bin/tools/trace_view.pl: invalid file location: $file\n";
    }

    #create the page
    $page->header("Chromatogram viewer: $temp_image_filename");
    print
"<center><h4>$temp_image_filename</h4></center><img src=\"$display_pngfile\" border=\"0\">";
    $page->footer();
}
else {
    $page->message_page('Invalid arguments.');
}
