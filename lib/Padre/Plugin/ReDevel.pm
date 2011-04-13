package Padre::Plugin::ReDevel;

use strict;
use warnings;
use 5.008;

our $VERSION = '0.03';

use Padre::Wx ();
use Data::Dumper; # ToDo - required only on debug mode
use File::Spec;
use File::HomeDir;
use YAML::Tiny;
use Carp qw(carp croak);

use base 'Padre::Plugin';

our $ProtocolRegex = qr/^remote:\/\//;
our $ProtocolHandlerClass = 'Padre::Plugin::ReDevel::SSH';


=head1 NAME

Padre::Plugin::ReDevel - Padre support for remote development

=head1 SYNOPSIS

TODO

=cut

sub padre_interfaces {
    return (
        'Padre::Plugin' => 0.84,
        'Padre::File'   => 0.4,
    );
}

sub plugin_name {
    'ReDevel';
}


# The command structure to show in the Plugins menu
sub menu_plugins_simple {
    my $self = shift;
    return $self->plugin_name => [
        "About" => 'show_about',
        "Open config" => 'open_config',
        # ToDo - remove debug shortcut
        "Reload config\tCtrl+Shift+N" => 'load_config',

        "Connect, run"  => [
            "Connect all hosts" => 'ssh_connect_all',
        ],

        # ToDo - remove debug menu (or make it conditional on Padre debug mode)
        # ToDo - remove debug shortcut
        "Devel ReDevel"  => [
            "Test noop rpc" => 'test_noop_rpc',
            "Test three parts rpc" => 'test_three_parts_rpc',
            "Reload plugin\tCtrl+Shift+M" => sub { $_[0]->current->ide->plugin_manager->reload_plugin('Padre::Plugin::ReDevel') },
        ],
    ];
}


# ToDo - use some Padre method?
sub conf_dir {
    return File::Spec->catdir(
        File::HomeDir->my_data,
        File::Spec->isa('File::Spec::Win32') ? 'Perl Padre' : '.padre'
    );
}


sub conf_fpath {
    my $self = shift;
    return File::Spec->catfile( $self->conf_dir, 'redevel.yml' );
}


sub open_config {
    my ( $self ) = @_;

    my $conf_fpath = $self->conf_fpath();
    my $main = $self->ide->wx->main;
    my $id = $main->setup_editor( $conf_fpath );
    return 1;
}


sub load_config_file {
    my $self = shift;

    my $conf_fpath = $self->conf_fpath();
    my $config = undef;
    eval { $config = YAML::Tiny::LoadFile($conf_fpath); };
    if ( $@ ) {
        #ToDo - warn dialog
        warn $@;
        return 0;
    }

    # ToDo - config validation method missing
    $self->{rd_config} = $config;
    print Dumper( $config ) if $self->{ver} >= 5;

    return 1;
}


sub set_config_section {
    my $self = shift;

    unless ( $self->{rd_config} ) {
        carp "Config not loaded yet.";
        return 0;
    }

    return 1 unless $self->current->ide->opts->{session};
    my $act_session_name = $self->current->ide->opts->{session};

    my $err_found = 0;
    my $selected_sess_pos = undef;
    my $config = $self->{rd_config};
    foreach my $sess_pos ( 0..$#{$config->{session}} ) {
        my $section = $config->{session}->[ $sess_pos ];
        if ( exists $section->{session} ) {
            if ( $section->{session} eq $act_session_name ) {
                $selected_sess_pos = $sess_pos;
                last;
            }

        } elsif ( exists $section->{session_regexp} ) {
            my $regexp = $section->{session_regexp};
            if ( $act_session_name =~ $section->{session_regexp} ) {
                $selected_sess_pos = $sess_pos;
                last;
            }

        } else {
            carp "Can not find session identification (no name or regexp given) on sessio->$sess_pos.";
            $err_found = 1;
            last;
        }
    }

    $self->{session_pos} = $selected_sess_pos;
    print "Selected session pos: $selected_sess_pos\n" if $self->{ver} >= 5;
    return 1;
}


sub load_config {
    my $self = shift;

    #ToDo - reconnect/disconnects host if needed
    $self->{conns} = undef;

    return 0 unless $self->load_config_file();
    return 0 unless $self->set_config_section();
    return 1;
}


sub padre_hooks {
    my $self = shift;
    return {
        before_save => sub {
            print " [[[TEST_PLUGIN:before_save]]] " . join( ', ', @_ ) . "\n";
            return undef;
        },
        after_save => sub {
            print  " [[[TEST_PLUGIN:before_save]]] " . join( ', ', @_ ) . "\n";
            return 1;
        },
    };
}


sub show_about {
    my $self = shift;
    my $about = Wx::AboutDialogInfo->new;

    $about->SetName("Padre Plugin ReDevel");
    $about->SetDescription("Remote development through SSH.");
    $about->SetVersion($VERSION);
    Wx::AboutBox($about);
    return 1;
}


sub ssh_connect {
    my ( $self, $host_alias, $host_conf ) = @_;

    my $client_obj = App::ReDevel->new({
        ver => $self->{ver},
    });
    my $ret_code = $client_obj->prepare_rpc_server( $host_conf );
    print STDERR $client_obj->err() . "\n" unless $ret_code;

    $self->{conns}->{ $host_alias } = $client_obj;
    return 1;
}


sub get_host_aliases_list {
    my $self = shift;
    return undef unless $self->{rd_config};
    return undef unless defined $self->{session_pos};
    my $session_pos = $self->{session_pos};
    return $self->{rd_config}->{session}->[ $session_pos ]->{hosts};
}


sub ssh_connect_all {
    my $self = shift;

    my $host_aliases = $self->get_host_aliases_list();
    return 0 unless $host_aliases;

    foreach my $host_alias ( @$host_aliases ) {
        my $host_conf = $self->{rd_config}->{hosts}->{ $host_alias };
        #$host_conf->{server_src_dir} =
        my $rc = $self->ssh_connect( $host_alias, $host_conf );
    }

    print Dumper( $self->{conns} );
    return 1;
}


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


sub test_noop_rpc {
    my $self = shift;
    return $self->run_rpc_cmd_on_hosts('test_noop_rpc');
}


sub test_three_parts_rpc {
    my $self = shift;
    return $self->run_rpc_cmd_on_hosts('test_three_parts_rpc');
}


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


sub plugin_disable {
    my $self = shift;

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
