package SGN::Config;
use base 'CXGN::Config';
my $defaults =
    {

     dbsearchpath             => [qw[
                                     sgn
                                     public
                                     annotation
                                     genomic
                                     insitu
                                     metadata
                                     pheno_population
                                     phenome
                                     physical
                                     tomato_gff
                                  ]],

     #is this a production server?
     production_server        => 0,

     #is there a system message text file somewhere we should be displaying?
     system_message_file      => undef,

     #should we send emails, if we are a production server? this can be used to turn off emails if we are being bombarded.
     bugs_email               => 'sgn-bugs@sgn.cornell.edu',
     disable_emails           => 0,

     #who is the apache user for chowning and emailing
     www_user              => 'www-data',
     www_group             => 'sgn-site-writers',

     #allow people to log in?
     disable_login            => 0,

     # where to run cluster jobs
     web_cluster_queue	      => undef,

     #is this a mirror of SGN, or the real thing?
     is_mirror                => 0,

     #how to find cosii_files for markerinfo.pl
     cosii_files              => '/data/cosii2',

     #log files, ABSOLUTE PATHS
     error_log                => '/var/log/sgn-site/error.log',
     access_log               => '/var/log/sgn-site/access.log',
     rewrite_log              => '/var/log/sgn-site/rewrite.log',

     #paths to stuff
     hmmsearch_location       => 'hmmsearch', #< in path
     intron_finder_database   => '/data/prod/public/intron_finder_database',

     # relative URL and absolute path for static datasets
     static_datasets_url      => '/data',
     static_datasets_path     => '/data/prod/public',

     # relative URL and absoluate path for static site content
     static_content_url       => '/static_content',
     static_content_path      => '/data/prod/public/sgn_static_content',
     homepage_files_dir       => '/data/prod/public/sgn_static_content/homepage',

     # relative URL and relative path for static site files
     static_site_files_url    => '/documents',
     static_site_files_path   => 'documents', #< relative to site root

     trace_path               => '/data/prod/public/chromatograms',
     image_dir    	      => '/images/image_files',
     image_path               => '/data/prod/public/images',
     tempfiles_subdir         => '/documents/tempfiles',
     submit_dir               => '/data/shared/submit-uploads',
     programs_subdir          => '/programs',
     documents_subdir         => '/documents',
     conf_subdir              => '/conf',
     support_data_subdir      => '/support_data',
     document_root_subdir     => '/cgi-bin',
     executable_subdir        => '/cgi-bin',

     #in case of missing pages where we should go
     error_document           => '/tools/http_error_handler.pl',

     #currently our cookies encrypt stuff, so this is just a random string to use to do that
     cookie_encryption_key    => 'bo9yie2JeeVee6ouAhch9aomeesieJ3iShae8aa8',

     #SGN Devel Toolbar Stuff
     dt_localsite             => 'http://localhost/',
     dt_develsite             => 'http://sgn-devel.sgn.cornell.edu/',
     dt_livesite              => 'http://www.sgn.cornell.edu/',

     #path to jslib relative to site basepath
     global_js_lib            => 'js',

     #path to mason global lib relative to site basepath
     global_mason_lib         => undef,

     # default GBrowse2 configuration, for a Debian gbrowse2 installation
     feature => {
         'SGN::Feature::GBrowse2' =>
             {
                 'enabled'    => 1,
                 'run_mode'   => 'fcgi',

                 #'conf_dir'   => '/etc/cxgn/SGN/gbrowse',
                 'tmp_dir'    => '/var/tmp/gbrowse',

                 'static_url' => '/gbrowse/static',
                 'static_dir' => '/usr/share/gbrowse/htdocs',

                 'cgi_url'    => '/gbrowse/bin',
                 'cgi_bin'    => '/usr/share/gbrowse/cgi-bin',
                 'perl_inc'   => ['/usr/share/gbrowse/lib/perl5'],
             },
         'SGN::Feature::ITAG' =>
             {
                 'enabled'       => 1,
                 'pipeline_base' => '/data/shared/tomato_genome/itagpipeline/itag',
             },
     },

    };
sub defaults { shift->SUPER::defaults( $defaults, @_ )}
