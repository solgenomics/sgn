package SGN::Test::I18NFiles;

=head1 NAME

SGN::Test::I18NFiles - build small translation files for the i18n unit tests

=head1 SYNOPSIS

    use lib 't/lib';
    use SGN::Test::I18NFiles qw(missing_requirement build_translations);

    plan skip_all => missing_requirement() if missing_requirement();
    my $dir = build_translations(tempdir(CLEANUP => 1));

=head1 DESCRIPTION

Compiles the synthetic PO files in F<t/data/i18n/po/> with C<msgfmt> into
F<< <dir>/LocaleData/<locale>/LC_MESSAGES/sgn.mo >>, and writes the synthetic
browser catalogs of F<t/data/i18n/test-catalogs.json> as
F<< <dir>/js/<locale>/common.json >>: the layout of the sgn-translations build.

=head1 FUNCTIONS

=head2 missing_requirement

Return why the files cannot be used (libintl-perl or msgfmt missing), or undef.

=head2 build_translations($dir)

Build the files into C<$dir> and return C<$dir>.

=cut

use strict;
use warnings;

use Exporter qw(import);
use File::Path qw(make_path);
use JSON::PP;

our @EXPORT_OK = qw(missing_requirement build_translations);

sub missing_requirement {
    return 'libintl-perl is not installed (Debian: apt-get install libintl-perl)'
        unless eval { require Locale::Messages; 1 };
    return 'msgfmt (GNU gettext) is not installed' unless `msgfmt --version 2>/dev/null`;
    return;
}

sub build_translations {
    my ($dir) = @_;
    for my $po (glob 't/data/i18n/po/*.po') {
        my ($locale) = $po =~ m{([^/]+)\.po\z};
        my $messages = "$dir/LocaleData/$locale/LC_MESSAGES";
        make_path($messages);
        system('msgfmt', '--check-format', '-o', "$messages/sgn.mo", $po) == 0 or die "msgfmt failed for $po\n";
    }
    my $json = JSON::PP->new->utf8->canonical;
    open(my $in, '<:raw', 't/data/i18n/test-catalogs.json') or die "Cannot read test catalogs: $!";
    my $catalogs = $json->decode(do { local $/; <$in> })->{catalogs};
    close($in);
    for my $locale (keys %$catalogs) {
        make_path("$dir/js/$locale");
        open(my $out, '>:raw', "$dir/js/$locale/common.json") or die $!;
        print $out $json->encode($catalogs->{$locale});
        close($out);
    }
    return $dir;
}

1;
