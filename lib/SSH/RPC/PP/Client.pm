package SSH::RPC::PP::Client;

our $VERSION = 1.200;

use strict;
use JSON;
use SSH::RPC::PP::Result;

=head1 NAME

SSH::RPC::PP::Client - The requestor of an RPC call over SSH.

=head1 SYNOPSIS

ToDo. See L<App::ReDevel>.

=head1 DESCRIPTION

Based on SSH::RPC::Client, but without Class::InsideOut.

=head1 METHODS


=head2 new

Constructor.

=cut

sub new {
    my ( $class, $ssh_obj, $server_start_cmd, $ver ) = @_;

    my $self = {};
    $self->{ssh} = $ssh_obj;
    $self->{server_start_cmd} = $server_start_cmd;
    $self->{ver} = $ver;

    $self->{out_fh} = undef;

    bless( $self, $class );
    return $self;
}


=head2 get_next_raw_response

Return next response from server in raw hash format.

=cut

sub get_next_raw_response {
    my ( $self ) = @_;

    unless ( defined $self->{out_fh} ) {
        return { error => 'Internal error: No input handle from server.', status => 501 };
    }

    my $out_to_decode = '';
    my $empty_lines = 0;
    my $out_fh = $self->{out_fh};
    while ( my $line = <$out_fh> ) {
        if ( $line eq "\n" || $line eq "\r\n" ) {
            $empty_lines++;
            # two empty lines (or eof) -> output to decode finished
            last if $empty_lines >= 2;

        } else {
            $empty_lines = 0;
            $out_to_decode .= $line;
        }
    }

    print "Output from server: '$out_to_decode'\n" if $self->{ver} >= 10;
    if ( $out_to_decode ) {
        my $response = eval { JSON->new->utf8->decode( $out_to_decode ) };
        if ( $@ ) {
            return { error => "Response translation error. $@".$self->{ssh}->error, status => 510 };
        }
        return $response;
    }

    return { error => "No response from server.", status => 600 };
}


=head2 get_next_raw_response

Return next response from server as L<SSH::RPC::PP::Result> object.

=cut

sub get_next_response {
    my ( $self ) = @_;

    my $response = $self->get_next_raw_response();
    my $result_obj = SSH::RPC::PP::Result->new( $response );
    return $result_obj;
}


=head2 run

Run command with arguments on server throug ssh and return first response (Result object).

=cut

sub run {
    my ( $self, $command, $args ) = @_;

    my $json = JSON->new->utf8->pretty->encode({
        command => $command,
        args    => $args,
    }) . "\n" . "\n\n";

    my $out_fh;
    my ($in_fh, $out_fh, undef, $pid) = $self->{ssh}->open_ex(
        {
            stdin_pipe => 1,
            stdout_pipe => 1,
            ssh_opts => ['-T'],
        },
        $self->{server_start_cmd}
    );

    unless ( defined $pid ) {
        my $response = { error => "Transmission error. ".$self->{ssh}->error, status => 406 };
        my $result_obj = SSH::RPC::PP::Result->new( $response );
        return $result_obj;
    }

    $self->{out_fh} = $out_fh;
    print $in_fh $json;
    return $self->get_next_response();
}


=head2 run

Run command with arguments on server in debug mode. Do not slurp remote output.

=cut

sub debug_run {
    my ( $self, $command, $args ) = @_;

    my $json = JSON->new->utf8->pretty->encode({
        command => $command,
        args    => $args,
    }) . "\n";

    my $ret_code = $self->{ssh}->system(
        {
            stdin_data => $json,
            ssh_opts => ['-T'],
        },
        $self->{server_start_cmd}
    );
    return $ret_code;
}


1;
