package SSH::RPC::Shell::PP::TestCmds;

$__PACKAGE__::VERSION = '0.100';

use strict;
use base 'SSH::RPC::Shell::PP::Cmd::BaseJSON';


=head1 NAME

SSH::RPC::Shell::PP::TestCmds - Class with base commands for testing purpose.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 METHODS


=head2 run_test_noop ()

This command method just returns a successful status so you know that communication is working.

=cut

sub run_test_noop {
    my ( $self ) = @_;

    my $result = { test => 'noop' };
    #return $result; # debug, really bad error
    #$result = { err => 'response error test' }; # debug, command error
    return $self->pack_ok_response( $result );
}


=head2 run_test_tree_parts()

This command record return tree JSON responses.

=cut

sub run_test_three_parts {
    my ( $self ) = @_;

    my $result = {
        test => 'three_parts',
        part_num => undef,
    };

    $result->{part_num} = 1;
    $self->send_ok_response( $result, 0 );

    $result->{part_num} = 2;
    $self->send_ok_response( $result, 0 );

    $result->{part_num} = 3;
    return $self->send_ok_response( $result, 1 );
}


1;
