package SSH::RPC::PP::Result;

our $VERSION = 0.100;

use strict;
use Data::Dumper;

=head1 NAME

SSH::RPC::PP::Result - Provides methods for the response from a SSH::RPC::Client run() method request.

=head1 DESCRIPTION

Based on SSH::RPC::Result, but without Class::InsideOut.

=cut


sub new {
    my ( $class, $result ) = @_;

    my $self = {};
    $self->{result} = $result;
    $self->{status_messages} = undef;

    bless( $self, $class );
    return $self;
}


=head2 getResult ()

Returns raw result.

=cut

sub getResult {
    my $self = shift;
    return $self->{result};
}


=head2 getResponseError ()

Returns error message from response. Error during command execution.

=cut

sub getResponseError {
    my $self = shift;
    return $self->{result}->{response}->{err};
}


=head2 getError ()

Returns the human readable error message (if any).

=cut

sub getError {
    my $self = shift;
    return $self->{result}->{error};
}

=head2 getResponse ()

Returns the return value(s) from the RPC, whether that be a scalar value, or a hash reference or array reference.

=cut

sub getResponse {
    my $self = shift;
    return $self->{result}->{response};
}


=head2 getShellVersion ()

Returns the $VERSION from the shell. This is useful if you have different versions of your shell running on different machines, and you need to do something differently to account for that.

=cut

sub getShellVersion {
    my $self = shift;
    return $self->{result}->{version};
}


=head2 getStatus ()

Returns a status code for the RPC.

=cut

sub getStatus {
    my $self = shift;
    return $self->{result}->{status};
}


=head2 isLast ()

Returns 1 if this is last result object.

=cut

sub isLast {
    my $self = shift;
    return $self->{result}->{is_last};
}


=head2 getAllStatusMessages ()

Return the status code mesages hash.

=cut

sub getAllStatusMessages {
    # ToDo - is this accurate?
    return {
        '200' => 'Success.',

        '400' => 'Malform request received by shell.',
        '405' => 'RPC called a method that doesn\'t exist.',
        '406' => 'Error transmitting RPC.',

        '500' => 'An undefined error occured in the shell.',
        '501' => 'Internal error occured in the shell.',
        '510' => 'Error translating return document in client.',
        '511' => 'Error translating return document in shell.',

        '600' => 'No response from client.',
    };
}


=head2 getStatusMessage ()

Returns a status code message for the RPC.

=cut

sub getStatusMessage {
    my $self = shift;

    $self->{status_messages} = $self->getAllStatusMessages() unless defined $self->{status_messages};

    unless ( defined $self->{result}->{status} ) {
        return "Status code not found. Can't determine status message";
    }

    my $status_code = $self->{result}->{status};
    unless ( exists $self->{status_messages}->{ $status_code } ) {
        return "Unknown status message (status code $status_code).";
    }
    return $self->{status_messages}->{ $status_code };
}


=head2 isSuccess ()

Returns true if the request was successful, or false if it wasn't.

=cut

sub isSuccess {
    my $self = shift;
    return ( $self->{result}->{status} == 200 );
}


=head2 isSuccess ()

Returns true if the request was successful, or false if it wasn't.

=cut

sub dump {
    my ( $self ) = @_;

    my $result = $self->{result};
    #print "Full result: " . Dumper($result) . "\n" if $self->{ver} >= 10;

    if ( $self->isSuccess ) {
        print "=== response is ok =============================================\n";
    } else {
        print "=== response error =============================================\n"
    }

    print "status: " . $self->getStatus() . " - '" . $self->getStatusMessage() . "'\n";


    if ( $self->isSuccess ) {
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::Indent = 1;
        my $response_dump = Data::Dumper->Dump( [ $result->{response} ] );
        print "--- response data: ---------------------------------------------\n";
        print $response_dump;

    } else {
        my $result_error = $self->getError();
        print "result error: '$result_error'\n" if $result_error;

        my $response_error = $self->getResponseError();
        print "response error: '$response_error'\n" if $response_error;
    }

    if ( $result->{debug_output} ) {
        print "--- debug output: ---------------------------------------------\n";
        print $result->{debug_output};
    }
    print "================================================================\n";
    print "\n";

}


1;

