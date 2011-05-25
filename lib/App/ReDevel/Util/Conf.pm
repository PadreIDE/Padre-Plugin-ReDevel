package App::ReDevel::Util::Conf;

use strict;
use warnings;


=head2 process_regexp

Translate config reg_expr to perl regular expression.

=cut

sub process_regexp {
    my ( $self, $in_reg_expr ) = @_;

    my $is_recursive = 0;
    if ( $in_reg_expr =~ m{\*\*}x ) {
        $is_recursive = 1;
    } elsif ( $in_reg_expr =~ m{ [\*\?] .* \/ .* [\*\?] }x ) {
        $is_recursive = 1;
    }
    
    my $reg_expr = $in_reg_expr;

    # escape
    $reg_expr =~ s{ ([  \- \) \( \] \[ \. \$ \^ \{ \} \\ \/ \: \; \, \# \! \> \< ]) }{\\$1}gx;

    # ?
    $reg_expr =~ s{ \? }{\[\^\\/\]\?}gx;

    # *
    #$reg_expr =~ s{ (?!\*) \* (?!\*)  }{\[\^\\\/\]\*}gx;
    # * - old way
    $reg_expr =~ s{   ([^\*])  \* ([^\*])     }{$1\[\^\\\/\]\*$2}gx;
    $reg_expr =~ s{   ([^\*])  \*           $ }{$1\[^\\\/\]\*}gx;
    $reg_expr =~ s{ ^          \*  ([^\*])    }{\[\^\\\/\]\*$1}gx;

    # **
    $reg_expr =~ s{ \*{2,} }{\.\*}gx;
    
    print "Reg expr transform: '$in_reg_expr' => '$reg_expr'\n" if $self->{ver} >= 5;
    return ( $is_recursive, $reg_expr );
}


1;