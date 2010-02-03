=head1 DEPRECATED

This package is deprecated, do not use in new code.

=cut

# =head1 NAME

# CXGN::MasonFactory - a factory that returns HTML::Mason::Interp object configured for the CXGN layout.

# =head1 SYNOPSIS

#     my $mason = CXGN::MasonFactory->new();
#     $mason->exec('/my/mason/module, %args);


#     my $output = CXGN::MasonFactory
#                    ->bare_render( '/my/component.mas',
#                                   foo => 'bar',
#                                   baz => 'boo',
#                                 );

# =head1 DESCRIPTION

# To create a new Mason object, use CXGN::MasonFactory instead of HTML::Mason. MasonFactory will give you correctly set paths for the CXGN system.

# =head1 AUTHOR

# Lukas Mueller E<lt>lam87@cornell.eduE<gt>

# =head1 COPYRIGHT & LICENSE

# Copyright (c) 2009 The Boyce Thompson Institute for Plant Research

# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

# =head1 METHODS

# =cut

package CXGN::MasonFactory;

use strict;
use warnings;
use English;
use Carp;

use HTML::Mason;

use SGN::Context;

# =head2 new

#  Usage:        $mason = CXGN::MasonFactory->new()
#                $mason->exec("/blabla");
#  Desc:         creates an appropriate HTML::Mason object
#  Args:         optional hash-style list as:
#                 data_dir => additional data tempfile dir to add,
#                 ...

#                See L<HTML::Mason::Admin> and L<HTML::Mason::Interp>
#                for more an these arguments.

#  Side Effects: none
#  Example:

#     CXGN::MasonFactory->new->exec('/mycomponent.mas');

# =cut

sub new {
    my $class = shift;
    @_ and croak "new() takes no arguments\n";
    SGN::Context->instance->_mason_interp;
}

# =head2 bare_render

#   Usage: my $output = CXGN::MasonFactory
#                          ->bare_render('/my/component.mas',
#                                        foo => 'bar',
#                                        baz => 'boo',
#                                       );

#   Desc : use this method to call a mason component like an
#          html-generating function
#   Args : component name, then hash-style list of arguments for the
#          component
#   Ret  : string of HTML produced by the component
#   Side Effects: throws a warning that the page you are using it in
#                 needs to be migrated to all-mason
#   Example :

#   # in some legacy script

#   print info_section_html(title   => 'Clone &amp; library',
# 			collapsible => 1,
# 			contents =>
# 			'<center><table><tr><td>'
# 			. CXGN::MasonFactory
#                              ->bare_render('/genomic/clone/clone_summary.mas',
#                                            clone => $clone )
# 			. '</td><td>'
# 			. CXGN::MasonFactory
#                              ->bare_render('/genomic/library/library_summary.mas',
#                                            library => $clone->library_object)
# 			. '</td></tr></table>'
# 			. '</center>'
# 		       );

# =cut

sub bare_render {
    my $class = shift;
    return SGN::Context->instance->render_mason( @_ );
}

###
1;#do not remove
###
