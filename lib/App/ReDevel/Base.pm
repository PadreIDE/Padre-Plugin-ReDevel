package App::ReDevel::Base;

use strict;
use warnings;


use Data::Dumper;


=head1 NAME

App::ReDevel::Base - App::ReDevel client base class.

=head1 SYNOPSIS

See L<App::ReDevel>

=head1 DESCRIPTION

App::ReDevel client base class.

=head1 METHODS


=head2 new

Constructor.

=cut

sub new {
    my ( $class, $params ) = @_;

    my $self  = {};

    $self->{ver} = 3;
    $self->{ver} = $params->{ver} if defined $params->{ver};
    $self->{err} = undef;

    bless $self, $class;
    return $self;
}


=head2 err

Get/set error message and return 0.

=cut

sub err {
    my ( $self, $err, $caller_back ) = @_;

    # Get.
    return $self->{err} unless defined $err;

    $caller_back = 0 unless defined $caller_back;
    
    # Set.
    my $package_name = ( ref $self );
    if ( $self->{ver} >= 5 ) {
        my $caller_line = (caller 0+$caller_back)[2];
        my $caller_sub = (caller 1+$caller_back)[3];
        my $msg_op_typ_str = ( $self->{err} ? 'Adding error' : 'Setting error to' );
        print  "$caller_sub on line $caller_line - $msg_op_typ_str '$err'\n";
    }
    
    if ( $self->{err} ) {
        $self->{err} .= "\n" . $err;
    } else {
        $self->{err} = $err;
    }

    # return 0 is ok here.
    # You can use  e.g.
    #   return $self->err('Err msg') if $some_error;
    return 0;
}


=head2 dump

Print given message and dump other parameters.

=cut

sub dump {
    my $self = shift;
    my $msg = shift;

    print $msg . " ";
    {
        local $Data::Dumper::Indent = 1;
        local $Data::Dumper::Purity = 1;
        local $Data::Dumper::Terse = 1;
        print Data::Dumper->Dump( [ @_ ], [] );
    }
    return 1;
}


=head2 print_progress

Print the progress line. Parameters are the same as for sprintf.

=cut

sub print_progress {
    my ( $self, $msg_format, @paramss ) = @_;

    my $msg = '';
    if ( defined $msg_format ) {
        $msg  = sprintf( $msg_format, @paramss );
    }
    if ( length($msg) >= 80 ) {
        $msg = substr( $msg, 0, 77 ) . '...';
    }

    my $blank_len = 80 - length( $msg );
    $blank_len = 0 if $blank_len < 0;

    my $prev_buff = $|;
    $| = 1;
    printf( "%s%s%s", $msg, ' ' x $blank_len, "\b" x ( length($msg) + $blank_len ) );
    $| = $prev_buff;
}


=head1 SEE ALSO

L<App::ReDevel>

=head1 LICENSE

This file is part of App::ReDevel. See L<App::ReDevel> license.

=cut


1;