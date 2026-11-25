package CXGN::Tools::ShellQuote;

=head1 NAME

CXGN::Tools::ShellQuote - quote values for a command line that runs in a shell

=head1 SYNOPSIS

  use CXGN::Tools::ShellQuote qw(shell_quote);
  my $cmd = join(" ", "Rscript", shell_quote($script, $pheno_file, $trait_name));

=head1 DESCRIPTION

Job commands (CXGN::Job, CXGN::Tools::Run) and system() run their command
string in bash, so any value that comes from a request or from the database
must be quoted. shell_quote() puts each value in single quotes, writing a
single quote inside it as '"'"'. An undefined value becomes ''.

=cut

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(shell_quote);

sub shell_quote {
    my @quoted = map {
        my $value = defined($_) ? $_ : '';
        "'" . join("'\"'\"'", split(/'/, $value, -1)) . "'";
    } @_;
    return wantarray ? @quoted : join(" ", @quoted);
}

1;
