use Module::Build;
my $class = Module::Build->subclass(
    class => 'Module::Build::SGNSite',
    code  => <<'SUBCLASS',

# build action just runs make on programs
sub ACTION_build {
   my $self = shift;
   $self->SUPER::ACTION_build(@_);
   system "make -C programs";
   $? and die "make failed\n";
}

# override install to just copy the whole dir into the install_base
sub ACTION_install {
   my $self = shift;
   $self->SUPER::ACTION_install(@_);

   my @install_dirs = qw|cgi-bin conf features js mason programs static support_data t |;

   require File::Spec;
   my $tgt_dir = File::Spec->catdir($self->install_base,'sgn');
   mkdir $tgt_dir;
   system 'cp', '-rl', @install_dirs => $tgt_dir;
   $? and die "SGN site copy failed\n";

   #put the documents symlink in place also
   symlink 'static/documents' => "$tgt_dir/documents"
    or die "$! symlinking static/documents => $tgt_dir/documents";
}

sub ACTION_clean {
   shift->SUPER::ACTION_clean(@_);
   system "make -C programs clean";
   $? and die "SGN site copy failed\n";
}
SUBCLASS
);

#my $class = 'Module::Build';
my $build = $class->new(

    dist_name          => 'SGN',
    license            => 'perl',
    create_makefile_pl => 'passthrough',

    module_name        => 'SGN::Context',

    # current version of our core libraries distribution
    dist_version => '0.1',
    dist_author  => 'Lukas Mueller',
    dist_abstract =>
'The code and content behind the Sol Genomics Network main website, http://solgenomics.net',

    recursive_test_files => 1,

    build_requires => {
        'Class::MethodMaker' => 0,

        'File::Temp'           => 0,
        'HTML::Lint'           => 0,
        'Test::JSON'              => 0,
        'List::Util'           => 0,
        'Test::More'           => 0,
        'Test::Most'           => 0,
        'Test::WWW::Mechanize' => 0,
        'Test::WWW::Mechanize::Catalyst' => '0.50',
        'Test::WWW::Selenium'  => 0,
        'Test::MockObject'     => 0,


    },
    requires => {
        'perl'                => '5.10.0',
        'autodie'             => 0,
        'IPC::System::Simple' => 0,         #< required for autodie :all
        'Apache::DBI'         => 0,

        'Bio::Chado::Schema' => '0.05900',

	'Bio::Root::Version'     => '1.006001',
        'Bio::Graphics::FeatureFile' => 0,

        'Cache::File' => 0,


        'Catalyst::Runtime'                => '5.80024',
        'Catalyst::Controller::CGIBin'     => '0.029',
        'Catalyst::Action::RenderView'     => 0,
        'Catalyst::Plugin::ConfigLoader'   => 0,
        'Catalyst::Plugin::Static::Simple' => 0,
        'Catalyst::View::Email'            => 0,
        'Catalyst::View::HTML::Mason'      => 0,
        'Catalyst::View::JavaScript::Minifier::XS'
                                           => '2.100000',
        'CatalystX::GlobalContext'         => 0,

        'Config::JFDI'                     => 0,
        'CGI'                              => 0,

        'Data::Visitor::Callback' => 0,

        'DBIx::Class'             => 0,
        'DBIx::Connector'         => 0,
        'File::Flock'             => 0,
        'File::NFSLock'           => 0,
        'File::Slurp'             => 0,
        'File::Temp'              => 0,
        'Number::Bytes::Human'    => '0.07',
        'GD'                      => 0,
        'GD::Graph::Map'          => 0,
        'GD::Graph::points'       => 0,
        'GD::Text'                => 0,
        'Hash::Merge'             => 0,
        'HTML::Entities'          => 0,
        'HTML::FormFu'            => 0,
        'HTML::Mason'             => 0,
        'HTML::TreeBuilder::XPath' => 0,
        'IO::String'              => 0,
        'Image::Size'             => 0,
        'JSAN::ServerSide'        => '==0.06',
        'JSON'                    => 0,
        'JSON::XS'                => '2.24',
        'JSON::Any'               => 0,
        'List::Util'              => 0,
        'LWP::UserAgent'          => 0,
        'Mail::Sendmail'          => 0,
        'Math::Round::Var'        => 0,
        'Memoize'                 => 0,
        'Module::Build'           => '0.36',
        'Module::Find'            => 0,
        'Module::Pluggable::Object' => 0,
        'Moose'                   => 0,
        'MooseX::Declare'         => 0,
        'MooseX::Method::Signatures' => '0.30',
        'MooseX::Types::Path::Class' => 0,
        'MooseX::Types::URI'      => 0,
        'MooseX::Singleton'       => 0,
        'Number::Format'          => 0,
        'namespace::autoclean'    => 0,
        'SOAP::Transport::HTTP'   => 0,
        'Statistics::Descriptive' => 0,
        'Storable'                => 0,
        'Test::More'              => 0,
        'Test::Class'             => 0,
        'Test::WWW::Mechanize'    => 0,
        'Test::WWW::Mechanize::Catalyst'
                                  => 0,
        'Text::ParseWords'        => 0,
        'Tie::Function'           => 0,
        'Tie::UrlEncoder'         => 0,
        'Time::HiRes'             => 0,
        'Try::Tiny'               => 0,
        'URI'                     => 0,
        'URI::Escape'             => 0,
        'URI::FromHash'           => 0,
        'XML::Generator'          => 0,
        'XML::Twig'               => 0,
        'YAML::Any'               => 0,
        'WWW::Mechanize::TreeBuilder' => 0,

    },
);
$build->create_build_script;

