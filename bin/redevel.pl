#!/usr/bin/perl

use strict;
use warnings;

use Carp qw(carp croak verbose);
use FindBin qw($RealBin);

use Getopt::Long;
use Pod::Usage;

use lib "lib";
use lib "../lib";

use App::ReDevel;

sub main {

    my $help = 0;

    my $options = {
        ver => 3,
        cmd => undef,
        host => undef,
        user => undef,
        host_dist_type => undef,
   };

    my $options_ok = GetOptions(
        'help|h|?' => \$help,

        'ver|v=i' => \$options->{'ver'},
        'cmd=s' => \$options->{'cmd'},
        'host=s' => \$options->{'host'},
        'user=s' => \$options->{'user'},
        'host_dist_type=s' => \$options->{'host_dist_type'},
    );

    if ( $help || !$options_ok ) {
        pod2usage(1);
        return 0 unless $options_ok;
        return 1;
    }

    my $client_obj = App::ReDevel->new();
    my $ret_code = $client_obj->run( $options );
    print STDERR $client_obj->err() . "\n" unless $ret_code;
    return $ret_code;
}


my $ret_code = main();
# 0 is ok, 1 is error. See Unix style exit codes.
exit(1) unless $ret_code;
exit(0);


=head1 NAME

redevel.pl - Run App::ReDevel server commands.

=head1 SYNOPSIS

perl redevel.pl [options]

 Options:
    --help ... Prints this help informations.
    
    --ver=$NUM ... Verbosity level 0..10 Default 3.

    --cmd=? ... See availible commands below:

    --cmd=test_hostname
        For testing purpose. Run 'hostname' command on server and compare it to --host.
        Return nothing (on success) or error message.
        Also require --host=? and --user=?.

    --host=? ... Full hostname of server for SSH connect.

    --user=? ... User name for SSH connect.

    --host_dist_type=? ... Distribution type e.g. irix-64b, linux-64b, ...

    --cmd=check_server_dir
        Run 'ls -l' command on server and validate output.
        Return nothing (on success) or error message.
        Also require --host=? and --user=?.

    --cmd=remove_server_dir
        Remove App::ReDevel directory on server. Call 'check_server_dir' to ensure that anything else will be removed.
        Return nothing (on success) or error message.
        Also require --host=? and --user=?.

    --cmd=renew_server_dir
        Remove old and put new server source code (scripts and libraries) on server machine. Call 'remove_server_dir'
        (and 'check_server_dir') and then put new code.
        Return nothing (on success) or error message.
        Also require --host=?, --user=? and --host_dist_type=?.

    --cmd=test_noop_rpc
        Try to run 'noop' test command on server shell over RPC. You should run 'renew_server_dir' cmd to transfer
        RPC source code to server first.
        Return nothing (on success) or error message.
        Also require --host=? and --user=?.

    --cmd=test_three_parts_rpc
        Try to run 'tree_parts' test command on server shell over RPC. You should run 'renew_server_dir' cmd to transfer
        RPC source code to server first.
        Return nothing (on success) or error message.
        Also require --host=? and --user=?.
    
=head1 DESCRIPTION

B<This program> run App::ReDevel server command.

=cut
