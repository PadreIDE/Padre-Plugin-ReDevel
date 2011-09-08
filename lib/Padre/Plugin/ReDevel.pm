package Padre::Plugin::ReDevel;

use strict;
use warnings;
use 5.008;

our $VERSION = '0.05';

use Padre::Wx ();
use Data::Dumper;
use File::Spec;
use File::HomeDir;
use YAML::Tiny;
use Carp qw(carp croak);

use base 'Padre::Plugin';

# ToDo
our $ProtocolRegex = qr/^remote:\/\//;
our $ProtocolHandlerClass = 'Padre::Plugin::ReDevel::SSH';


=head1 NAME

Padre::Plugin::ReDevel - Padre support for remote development

=head1 SYNOPSIS

L<Padre> (Perl Application Development and Refactoring Environment) plugin
to remote (over SSH) development.

=head1 METHODS


=head2 plugin_name

The plug-in name to show in the Plug-in Manager and menus

=cut

sub plugin_name {
    'ReDevel';
}


=head2 padre_interfaces

Declare the Padre interfaces this plug-in uses.

=cut

sub padre_interfaces {
    return (
        'Padre::Plugin' => 0.84,
        'Padre::File'   => 0.4,
    );
}


=head2 menu_plugins_simple

The command structure to show in the Plugins menu.

=cut

sub menu_plugins_simple {
    my $self = shift;
    return $self->plugin_name => [
        "Connect and start"         => sub { $self->run_for_all_hosts('connect_and_start_cmd') },
        "Connect, renew and start"  => sub { $self->run_for_all_hosts('connect_renew_and_start_cmd') },
        "Stop and disconnect"       => sub { $self->run_for_all_hosts('stop_and_disconnect_cmd') },

        "Connect, renew, ..." => [
            "Connect and start"         => sub { $self->run_for_all_hosts('connect_and_start_cmd') },
            "Stop and disconnect"       => sub { $self->run_for_all_hosts('stop_and_disconnect_cmd') },
            "Connect, renew and start"  => sub { $self->run_for_all_hosts('connect_renew_and_start_cmd') },
            "Connect"                   => sub { $self->run_for_all_hosts('connect_cmd') },
            "Renew"                     => sub { $self->run_for_all_hosts('renew_cmd') },
            "Start"                     => sub { $self->run_for_all_hosts('start_cmd') },
            "Test noop rpc"             => sub { $self->run_for_all_hosts('run_client_cmd_by_name','test_noop_rpc') },
            "Test three parts rpc"      => sub { $self->run_for_all_hosts('run_client_cmd_by_name','test_three_parts_rpc') },
            "Stop"                      => sub { $self->run_for_all_hosts('stop_cmd') },
            "Remove"                    => sub { $self->run_for_all_hosts('remove_cmd') },
            "Disconnect"                => sub { $self->run_for_all_hosts('disconnect_cmd') },
        ],

        # ToDo - remove debug shortcut
        "Config, reload"  => [
            "Open config" => 'open_config',
            "Reload config" => 'load_config',
            #"Reload plugin\tCtrl+Shift+M"
            "Reload plugin" => sub { $_[0]->current->ide->plugin_manager->reload_plugin('Padre::Plugin::ReDevel') },
        ],
        "About" => 'show_about',
    ];
}


=head2 conf_dir

Return configuration directory of Padre inside user home directory.

=cut

sub conf_dir {
    # ToDo - use some Padre method?
    return File::Spec->catdir(
        File::HomeDir->my_data,
        File::Spec->isa('File::Spec::Win32') ? 'Perl Padre' : '.padre'
    );
}


=head2 conf_fpath

Return ReDevel plugin's configuration file. See also C<conf_dir>.

=cut

sub conf_fpath {
    my $self = shift;
    return File::Spec->catfile( $self->conf_dir, 'redevel.yml' );
}


=head2 open_config

Open ReDevel plugin's configuration file as new window in current editor.

=cut

sub open_config {
    my ( $self ) = @_;

    my $conf_fpath = $self->conf_fpath();
    my $main = $self->ide->wx->main;
    my $id = $main->setup_editor( $conf_fpath );
    return 1;
}


=head2 load_config_file

Load/reload ReDevel plugin's configuration file to 'rd_config' attribute.

=cut

sub load_config_file {
    my $self = shift;

    my $conf_fpath = $self->conf_fpath();
    my $config = undef;
    eval { $config = YAML::Tiny::LoadFile($conf_fpath); };
    my $e = $@;
    return $self->show_err_dialog( $e ) if $e;

    # ToDo - config validation method missing
    $self->{rd_config} = $config;
    print Dumper( $config ) if $self->{ver} >= 7;

    return 1;
}


=head2 set_config_section

Set 'session_pos' attribute to rd_config->session element position
which match current Padre session name (by value or regexp).

=cut

sub set_config_section {
    my $self = shift;

    # Check if config is already loaded.
    unless ( $self->{rd_config} ) {
        carp "Config not loaded yet.";
        return 0;
    }

    # Return if section isn't set.
    # ToDo - provide this info to user somehow.
    return 1 unless $self->current->ide->opts->{session};
    my $act_session_name = $self->current->ide->opts->{session};

    # Find first position in config->session matching current session name
    # by value or regexp.
    my $err_found = 0;
    my $selected_sess_pos = undef;
    my $config = $self->{rd_config};
    foreach my $sess_pos ( 0..$#{$config->{session}} ) {
        my $section = $config->{session}->[ $sess_pos ];
        # by exact value
        if ( exists $section->{session_name} ) {
            if ( $section->{session_name} eq $act_session_name ) {
                $selected_sess_pos = $sess_pos;
                last;
            }

        # by regexp
        } elsif ( exists $section->{session_regexp} ) {
            my $regexp = $section->{session_regexp};
            if ( $act_session_name =~ $section->{session_regexp} ) {
                $selected_sess_pos = $sess_pos;
                last;
            }

        # error - no value nor regexp
        } else {
            carp "Can not find session identification (no name or regexp given) on sessio->$sess_pos.";
            $err_found = 1;
            last;
        }
    }

    # remember position found (or undef)
    $self->{session_pos} = $selected_sess_pos;
    print "Selected session pos: " . ( defined $selected_sess_pos ? "'$selected_sess_pos'" : 'undef' ) . "\n" if $self->{ver} >= 5;
    return 1;
}


=head2 set_config_path_maps

Use 'session_pos' attribute to set 'session_map' hashref attribute containing
path aliases (arrayref in hash value) for each host alias (in hash key).

=cut

sub set_config_path_maps {
    my $self = shift;

    return 1 unless defined $self->{session_pos};

    my $sess_pos = $self->{session_pos};
    my $section_hosts = $self->{rd_config}->{session}->[ $sess_pos ]->{hosts};
    foreach my $host_alias ( keys %$section_hosts ) {
        $self->{session_map}->{ $host_alias } = [];
        my $host_path_aliases = $section_hosts->{ $host_alias }->{paths};
        foreach my $path_alias ( @$host_path_aliases ) {
            push @{ $self->{session_map}->{$host_alias} }, $path_alias;
        }
    }
    return 1;
}


=head2 load_config

Do all steps needed to load and process connfig.

=cut

sub load_config {
    my $self = shift;

    $self->close_all_hosts();

    return 0 unless $self->load_config_file();
    return 0 unless $self->set_config_section();
    return 0 unless $self->set_config_path_maps();
    return 1;
}


=head2 process_src_rx

Translate config reg_expr to perl regular expression.

=cut

sub process_src_rx {
    my ( $self, $rx ) = @_;

    # simple most common cases
    return '.*' if $rx eq '**';
    return '[^\\]*' if $rx eq '*';

    # ToDo - review and tests
    # more sofisticated patters
    my $reg_expr = $rx;

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
    return $reg_expr;
}


=head2 match_src_rx

Part of path regexp processing. $src_prefix should match the begin of the path and
$src_rx remaining part.

=cut

sub match_src_rx {
    my ( $self, $file_path, $src_prefix, $src_rx ) = @_;

    # Nothing to do if lenght of path is lower than src_prefix.
    return undef if length($file_path) < length($src_prefix);

    # Try to match src_prefix.
    my $file_path_part1 = substr( $file_path, 0, length($src_prefix) );
    return undef if $file_path_part1 ne $src_prefix;

    # Get second part of path to match with src_rx.
    my $file_path_part2 = substr( $file_path, length($src_prefix) );
    #print "part1: '$file_path_part1', part2: '$file_path_part2'\n";

    # no regexp - move one specific file to some remote directory/file
    if ( (not defined $src_rx) or $src_rx eq '' ) {
        return '' if $file_path_part2 eq '';
        return undef;
    }

    # Convert src_rx to real perl regexp.
    my $regex = $self->process_src_rx( $src_rx );
    #print "in: '$src_rx', regexp: '$regex'\n";

    # Try to match with regexp.
    return $file_path_part2 if $file_path_part2 =~ /^$regex$/;
    return undef;
}


=head2 match_path_map

Return first destination path of file if local/source $file_path match
any from $path_map array. Otherwise return undef.

=cut

sub match_path_map {
    my ( $self, $file_path, $path_map ) = @_;

    foreach my $def ( @$path_map ) {
        my ( $src_prefix, $src_rx, $dest_path ) = @$def;
        my $dest_sub_path = $self->match_src_rx( $file_path, $src_prefix, $src_rx );
        if ( defined $dest_sub_path ) {
            # Return the first one found.
            return File::Spec->catdir( $dest_path, $dest_sub_path );
        }
    }
    return undef;
}


=head2 add_to_doc_cache

For provided $file_path of local file/document try to match them against path_maps
of each host. The result save to 'doc_cache' attribute.

=cut

sub add_to_doc_cache {
    my ( $self, $file_path ) = @_;

    my $session_map = $self->{session_map};
    #print Dumper( $session_map );
    foreach my $host_alias ( keys %$session_map ) {
        my $path_aliases = $session_map->{ $host_alias };
        foreach my $path_alias ( @$path_aliases ) {
            my $path_map = $self->{rd_config}->{path_maps}->{ $path_alias };
            next unless defined $path_map; # ToDo - exception
            if ( my $dest_path = $self->match_path_map($file_path, $path_map) ) {
                $self->{doc_cache}->{ $file_path } = [] unless defined $self->{doc_cache}->{ $file_path };
                push @{ $self->{doc_cache}->{ $file_path } }, [ $host_alias, $dest_path ];
            }
        }
    }
}


=head2 process_doc_change

The main part of transfering file called from after_save document hook.
Call C<add_to_doc_cache> to prepare match 'doc_cache' attribute once time
for each document. If connected then call 'put_file_create_dirs'
( see C<App::ReDevel::SSHRPCClient> ).

=cut

sub process_doc_change {
    my ( $self, $doc ) = @_;

    my $file_path = $doc->filename;

    # Add to cache if not found already.
    unless ( exists $self->{doc_cache}->{$file_path} ) {
        $self->add_to_doc_cache( $file_path );
    }
    #print Dumper( $self->{doc_cache} );

    my $ret_code = 1;
    if ( defined $self->{doc_cache}->{$file_path} ) {

        foreach my $one_host_cache ( @{ $self->{doc_cache}->{$file_path} } ) {
            my ( $host_alias, $dest_path ) = @$one_host_cache;
            unless ( $self->{conns}->{ $host_alias } ) {
                print "no connected\n";
                next;
            }
            print "file_path: $file_path -> host_alias: $host_alias, dest_path: $dest_path\n";
            my $ok = $self->run_client_cmd_by_name( $host_alias, 'put_file_create_dirs', $file_path, $dest_path );
            $ret_code = 0 unless $ok;
        }
    }

    return $ret_code;
}


=head2 do_after_save

Padre after save hook.

=cut

sub do_after_save {
    my ( $self, $doc ) = @_;
    return $self->process_doc_change( $doc );
}


=head2 padre_hooks

Define Padre hooks.

=cut

sub padre_hooks {
    my $self = shift;
    return {
        before_save => sub {
            print " [[[TEST_PLUGIN:before_save]]] " . join( ', ', @_ ) . "\n";
            return undef;
        },
        after_save => sub {
            print  " [[[TEST_PLUGIN:after_save]]] " . join( ', ', @_ ) . "\n";
            my ( $self, $doc ) = @_;
            return $self->do_after_save( $doc );
        },
    };
}


=head2 show_about

ReDevel plugin about dialog.

=cut

sub show_about {
    my $self = shift;
    my $about = Wx::AboutDialogInfo->new;

    $about->SetName("Padre Plugin ReDevel");
    $about->SetDescription("Remote development through SSH.");
    $about->SetVersion($VERSION);
    Wx::AboutBox($about);
    return 1;
}


=head2 show_err_dialog

Show error in dialog window.

=cut

sub show_err_dialog {
    my ( $self, $err_msg ) = @_;
    $self->main->error( "Error: $err_msg" );
    return 0;
}


=head2 host_err

Show host error.

=cut

sub host_err {
    my ( $self, $err_msg ) = @_;
    $self->show_err_dialog( $err_msg );
    return 0;
}


=head2 connect_cmd

Connect to provided host (by $host_alias) and add connection object
App::ReDevel to 'conns' attribute. Do not start RPC shell yet (see C<start_cmd>).

=cut

sub connect_cmd {
    my ( $self, $host_alias ) = @_;

    my $host_obj = App::ReDevel->new({
        ver => $self->{ver},
    });
    my $host_conf = $self->{rd_config}->{hosts}->{ $host_alias };
    $host_conf->{ver} = $self->{ver};
    my $ret_code = $host_obj->connect_host( $host_conf );
    return $self->host_err( $host_obj->err() ) unless $ret_code;

    $self->{conns}->{ $host_alias } = $host_obj;
    return 1;
}


=head2 call_on_connected_host

Call provided $method_name with @run_params on host (by $host_alias) if
already connected. Show error if not connected yet.

=cut

sub call_on_connected_host {
    my ( $self, $host_alias, $method_name, @run_params ) = @_;

    return $self->host_err( "Not connected to host." ) unless $self->{conns}->{ $host_alias };

    my $host_obj = $self->{conns}->{ $host_alias };
    my $ret_code = $host_obj->$method_name( @run_params );
    return $self->host_err( $host_obj->err() ) unless $ret_code;
    return 1;
}


=head2 start_cmd

Start RPC Shell on already connected host.

=cut

sub start_cmd {
    my ( $self, $host_alias ) = @_;
    return $self->call_on_connected_host( $host_alias, 'start_rpc_server', 'no' );
}


=head2 renew_cmd

Renew source files for RPC Shell on already connected host.

=cut

sub renew_cmd {
    my ( $self, $host_alias ) = @_;
    return $self->call_on_connected_host( $host_alias, 'renew_server_dir', 'smart' );
}


=head2 renew_and_start_cmd

Renew source files for RPC Shell on already connected host and start RPC Shell.

=cut

sub renew_and_start_cmd {
    my ( $self, $host_alias ) = @_;
    return $self->call_on_connected_host( $host_alias, 'start_rpc_server', 'smart' );
}


=head2 connect_and_start_cmd

Connect to host and start RPC Shell.

=cut

sub connect_and_start_cmd {
    my ( $self, $host_alias ) = @_;
    return 0 unless $self->connect_cmd( $host_alias );
    return $self->call_on_connected_host( $host_alias, 'start_rpc_server', 'no' );
}


=head2 connect_renew_and_start_cmd

Connect to host, renew RPC Shell source code and start RPC Shell.

=cut

sub connect_renew_and_start_cmd {
    my ( $self, $host_alias ) = @_;
    return 0 unless $self->connect_cmd( $host_alias );
    return $self->call_on_connected_host( $host_alias, 'start_rpc_server', 'smart' );
}


=head2 run_client_cmd_by_name

Run command (SSH or RPC Shell one) by name.

=cut

sub run_client_cmd_by_name {
    my ( $self, $host_alias, $client_cmd_name, @host_params ) = @_;
    return $self->call_on_connected_host( $host_alias, 'run_by_name', $client_cmd_name, @host_params );
}


=head2 remove_cmd

Remove RPC Shell from connected host.

=cut

sub remove_cmd {
    my ( $self, $host_alias ) = @_;
    return $self->call_on_connected_host( $host_alias, 'renew_server_dir', 'remove' );
}


=head2 stop_cmd

Stop RPC Shell on provided host.

=cut

sub stop_cmd {
    my ( $self, $host_alias ) = @_;
    return $self->call_on_connected_host( $host_alias, 'stop_rpc_server' );
}


=head2 stop_and_disconnect_cmd

Stop RPC Shell on provided host and disconnect from it.

=cut

sub stop_and_disconnect_cmd {
    my ( $self, $host_alias ) = @_;
    $self->call_on_connected_host( $host_alias, 'stop_rpc_server' ) || return 0;
    return $self->call_on_connected_host( $host_alias, 'disconnect_host' );
}


=head2 stop_and_disconnect_if_needed_cmd

If connected to provided host then Stop RPC Shell it (if running) and disconnect from it.

=cut

sub stop_and_disconnect_if_needed_cmd {
    my ( $self, $host_alias ) = @_;

    return 1 unless $self->{conns}->{$host_alias};
    return 1 unless $self->{conns}->{$host_alias}->host_is_connected();

    if ( $self->{conns}->{$host_alias}->rpc_shell_is_running ) {
        $self->call_on_connected_host( $host_alias, 'stop_rpc_server' ) || return 0;
    }

    return $self->call_on_connected_host( $host_alias, 'disconnect_host' );
}


=head2 close_all_hosts

Call C<stop_and_disconnect_if_needed_cmd> on each host.

=cut

sub close_all_hosts {
    my $self = shift;
    return $self->run_for_all_hosts('stop_and_disconnect_if_needed_cmd');
}


=head2 disconnect_cmd

Disconnect from provided host.

=cut

sub disconnect_cmd {
    my ( $self, $host_alias ) = @_;
    return $self->call_on_connected_host( $host_alias, 'disconnect_host' );
}


=head2 get_host_aliases_list

Return list of host aliases from 'rd_config' for current session ('session_pos' attribute).

=cut

sub get_host_aliases_list {
    my $self = shift;
    return undef unless $self->{rd_config};
    return undef unless defined $self->{session_pos};
    my $session_pos = $self->{session_pos};
    return [ keys %{ $self->{rd_config}->{session}->[ $session_pos ]->{hosts} } ];
}


=head2 run_for_all_hosts

Run provided method name for each host_alias.

=cut

sub run_for_all_hosts {
    my ( $self, $method_name, @method_params ) = @_;

    my $host_aliases = $self->get_host_aliases_list();
    return 0 unless $host_aliases;

    foreach my $host_alias ( @$host_aliases ) {
        my $rc = $self->$method_name( $host_alias, @method_params );
    }

    #print Dumper( $self->{conns} );
    return 1;
}


=head2 run_rpc_cmd_on_hosts

Run RPC Shell command on all connected hosts and show error
dialog if any error found.

=cut

sub run_rpc_cmd_on_hosts {
    my ( $self, $cmd ) = @_;

    my $msg;

    if ( $self->{conns} ) {

        $msg = "Running command '$cmd' on all hosts.\n";
        $msg .= "Results:\n";
        foreach my $host_alias ( keys %{$self->{conns}} ) {
            my $rc = $self->{conns}->{ $host_alias }->run_by_name( $cmd );
            $msg .= "  host $host_alias return code $rc\n";
        }

    } else {
        $msg = "Not connected.";
    }

    # Show the result in a text box
    require Padre::Wx::Dialog::Text;
    Padre::Wx::Dialog::Text->show(
        $self->main,
        'Output',
        $msg
    );
    return 1;
}


=head2 test_noop_rpc

Run 'test_noop_rpc' RPC Shell command on each connected host.

=cut

sub test_noop_rpc {
    my $self = shift;
    return $self->run_rpc_cmd_on_hosts('test_noop_rpc');
}


=head2 test_three_parts_rpc

Run 'test_three_parts_rpc' RPC Shell command on each connected host.

=cut

sub test_three_parts_rpc {
    my $self = shift;
    return $self->run_rpc_cmd_on_hosts('test_three_parts_rpc');
}


=head2 plugin_enable

Padre plugin method called when plugin is enabled. Load all packages needed
and do some initialization work.

=cut

sub plugin_enable {
    my $self = shift;

    # ToDo - move to new
    $self->{ver} = 10;

    $self->load_config();

    require Padre::File;
    require Padre::Plugin::ReDevel::SSH;
    Padre::File->RegisterProtocol( $ProtocolRegex, $ProtocolHandlerClass );

    require App::ReDevel;
    # used in connect method

    return 1;
}


=head2 plugin_disable

Padre plugin method called when plugin is disables. Unload some App::ReDevel modules
hoping nothing else use them.

=cut

sub plugin_disable {
    my $self = shift;

    $self->close_all_hosts();

    require Class::Unload;

    my @pkgs = qw(
        App::ReDevel
        App::ReDevel::SSHRPCClient
        App::ReDevel::Base
    );
    foreach my $pkg ( @pkgs ) {
        Class::Unload->unload( $pkg );
    }

    Padre::File->DropProtocol( $ProtocolRegex, $ProtocolHandlerClass );
    return 1;
}


1;

__END__


=head1 AUTHOR

Michal Jurosz, C<mj@mj41.cz>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 Michal Jurosz

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut
